/**
 * Handler para el trigger de Tonelada__c
 * 
 * Responsabilidades:
 * - afterInsert: Filtra toneladas válidas y delega a ActualizarCuentaGranariaBatch.procesarToneladasEspecificas()
 *   para crear/asignar Cuenta_Granaria__c, compensaciones y expedientes (reutiliza lógica del batch).
 *   Tras compensar, encola sincronización del expediente hacia el MBT asociado (post-commit).
 * - afterUpdate: Reprocesa al entrar en Cobrada/Debitada, Cancelada por NC, al cambiar campaña,
 *   o al modificar cantidad/CG de negativos consumibles (p. ej. BolsaTech Debitada);
 *   si cambia Expediente_de_Negativos__c, propaga el valor al MBT vinculado;
 *   recalcula saldos de cuentas afectadas
 * - afterDelete: Recalcula saldos de cuentas afectadas (lógica ligera propia)
 * 
 * Filtros aplicados (afterInsert):
 * - Sin CG: asignación automática (criterios estándar)
 * - Con CG ya asignada: Compra HT positiva en CG HT → dispara compensación
 * - Requiere: Biotecnología, Productor, Cultivo
 * - Excluye: Etapa = 'Pendiente', Origen = 'Balance Anual'
 */
public without sharing class ToneladaTriggerHandler {
    
    // Prevención de recursión: evita que el trigger se ejecute infinitamente
    // cuando el batch crea compensaciones/movimientos internos
    private static Boolean procesandoCompensaciones = false;

    @TestVisible
    private static Integer reprocesamientosEjecutados = 0;
    
    /**
     * Procesa toneladas después de insert
     * 
     * Filtra toneladas que cumplen criterios, re-consulta para obtener campos fórmula,
     * y delega toda la lógica al batch (crear CG, asignar, compensar, expedientes).
     */
    public static void afterInsert(List<Tonelada__c> newToneladas) {
        System.debug('=== ToneladaTriggerHandler.afterInsert ===');
        System.debug('Total toneladas creadas: ' + newToneladas.size());
        
        if (procesandoCompensaciones) {
            System.debug('⚠ Recursión detectada - saliendo para evitar loop infinito');
            return;
        }
        
        Set<Id> toneladasIds = new Set<Id>();
        for (Tonelada__c tn : newToneladas) {
            if (cumpleCriteriosAsignacion(tn) || cumpleCriteriosReprocesoPorCgManual(tn)) {
                toneladasIds.add(tn.Id);
            }
        }
        
        if (toneladasIds.isEmpty()) {
            System.debug('No hay toneladas para procesar');
            return;
        }
        
        System.debug('Toneladas a procesar: ' + toneladasIds.size());
        ejecutarReprocesamiento(toneladasIds);
        // Post-commit: el flow de débito BolsaTech puede actualizar el MBT después del trigger
        // y dejar Expediente_de_Negativos__c en null aunque compensar ya lo haya seteado en la TN.
        CuentaGranariaExpedienteService.programarSincronizacionMbtDesdeToneladas(toneladasIds);
    }
    
    /**
     * Procesa toneladas antes de update
     * 
     * Cuando cambia la campaña, desasigna la tonelada de su Cuenta Granaria actual
     * para que el afterUpdate la reasigne correctamente (o no, si la nueva campaña es < 2025).
     */
    public static void beforeUpdate(List<Tonelada__c> newToneladas, Map<Id, Tonelada__c> oldMap) {
        System.debug('=== ToneladaTriggerHandler.beforeUpdate ===');
        
        for (Tonelada__c tn : newToneladas) {
            Tonelada__c old = oldMap.get(tn.Id);
            
            // Si cambia la campaña, desasignar de la cuenta granaria actual
            if (tn.Campania__c != old.Campania__c && old.Cuenta_Granaria__c != null) {
                System.debug('Campaña cambió para tonelada ' + tn.Id + ': ' + old.Campania__c + ' → ' + tn.Campania__c + ' | Desasignando CG: ' + old.Cuenta_Granaria__c);
                tn.Cuenta_Granaria__c = null;
            }
        }
    }
    
    /**
     * Procesa toneladas después de update
     * 
     * Detecta cambios en campos que afectan el saldo y recalcula.
     * Asigna cuenta granaria cuando la etapa pasa a Cancelada por NC (p. ej. tras nota de crédito
     * sin haber pasado por Cobrada).
     */
    public static void afterUpdate(List<Tonelada__c> newToneladas, Map<Id, Tonelada__c> oldMap) {
        System.debug('=== ToneladaTriggerHandler.afterUpdate ===');
        
        Set<Id> cuentasARecalcular = new Set<Id>();
        Set<Id> toneladasAReprocesar = new Set<Id>();
        Set<Id> toneladasConExpedienteNuevo = new Set<Id>();
        
        for (Tonelada__c tn : newToneladas) {
            Tonelada__c old = oldMap.get(tn.Id);

            if (tn.Expediente_de_Negativos__c != old.Expediente_de_Negativos__c
                && tn.Expediente_de_Negativos__c != null) {
                toneladasConExpedienteNuevo.add(tn.Id);
            }
            
            // Reprocesar cuando entra a etapa cobrable/acreditable:
            // - Compra HT (impacta disponibilidad de compensación)
            // - Toneladas negativas (deben disparar consumo recién en Cobrada/Debitada)
            Boolean entraEtapaConsumible = (tn.Etapa__c == 'Cobrada' || tn.Etapa__c == 'Debitada') && tn.Etapa__c != old.Etapa__c;
            Boolean requiereReprocesoPorEtapa = entraEtapaConsumible &&
                (tn.Origen__c == 'Compra HT' || (tn.Signo__c == -1 && tn.Origen__c != 'Consumo'));
            if (requiereReprocesoPorEtapa) {
                toneladasAReprocesar.add(tn.Id);
            }
            
            // Cancelada por NC: asignar CG aunque no haya pasado por Cobrada (Facturada, Aplicada, etc.)
            Boolean entraCanceladaPorNC = tn.Etapa__c == 'Cancelada por NC' && old.Etapa__c != 'Cancelada por NC';
            if (entraCanceladaPorNC && cumpleCriteriosAsignacion(tn)) {
                toneladasAReprocesar.add(tn.Id);
            }
            
            // Detectar cambio de campaña → reprocesar tonelada + recalcular CG anterior
            if (tn.Campania__c != old.Campania__c) {
                toneladasAReprocesar.add(tn.Id);
                if (old.Cuenta_Granaria__c != null) {
                    cuentasARecalcular.add(old.Cuenta_Granaria__c);
                }
            }
            
            // Detectar cambio en cantidad
            if (tn.Cuenta_Granaria__c != null && tn.Cantidad_con_Signo__c != old.Cantidad_con_Signo__c) {
                cuentasARecalcular.add(tn.Cuenta_Granaria__c);
                if (debeDispararReprocesoPorCg(tn)) {
                    toneladasAReprocesar.add(tn.Id);
                }
            }
            
            // Detectar cambio en fecha de inicio: afecta el saldo por el filtro Fecha_Inicio__c <= TODAY
            // (p. ej. una Compra HT Futura que pasa a fecha pasada y empieza a contar)
            if (tn.Fecha_Inicio__c != old.Fecha_Inicio__c) {
                if (tn.Cuenta_Granaria__c != null) {
                    cuentasARecalcular.add(tn.Cuenta_Granaria__c);
                } else if (cumpleCriteriosAsignacion(tn)) {
                    toneladasAReprocesar.add(tn.Id);
                }
            }
            
            // Detectar cambio en cuenta granaria
            if (tn.Cuenta_Granaria__c != old.Cuenta_Granaria__c) {
                if (tn.Cuenta_Granaria__c != null) {
                    cuentasARecalcular.add(tn.Cuenta_Granaria__c);
                }
                if (old.Cuenta_Granaria__c != null) {
                    cuentasARecalcular.add(old.Cuenta_Granaria__c);
                }
                if (debeDispararReprocesoPorCg(tn)) {
                    toneladasAReprocesar.add(tn.Id);
                }
            }
        }
        
        ejecutarReprocesamiento(toneladasAReprocesar);

        if (!toneladasConExpedienteNuevo.isEmpty()) {
            CuentaGranariaExpedienteService.programarSincronizacionMbtDesdeToneladas(
                toneladasConExpedienteNuevo
            );
        }
        
        if (!cuentasARecalcular.isEmpty()) {
            recalcularSaldos(cuentasARecalcular);
        }
    }
    
    /**
     * Procesa toneladas después de delete
     * 
     * Recalcula el saldo de las cuentas granarias que tenían toneladas eliminadas.
     */
    public static void afterDelete(List<Tonelada__c> oldToneladas) {
        System.debug('=== ToneladaTriggerHandler.afterDelete ===');
        
        Set<Id> cuentasARecalcular = new Set<Id>();
        
        for (Tonelada__c tn : oldToneladas) {
            if (tn.Cuenta_Granaria__c != null) {
                cuentasARecalcular.add(tn.Cuenta_Granaria__c);
            }
        }
        
        if (!cuentasARecalcular.isEmpty()) {
            recalcularSaldos(cuentasARecalcular);
        }
    }
    
    /**
     * Compra HT positiva ya vinculada a una CG (p. ej. asignación manual a CG HT).
     * Debe disparar compensación aunque la TN no pase por asignación automática.
     */
    private static Boolean cumpleCriteriosReprocesoPorCgManual(Tonelada__c tn) {
        return tn.Cuenta_Granaria__c != null
            && tn.Origen__c == 'Compra HT'
            && tn.Signo__c != null
            && tn.Signo__c > 0
            && tn.Cantidad__c != null
            && tn.Cantidad__c > 0
            && tn.Biotecnologia__c != null
            && tn.Productor__c != null
            && tn.Cultivo__c != null
            && tn.Etapa__c != 'Pendiente'
            && tn.Fecha_Inicio__c != null
            && tn.Fecha_Inicio__c <= Date.today();
    }

    /**
     * Negativo en etapa consumible (BolsaTech Debitada, etc.) ya asignado a CG de campaña.
     * Al modificar cantidad o CG debe re-evaluar compensación HT.
     */
    private static Boolean cumpleCriteriosReprocesoPorNegativoConsumible(Tonelada__c tn) {
        return tn.Cuenta_Granaria__c != null
            && tn.Signo__c != null
            && tn.Signo__c < 0
            && tn.Origen__c != 'Consumo'
            && (tn.Etapa__c == 'Cobrada' || tn.Etapa__c == 'Debitada' || tn.Etapa__c == 'Cedida')
            && tn.Campania__c != null
            && tn.Biotecnologia__c != null
            && tn.Productor__c != null
            && tn.Cultivo__c != null
            && tn.Fecha_Inicio__c != null
            && tn.Fecha_Inicio__c <= Date.today();
    }

    private static Boolean debeDispararReprocesoPorCg(Tonelada__c tn) {
        return cumpleCriteriosReprocesoPorCgManual(tn)
            || cumpleCriteriosReprocesoPorNegativoConsumible(tn);
    }

    private static void ejecutarReprocesamiento(Set<Id> toneladasIds) {
        if (toneladasIds.isEmpty() || procesandoCompensaciones) {
            return;
        }

        List<Tonelada__c> toneladasCompletas = [
            SELECT Id, Name, Productor__c, Campania__c, Cultivo__c, Biotecnologia__c,
                   Cantidad__c, Signo__c, Cantidad_con_Signo__c, Origen__c, Etapa__c,
                   Fecha_Inicio__c, Fecha_Fin__c, Cuenta_Granaria__c
            FROM Tonelada__c
            WHERE Id IN :toneladasIds
                AND Biotecnologia__c != null
                AND Productor__c != null
                AND Cultivo__c != null
                AND (
                    Campania__r.Ano__c >= '2025'
                    OR Campania__c = null
                    OR (Origen__c = 'Compra HT' AND Cuenta_Granaria__r.Campania__c = null)
                )
        ];

        if (toneladasCompletas.isEmpty()) {
            return;
        }

        System.debug('Toneladas a reprocesar (compensación): ' + toneladasCompletas.size());
        procesandoCompensaciones = true;
        try {
            ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
            batch.procesarToneladasEspecificas(toneladasCompletas);
            reprocesamientosEjecutados++;
        } finally {
            procesandoCompensaciones = false;
        }
    }

    @TestVisible
    private static void resetReprocesamientosForTest() {
        reprocesamientosEjecutados = 0;
    }
    
    /**
     * Valida si una tonelada cumple con los criterios para asignación automática
     */
    private static Boolean cumpleCriteriosAsignacion(Tonelada__c tn) {
        Boolean esOrigenValido = (tn.Origen__c == 'Compra HT' || 
                                  tn.Origen__c == 'Consumo' || 
                                  (tn.Origen__c != 'Balance Anual' && tn.Campania__c != null));
        
        return tn.Cuenta_Granaria__c == null 
            && tn.Biotecnologia__c != null 
            && tn.Productor__c != null
            && tn.Cultivo__c != null
            && tn.Etapa__c != 'Pendiente'
            && esOrigenValido;
    }
    
    /**
     * Recalcula los saldos de las Cuentas_Granarias indicadas
     * 
     * Excluye cuentas de carga manual (Es_Carga_Manual__c = true).
     */
    private static void recalcularSaldos(Set<Id> cuentaIds) {
        // Filtrar cuentas que NO son de carga manual
        Set<Id> cuentasQueProcesar = new Set<Id>();
        for (Cuenta_Granaria__c cg : [
            SELECT Id 
            FROM Cuenta_Granaria__c 
            WHERE Id IN :cuentaIds 
                AND (Es_Carga_Manual__c = false OR Es_Carga_Manual__c = null)
                AND (Campania__r.Ano__c >= '2025' OR Campania__c = null)
        ]) {
            cuentasQueProcesar.add(cg.Id);
        }
        
        if (cuentasQueProcesar.isEmpty()) {
            return;
        }
        
        // Inicializar saldos en 0
        Map<Id, Decimal> saldosPorCuenta = new Map<Id, Decimal>();
        for (Id cgId : cuentasQueProcesar) {
            saldosPorCuenta.put(cgId, 0);
        }
        
        // Sumar toneladas de cada cuenta
        for (AggregateResult ar : [
            SELECT Cuenta_Granaria__c cgId, SUM(Cantidad_con_Signo__c) total
            FROM Tonelada__c
            WHERE Cuenta_Granaria__c IN :cuentasQueProcesar
                AND Fecha_Inicio__c <= TODAY
                AND Etapa__c != 'Pendiente'
                AND Origen__c != 'Balance Anual'
            GROUP BY Cuenta_Granaria__c
        ]) {
            Id cgId = (Id)ar.get('cgId');
            Decimal total = (Decimal)ar.get('total');
            saldosPorCuenta.put(cgId, total != null ? total : 0);
        }
        
        // Actualizar cuentas
        List<Cuenta_Granaria__c> cuentasAActualizar = new List<Cuenta_Granaria__c>();
        for (Id cgId : saldosPorCuenta.keySet()) {
            cuentasAActualizar.add(new Cuenta_Granaria__c(
                Id = cgId,
                Saldo_Cuenta__c = saldosPorCuenta.get(cgId)
            ));
        }
        
        if (!cuentasAActualizar.isEmpty()) {
            Database.update(cuentasAActualizar, false);
        }
    }
}