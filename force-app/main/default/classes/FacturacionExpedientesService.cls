public class FacturacionExpedientesService {

    // --- WRAPPERS DE ENTRADA Y SALIDA PARA EL FLOW ---
    public class PeticionFacturacion {
        @InvocableVariable(label='IDs Seleccionados' required=true)
        public List<Id> idsSeleccionados;
        
        @InvocableVariable(label='Es Solo Validación (Marcar True para previsualizar)' required=true)
        public Boolean esSoloValidacion;
    }

    public class ResultadoFacturacion {
        @InvocableVariable(label='Cantidad de Expedientes Válidos')
        public Integer cantidadValidos;
        
        @InvocableVariable(label='Mensaje de Confirmación (Para Pantalla 1)')
        public String mensajeConfirmacion;
        
        @InvocableVariable(label='Resumen Final (Para Pantalla 2)')
        public String mensajeResultado;
    }

    @InvocableMethod(label='Facturar Expedientes (Validar o Procesar)' description='Valida o procesa facturas en lote devolviendo resúmenes detallados.')
    public static List<ResultadoFacturacion> procesarFacturacion(List<PeticionFacturacion> peticiones) {
        
        List<ResultadoFacturacion> resultados = new List<ResultadoFacturacion>();
        
        for (PeticionFacturacion peticion : peticiones) {
            ResultadoFacturacion resultado = new ResultadoFacturacion();
            
            if (peticion.idsSeleccionados == null || peticion.idsSeleccionados.isEmpty()) {
                resultado.mensajeConfirmacion = 'No se seleccionaron expedientes.';
                resultado.cantidadValidos = 0;
                resultados.add(resultado);
                continue;
            }
            
            // 1. Consulta Principal
            List<Expediente_de_Negativos__c> expedientes = [
                SELECT Id, Name, Tipo_expendiente__c, Etapa__c, Estado_de_la_Etapa__c, TNRE3_Id__c, Saldo_Expediente__c, 
                       Saldo_CG__c, Campania__c, Cuenta__c, Cuenta__r.N_CUIT__c, Cuenta__r.TN_Disponibles__c
                FROM Expediente_de_Negativos__c 
                WHERE Id IN :peticion.idsSeleccionados
            ];
            
            Map<Id, String> mapaNombres = new Map<Id, String>();
            List<Expediente_de_Negativos__c> expsParaProcesarEXP = new List<Expediente_de_Negativos__c>();
            List<Expediente_de_Negativos__c> expsParaProcesarPRI = new List<Expediente_de_Negativos__c>();
            
            Integer validos = 0;
            Integer descartados = 0;
            List<String> detallesDescartados = new List<String>();
            List<String> exitos = new List<String>();
            List<String> errores = new List<String>();
            
            // 2. Lógica de Pre-Validación para todos
            for (Expediente_de_Negativos__c exp : expedientes) {
                mapaNombres.put(exp.Id, exp.Name);
                String motivoDescarga = null;
                
                // Reglas de exclusión compartidas
                if (exp.Tipo_expendiente__c == 'SEC' || exp.Name.startsWith('SEC-')) {
                    motivoDescarga = 'Ignorado por ser de tipo SEC.';
                } else if (exp.Estado_de_la_Etapa__c == 'Finalizado') {
                    motivoDescarga = 'El expediente ya se encuentra Finalizado.';
                } else if (exp.Etapa__c == 'Facturar Regalía E3' || exp.TNRE3_Id__c != null) {
                    motivoDescarga = 'El expediente ya fue facturado previamente.';
                } else if (exp.Tipo_expendiente__c == 'EXP' || exp.Name.startsWith('EXP-')) {
                    if (exp.Saldo_CG__c == null || exp.Saldo_CG__c >= 0) {
                        motivoDescarga = 'El saldo de la cuenta no es negativo.';
                    }
                } else if (exp.Tipo_expendiente__c != 'PRI' && !exp.Name.startsWith('PRI-')) {
                    motivoDescarga = 'Tipo de expediente no soportado.';
                }
                
                if (motivoDescarga != null) {
                    descartados++;
                    detallesDescartados.add('❌ ' + exp.Name + ': ' + motivoDescarga);
                    errores.add('❌ ' + exp.Name + ': ' + motivoDescarga);
                } else {
                    validos++;
                    if (exp.Tipo_expendiente__c == 'EXP' || exp.Name.startsWith('EXP-')) {
                        expsParaProcesarEXP.add(exp);
                    } else {
                        expsParaProcesarPRI.add(exp);
                    }
                }
            }
            
            resultado.cantidadValidos = validos;
            
            // 3. ARMADO DE PANTALLA 1: CONFIRMACIÓN (MODO VALIDACIÓN)
            if (peticion.esSoloValidacion) {
                String msgConf = 'Se analizaron ' + expedientes.size() + ' expedientes seleccionados.\n\n';
                msgConf += '✅ Válidos para facturar: ' + validos + '\n';
                msgConf += '🚫 Descartados: ' + descartados + '\n\n';
                
                if (descartados > 0) {
                    msgConf += '--- DETALLE DE DESCARTADOS ---\n' + String.join(detallesDescartados, '\n') + '\n\n';
                }
                
                msgConf += validos > 0 ? '¿Desea confirmar y procesar los ' + validos + ' expedientes válidos?' : 'No hay registros válidos para procesar.';
                resultado.mensajeConfirmacion = msgConf;
                
            } else {
                // 4. MODO PROCESAMIENTO (DML REAL)
                if (validos > 0) {
                    try {
                        if (!expsParaProcesarEXP.isEmpty()) procesarLogicaEXP(expsParaProcesarEXP, exitos, errores, mapaNombres);
                        if (!expsParaProcesarPRI.isEmpty()) procesarLogicaPRI(expsParaProcesarPRI, exitos, errores, mapaNombres);
                    } catch (Exception e) {
                        errores.add('⚠️ Error Crítico Global: ' + e.getMessage());
                    }
                }
                
                // ARMADO DE PANTALLA 2: RESUMEN FINAL
                String textoResumen = '';
                if (!exitos.isEmpty()) {
                    textoResumen += '=== FACTURADOS CON ÉXITO (' + exitos.size() + ') ===\n' + String.join(exitos, '\n') + '\n\n';
                }
                if (!errores.isEmpty()) {
                    textoResumen += '=== ERRORES Y DESCARTADOS (' + errores.size() + ') ===\n' + String.join(errores, '\n');
                }
                resultado.mensajeResultado = String.isBlank(textoResumen) ? 'No se ejecutó ninguna acción.' : textoResumen;
            }
            
            resultados.add(resultado);
        }
        return resultados;
    }
    
    // ==========================================
    // MÉTODO PARA LÓGICA EXPEDIENTES "EXP"
    // ==========================================
    @TestVisible
    private static void procesarLogicaEXP(List<Expediente_de_Negativos__c> expsParaProcesar, List<String> exitos, List<String> errores, Map<Id, String> mapaNombres) {
        
        Cultivo__c cultivoSoja = [SELECT Id, Fecha_Vencimiento_de_Tonelada__c FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Sembra_Evolucion__c customSetting = Sembra_Evolucion__c.getInstance();
        Id cortevaId = customSetting != null ? customSetting.Corteva_30_Id__c : null;

        Date today = Date.today();
        Date fechaVtoTN = cultivoSoja.Fecha_Vencimiento_de_Tonelada__c;
        Date fechaFinCalc = (fechaVtoTN != null && Date.newInstance(today.year(), 1, 1) <= today && today < fechaVtoTN) 
                            ? fechaVtoTN : (fechaVtoTN != null ? Date.newInstance(today.year() + 1, fechaVtoTN.month(), fechaVtoTN.day()) : null);

        Map<Id, Tonelada__c> mapaExpATnPrincipal = new Map<Id, Tonelada__c>();
        Map<Id, List<String>> mapaExpACTGs = new Map<Id, List<String>>();
        
        for (Tonelada__c tn : [SELECT Id, Expediente_de_Negativos__c, Origen__c, Tipo_de_Movimiento__c, Mov_BolsaTech__r.CTG__c FROM Tonelada__c WHERE Expediente_de_Negativos__c IN :expsParaProcesar]) {
            if (tn.Origen__c == 'Regalía Enlist' && tn.Tipo_de_Movimiento__c == 'C') mapaExpATnPrincipal.put(tn.Expediente_de_Negativos__c, tn);
            if (String.isNotBlank(tn.Mov_BolsaTech__r?.CTG__c)) {
                if (!mapaExpACTGs.containsKey(tn.Expediente_de_Negativos__c)) mapaExpACTGs.put(tn.Expediente_de_Negativos__c, new List<String>());
                mapaExpACTGs.get(tn.Expediente_de_Negativos__c).add(tn.Mov_BolsaTech__r.CTG__c);
            }
        }

        Map<Id, Id> mapaExpAFacturaExistente = new Map<Id, Id>();
        for (TN_Regalia_Enlist__c fc : [SELECT Id, Expediente_de_Negativos__c FROM TN_Regalia_Enlist__c WHERE Expediente_de_Negativos__c IN :expsParaProcesar]) {
            mapaExpAFacturaExistente.put(fc.Expediente_de_Negativos__c, fc.Id);
        }

        List<Tonelada__c> tnsAInsertar = new List<Tonelada__c>();
        Map<Id, Tonelada__c> mapaExpANuevaTn = new Map<Id, Tonelada__c>();
        List<TN_Regalia_Enlist__c> facturasAInsertar = new List<TN_Regalia_Enlist__c>();
        Map<Id, TN_Regalia_Enlist__c> mapaExpANuevaFactura = new Map<Id, TN_Regalia_Enlist__c>();

        for (Expediente_de_Negativos__c exp : expsParaProcesar) {
            if (!mapaExpATnPrincipal.containsKey(exp.Id)) {
                Tonelada__c nuevaTn = new Tonelada__c(
                    Biotecnologia__c = 'Enlist E3', Campania__c = exp.Campania__c, Cantidad__c = exp.Saldo_CG__c * (-1),
                    Cultivo__c = cultivoSoja.Id, Etapa__c = 'Facturada', Expediente_de_Negativos__c = exp.Id,
                    Fecha_Fin_Original__c = fechaFinCalc, Fecha_Fin__c = fechaFinCalc, Fecha_Inicio__c = today,
                    N_CUIT__c = exp.Cuenta__r.N_CUIT__c, Origen__c = 'Regalía Enlist', Productor__c = exp.Cuenta__c,
                    Signo__c = 1.0, Tipo_de_Movimiento__c = 'C'
                );
                mapaExpANuevaTn.put(exp.Id, nuevaTn);
                tnsAInsertar.add(nuevaTn);
            }

            if (!mapaExpAFacturaExistente.containsKey(exp.Id)) {
                String stringCTGs = mapaExpACTGs.containsKey(exp.Id) ? String.join(mapaExpACTGs.get(exp.Id), ', ') : '';
                TN_Regalia_Enlist__c nuevaFC = new TN_Regalia_Enlist__c(
                    Biotecnologia__c = 'Enlist', CTGs_Involucrados__c = stringCTGs, Cantidad__c = exp.Saldo_CG__c * (-1),
                    Cultivo__c = cultivoSoja.Id, Etapa__c = 'A Facturar', Expediente_de_Negativos__c = exp.Id,
                    N_CUIT__c = exp.Cuenta__r.N_CUIT__c, Obtentor__c = cortevaId, Productor__c = exp.Cuenta__c
                );
                mapaExpANuevaFactura.put(exp.Id, nuevaFC);
                facturasAInsertar.add(nuevaFC);
            }
        }

        if (!tnsAInsertar.isEmpty()) {
            Database.SaveResult[] srTns = Database.insert(tnsAInsertar, false);
            for (Integer i = 0; i < srTns.size(); i++) {
                if (!srTns[i].isSuccess()) errores.add('❌ ' + mapaNombres.get(tnsAInsertar[i].Expediente_de_Negativos__c) + ': Error Tonelada -> ' + srTns[i].getErrors()[0].getMessage());
            }
        }
        
        if (!facturasAInsertar.isEmpty()) {
            Database.SaveResult[] srFcs = Database.insert(facturasAInsertar, false);
            for (Integer i = 0; i < srFcs.size(); i++) {
                if (!srFcs[i].isSuccess()) errores.add('❌ ' + mapaNombres.get(facturasAInsertar[i].Expediente_de_Negativos__c) + ': Error Factura -> ' + srFcs[i].getErrors()[0].getMessage());
            }
        }

        List<Expediente_de_Negativos__c> expedientesAActualizar = new List<Expediente_de_Negativos__c>();
        List<Tonelada__c> tnsAActualizar = new List<Tonelada__c>();

        for (Expediente_de_Negativos__c exp : expsParaProcesar) {
            Id fcId = mapaExpAFacturaExistente.get(exp.Id);
            if (fcId == null && mapaExpANuevaFactura.containsKey(exp.Id) && mapaExpANuevaFactura.get(exp.Id).Id != null) {
                fcId = mapaExpANuevaFactura.get(exp.Id).Id;
            }

            Id tnId = mapaExpATnPrincipal.containsKey(exp.Id) ? mapaExpATnPrincipal.get(exp.Id).Id : 
                     (mapaExpANuevaTn.containsKey(exp.Id) && mapaExpANuevaTn.get(exp.Id).Id != null ? mapaExpANuevaTn.get(exp.Id).Id : null);

            if (fcId != null) {
                Expediente_de_Negativos__c expUpdate = new Expediente_de_Negativos__c(Id = exp.Id);
                expUpdate.Estado_de_la_Etapa__c = 'Finalizado';
                expUpdate.Etapa__c = 'Facturar Regalía E3';
                expUpdate.Fecha_Cambio_Etapa__c = today;
                expUpdate.Saldo_del_Expediente_al_Cierre__c = exp.Saldo_CG__c; 
                expUpdate.TNRE3_Id__c = fcId;
                expUpdate.ValidationBypassDateTime__c = Datetime.now();
                expedientesAActualizar.add(expUpdate);

                if (tnId != null) tnsAActualizar.add(new Tonelada__c(Id = tnId, FT_RE3_Id__c = fcId));
            }
        }

        if (!expedientesAActualizar.isEmpty()) {
            Database.SaveResult[] srUpdates = Database.update(expedientesAActualizar, false);
            for (Integer i = 0; i < srUpdates.size(); i++) {
                if (srUpdates[i].isSuccess()) {
                    exitos.add('✅ ' + mapaNombres.get(expedientesAActualizar[i].Id) + ' | FCRE3 Generado: ' + expedientesAActualizar[i].TNRE3_Id__c);
                } else {
                    errores.add('❌ ' + mapaNombres.get(expedientesAActualizar[i].Id) + ': Error Update -> ' + srUpdates[i].getErrors()[0].getMessage());
                }
            }
        }
        
        if (!tnsAActualizar.isEmpty()) Database.update(tnsAActualizar, false);
    }

    // ==========================================
    // MÉTODO PARA LÓGICA EXPEDIENTES "PRI"
    // ==========================================
    private static void procesarLogicaPRI(List<Expediente_de_Negativos__c> expsParaProcesar, List<String> exitos, List<String> errores, Map<Id, String> mapaNombres) {
        
        Cultivo__c cultivoSoja = [SELECT Id, Fecha_Vencimiento_de_Tonelada__c FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Sembra_Evolucion__c customSetting = Sembra_Evolucion__c.getInstance();
        Id cortevaId = customSetting != null ? customSetting.Corteva_30_Id__c : null;
        
        Map<Id, List<Movimiento_BolsaTech__c>> mapaExpAMBTs = new Map<Id, List<Movimiento_BolsaTech__c>>();
        for (Movimiento_BolsaTech__c mbt : [SELECT Id, Expediente_de_Negativos__c, CTG__c, Titular_asignado__c, Titular_original__c FROM Movimiento_BolsaTech__c WHERE Expediente_de_Negativos__c IN :expsParaProcesar]) {
            if (!mapaExpAMBTs.containsKey(mbt.Expediente_de_Negativos__c)) mapaExpAMBTs.put(mbt.Expediente_de_Negativos__c, new List<Movimiento_BolsaTech__c>());
            mapaExpAMBTs.get(mbt.Expediente_de_Negativos__c).add(mbt);
        }
        
        Map<Id, Id> mapaExpAFacturaExistente = new Map<Id, Id>();
        for (TN_Regalia_Enlist__c fc : [SELECT Id, Expediente_de_Negativos__c FROM TN_Regalia_Enlist__c WHERE Expediente_de_Negativos__c IN :expsParaProcesar]) {
            mapaExpAFacturaExistente.put(fc.Expediente_de_Negativos__c, fc.Id);
        }
        
        List<TN_Regalia_Enlist__c> facturasAInsertar = new List<TN_Regalia_Enlist__c>();
        Map<Id, TN_Regalia_Enlist__c> mapaExpANuevaFactura = new Map<Id, TN_Regalia_Enlist__c>();
        List<Expediente_de_Negativos__c> expedientesAActualizar = new List<Expediente_de_Negativos__c>();
        List<Id> expedientesParaAccionMbt = new List<Id>();
        
        for (Expediente_de_Negativos__c exp : expsParaProcesar) {
            
            List<String> ctgsList = new List<String>();
            Boolean titularAsignado = false;
            String cuitTitular = '';
            
            if (mapaExpAMBTs.containsKey(exp.Id)) {
                for (Movimiento_BolsaTech__c mbt : mapaExpAMBTs.get(exp.Id)) {
                    if (String.isNotBlank(mbt.CTG__c)) ctgsList.add(mbt.CTG__c);
                    if (!titularAsignado && String.isNotBlank(mbt.Titular_asignado__c)) {
                        titularAsignado = true; cuitTitular = mbt.Titular_asignado__c;
                    } else if (!titularAsignado && String.isNotBlank(mbt.Titular_original__c)) {
                        cuitTitular = mbt.Titular_original__c;
                    }
                }
            }
            
            Id facturaId = mapaExpAFacturaExistente.get(exp.Id);
            if (facturaId == null) {
                TN_Regalia_Enlist__c nuevaFC = new TN_Regalia_Enlist__c(
                    Biotecnologia__c = 'Enlist', CTGs_Involucrados__c = String.join(ctgsList, ', '),
                    Cantidad__c = exp.Saldo_Expediente__c, Cultivo__c = cultivoSoja.Id, Etapa__c = 'A Facturar',
                    Expediente_de_Negativos__c = exp.Id, N_CUIT__c = exp.Cuenta__r.N_CUIT__c,
                    Obtentor__c = cortevaId, Productor__c = exp.Cuenta__c
                );
                if (titularAsignado) nuevaFC.Titular_asignado__c = cuitTitular; else nuevaFC.Titular_original__c = cuitTitular;
                
                mapaExpANuevaFactura.put(exp.Id, nuevaFC);
                facturasAInsertar.add(nuevaFC);
            } else {
                expedientesParaAccionMbt.add(exp.Id);
            }
        }
        
        if (!facturasAInsertar.isEmpty()) {
            Database.SaveResult[] srFcs = Database.insert(facturasAInsertar, false);
            for (Integer i = 0; i < srFcs.size(); i++) {
                if (srFcs[i].isSuccess()) {
                    expedientesParaAccionMbt.add(facturasAInsertar[i].Expediente_de_Negativos__c);
                } else {
                    errores.add('❌ ' + mapaNombres.get(facturasAInsertar[i].Expediente_de_Negativos__c) + ': Error Factura -> ' + srFcs[i].getErrors()[0].getMessage());
                }
            }
        }
        
        for (Expediente_de_Negativos__c exp : expsParaProcesar) {
            Id fcId = mapaExpAFacturaExistente.get(exp.Id);
            if (fcId == null && mapaExpANuevaFactura.containsKey(exp.Id) && mapaExpANuevaFactura.get(exp.Id).Id != null) {
                fcId = mapaExpANuevaFactura.get(exp.Id).Id;
            }
            
            if (fcId != null && (exp.Etapa__c != 'Facturar Regalía E3' && exp.TNRE3_Id__c == null)) {
                Expediente_de_Negativos__c expUpdate = new Expediente_de_Negativos__c(Id = exp.Id);
                expUpdate.Estado_de_la_Etapa__c = 'Finalizado';
                expUpdate.Etapa__c = 'Facturar Regalía E3';
                expUpdate.Fecha_Cambio_Etapa__c = Date.today();
                expUpdate.Saldo_del_Expediente_al_Cierre__c = exp.Cuenta__r.TN_Disponibles__c; 
                expUpdate.TNRE3_Id__c = fcId;
                expUpdate.ValidationBypassDateTime__c = Datetime.now();
                expedientesAActualizar.add(expUpdate);
            }
        }
        
        if (!expedientesAActualizar.isEmpty()) {
            Database.SaveResult[] srUpdates = Database.update(expedientesAActualizar, false);
            for (Integer i = 0; i < srUpdates.size(); i++) {
                if (srUpdates[i].isSuccess()) {
                    // AQUÍ ESTÁ EL ID DEL FCRE3 GENERADO
                    exitos.add('✅ ' + mapaNombres.get(expedientesAActualizar[i].Id) + ' | FCRE3 Generado: ' + expedientesAActualizar[i].TNRE3_Id__c);
                } else {
                    errores.add('❌ ' + mapaNombres.get(expedientesAActualizar[i].Id) + ': Error Update -> ' + srUpdates[i].getErrors()[0].getMessage());
                }
            }
        }
        
        if (!expedientesParaAccionMbt.isEmpty()) {
            try {
                Set<Id> expedientesSet = new Set<Id>(expedientesParaAccionMbt);
                RelacionarFacturaEnlistMbt.relacionarPorExpedientes(expedientesSet);
            } catch (Exception mbtEx) {
                errores.add('⚠️ Error al relacionar MBTs: ' + mbtEx.getMessage());
            }
        }
    }
}