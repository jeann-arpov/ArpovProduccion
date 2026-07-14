public with sharing class CuentaGranariaToneladasController {

    public class ToneladaWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String nombre;
        @AuraEnabled public String origen;
        @AuraEnabled public Decimal cantidad;
        @AuraEnabled public Boolean esPositivo;
        @AuraEnabled public String fechaInicio;
        @AuraEnabled public String fechaCreacion;
        @AuraEnabled public String etapa;
    }

    public class ConsumoResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Decimal cantidadConsumida;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getToneladas(Id cuentaGranariaId) {
        List<ToneladaWrapper> toneladas = new List<ToneladaWrapper>();
        Decimal total = 0;
        Decimal totalPositivo = 0;
        Decimal totalNegativo = 0;

        Cuenta_Granaria__c cuenta = [
            SELECT Id, Name, Productor__c, Productor__r.Name, Campania__c, Campania__r.Name,
                   Cultivo__c, Cultivo__r.Name, Tecnologia__c, Saldo_Cuenta__c, Es_Carga_Manual__c
            FROM Cuenta_Granaria__c
            WHERE Id = :cuentaGranariaId
            LIMIT 1
        ];

        for (Tonelada__c tn : [
            SELECT Id, Name, Origen__c, Cantidad_con_Signo__c,
                   Fecha_Inicio__c, Etapa__c, CreatedDate
            FROM Tonelada__c
            WHERE Cuenta_Granaria__c = :cuentaGranariaId
                AND Fecha_Inicio__c <= TODAY
                AND Etapa__c != 'Pendiente'
                AND Origen__c != 'Balance Anual'
            ORDER BY CreatedDate DESC
        ]) {
            ToneladaWrapper wrapper = new ToneladaWrapper();
            wrapper.id = tn.Id;
            wrapper.nombre = tn.Name != null ? tn.Name : 'Sin nombre';
            wrapper.origen = tn.Origen__c;
            wrapper.cantidad = tn.Cantidad_con_Signo__c != null ? tn.Cantidad_con_Signo__c : 0;
            wrapper.esPositivo = wrapper.cantidad >= 0;
            wrapper.fechaInicio = tn.Fecha_Inicio__c != null ?
                String.valueOf(tn.Fecha_Inicio__c) : '';
            wrapper.fechaCreacion = tn.CreatedDate != null
                ? tn.CreatedDate.format('dd/MM/yyyy')
                : '';
            wrapper.etapa = tn.Etapa__c;

            toneladas.add(wrapper);
            total += wrapper.cantidad;

            if (wrapper.esPositivo) {
                totalPositivo += wrapper.cantidad;
            } else {
                totalNegativo += wrapper.cantidad;
            }
        }

        Decimal saldoCompraHT = 0;
        Id compraHTId = null;
        List<Map<String, Object>> cuentasRelacionadas = new List<Map<String, Object>>();

        if (cuenta.Campania__c != null) {
            List<Cuenta_Granaria__c> cuentasHT = [
                SELECT Id, Saldo_Cuenta__c
                FROM Cuenta_Granaria__c
                WHERE Productor__c = :cuenta.Productor__c
                    AND Cultivo__c = :cuenta.Cultivo__c
                    AND Tecnologia__c = :cuenta.Tecnologia__c
                    AND Campania__c = null
                LIMIT 1
            ];
            if (!cuentasHT.isEmpty()) {
                saldoCompraHT = cuentasHT[0].Saldo_Cuenta__c != null ? cuentasHT[0].Saldo_Cuenta__c : 0;
                compraHTId = cuentasHT[0].Id;
            }
        } else {
            Integer anio = Date.today().year();
            Set<String> anosPermitidos = new Set<String>();
            for (Integer i = 0; i < 5; i++) {
                anosPermitidos.add(String.valueOf(anio - i));
            }
            for (Cuenta_Granaria__c cg : [
                SELECT Id, Campania__r.Name, Campania__r.Ano__c, Tecnologia__c, Saldo_Cuenta__c
                FROM Cuenta_Granaria__c
                WHERE Productor__c = :cuenta.Productor__c
                    AND Cultivo__c = :cuenta.Cultivo__c
                    AND Campania__c != null
                    AND Campania__r.Ano__c IN :anosPermitidos
                ORDER BY Campania__r.Ano__c DESC, Tecnologia__c ASC
            ]) {
                cuentasRelacionadas.add(new Map<String, Object>{
                    'id' => cg.Id,
                    'campania' => cg.Campania__r.Name,
                    'saldo' => cg.Saldo_Cuenta__c != null ? cg.Saldo_Cuenta__c : 0
                });
            }
        }

        Boolean puedeGenerarConsumo = evaluarPuedeGenerarConsumo(cuenta, saldoCompraHT);

        return new Map<String, Object>{
            'toneladas' => toneladas,
            'total' => total,
            'totalPositivo' => totalPositivo,
            'totalNegativo' => totalNegativo,
            'cuenta' => new Map<String, Object>{
                'nombre' => cuenta.Name,
                'productor' => cuenta.Productor__r.Name,
                'campania' => cuenta.Campania__c != null ? cuenta.Campania__r.Name : null,
                'cultivo' => cuenta.Cultivo__r.Name,
                'tecnologia' => cuenta.Tecnologia__c,
                'saldo' => cuenta.Saldo_Cuenta__c,
                'esCompraHT' => cuenta.Campania__c == null,
                'esCargaManual' => cuenta.Es_Carga_Manual__c == true,
                'puedeGenerarConsumo' => puedeGenerarConsumo,
                'saldoCompraHT' => saldoCompraHT,
                'compraHTId' => compraHTId,
                'cuentasRelacionadas' => cuentasRelacionadas
            }
        };
    }

    @AuraEnabled
    public static ConsumoResult generarConsumoHT(Id cuentaGranariaId) {
        ConsumoResult result = new ConsumoResult();
        result.success = false;
        result.cantidadConsumida = 0;

        Cuenta_Granaria__c cgRegular = [
            SELECT Id, Productor__c, Campania__c, Cultivo__c, Tecnologia__c,
                   Saldo_Cuenta__c, Es_Carga_Manual__c
            FROM Cuenta_Granaria__c
            WHERE Id = :cuentaGranariaId
            LIMIT 1
        ];

        List<Cuenta_Granaria__c> cuentasHT = [
            SELECT Id, Saldo_Cuenta__c
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :cgRegular.Productor__c
                AND Cultivo__c = :cgRegular.Cultivo__c
                AND Tecnologia__c = :cgRegular.Tecnologia__c
                AND Campania__c = null
            LIMIT 1
        ];

        Decimal saldoHT = cuentasHT.isEmpty() || cuentasHT[0].Saldo_Cuenta__c == null
            ? 0
            : cuentasHT[0].Saldo_Cuenta__c;

        if (!evaluarPuedeGenerarConsumo(cgRegular, saldoHT)) {
            throw new AuraHandledException(
                'No se puede generar consumo: la cuenta debe ser carga manual, tener saldo negativo y HT disponible positivo.'
            );
        }

        Id htCuentaId = cuentasHT[0].Id;
        String biotecnologia = obtenerBiotecnologiaRepresentativa(cgRegular.Tecnologia__c);
        Decimal deficit = Math.abs(cgRegular.Saldo_Cuenta__c);

        List<Tonelada__c> lotesHT = consultarLotesCompraHT(
            cgRegular.Productor__c,
            cgRegular.Cultivo__c,
            cgRegular.Tecnologia__c,
            htCuentaId
        );
        Map<Id, Decimal> remainingPorLote = calcularRemainingPorLote(lotesHT);

        Decimal htDisponibleLotes = 0;
        for (Decimal rem : remainingPorLote.values()) {
            htDisponibleLotes += rem;
        }
        Decimal consumoTotal = Math.min(deficit, Math.min(saldoHT, htDisponibleLotes));

        if (consumoTotal <= 0) {
            throw new AuraHandledException('No hay toneladas HT disponibles para consumir.');
        }

        List<Tonelada__c> nuevasConsumiciones = new List<Tonelada__c>();
        Decimal pendiente = consumoTotal;

        for (Tonelada__c lote : lotesHT) {
            if (pendiente <= 0) {
                break;
            }
            if (!remainingPorLote.containsKey(lote.Id)) {
                continue;
            }
            Decimal disponible = remainingPorLote.get(lote.Id);
            if (disponible <= 0) {
                continue;
            }

            Decimal consumo = Math.min(pendiente, disponible);

            Tonelada__c consumoPositivo = new Tonelada__c();
            consumoPositivo.Productor__c = cgRegular.Productor__c;
            consumoPositivo.Campania__c = cgRegular.Campania__c;
            consumoPositivo.Cultivo__c = cgRegular.Cultivo__c;
            consumoPositivo.Biotecnologia__c = biotecnologia;
            consumoPositivo.Cantidad__c = consumo;
            consumoPositivo.Signo__c = 1;
            consumoPositivo.No_asignar_campa_a__c = true;
            consumoPositivo.Fecha_Inicio__c = Date.today();
            consumoPositivo.Fecha_Fin__c = lote.Fecha_Fin__c;
            consumoPositivo.Origen__c = 'Consumo';
            consumoPositivo.Etapa__c = 'Cobrada';
            consumoPositivo.Tonelada_Compra_HT__c = lote.Id;
            consumoPositivo.N_CUIT__c = lote.N_CUIT__c;
            consumoPositivo.Cuenta_Granaria__c = cgRegular.Id;
            nuevasConsumiciones.add(consumoPositivo);

            Tonelada__c consumoNegativo = new Tonelada__c();
            consumoNegativo.Productor__c = cgRegular.Productor__c;
            consumoNegativo.Cultivo__c = cgRegular.Cultivo__c;
            consumoNegativo.Biotecnologia__c = biotecnologia;
            consumoNegativo.Cantidad__c = consumo;
            consumoNegativo.Signo__c = -1;
            consumoNegativo.No_asignar_campa_a__c = true;
            consumoNegativo.Fecha_Inicio__c = Date.today();
            consumoNegativo.Fecha_Fin__c = lote.Fecha_Fin__c;
            consumoNegativo.Origen__c = 'Consumo';
            consumoNegativo.Etapa__c = 'Cobrada';
            consumoNegativo.Tonelada_Compra_HT__c = lote.Id;
            consumoNegativo.N_CUIT__c = lote.N_CUIT__c;
            consumoNegativo.Cuenta_Granaria__c = htCuentaId;
            nuevasConsumiciones.add(consumoNegativo);

            pendiente -= consumo;
        }

        if (nuevasConsumiciones.isEmpty()) {
            throw new AuraHandledException('No se pudieron crear las toneladas de consumo.');
        }

        insert nuevasConsumiciones;

        Decimal cantidadConsumida = consumoTotal - pendiente;
        cgRegular.Saldo_Cuenta__c = cgRegular.Saldo_Cuenta__c + cantidadConsumida;
        Cuenta_Granaria__c cgHT = new Cuenta_Granaria__c(
            Id = htCuentaId,
            Saldo_Cuenta__c = calcularSaldoDesdeToneladas(htCuentaId)
        );
        update new List<Cuenta_Granaria__c>{ cgRegular, cgHT };

        result.success = true;
        result.cantidadConsumida = cantidadConsumida;
        result.message = 'Consumo generado: ' + result.cantidadConsumida.setScale(2) + ' tn';
        return result;
    }

    private static Boolean evaluarPuedeGenerarConsumo(Cuenta_Granaria__c cuenta, Decimal saldoCompraHT) {
        return cuenta.Es_Carga_Manual__c == true
            && cuenta.Campania__c != null
            && cuenta.Saldo_Cuenta__c != null
            && cuenta.Saldo_Cuenta__c < 0
            && saldoCompraHT != null
            && saldoCompraHT > 0;
    }

    private static String obtenerBiotecnologiaRepresentativa(String tecnologiaAgrupada) {
        if (tecnologiaAgrupada == 'Enlist E3/Conkesta E3') {
            return 'Enlist E3';
        }
        if (tecnologiaAgrupada == 'RR1/RR2 - BT/Convencional') {
            return 'RR1';
        }
        return tecnologiaAgrupada;
    }

    private static String mapearTecnologia(String biotecnologia, String cultivoNombre) {
        if (biotecnologia == 'Enlist E3' || biotecnologia == 'Conkesta E3') {
            return 'Enlist E3/Conkesta E3';
        }
        if (biotecnologia == 'RR1' || biotecnologia == 'RR2 - BT') {
            return 'RR1/RR2 - BT/Convencional';
        }
        if (biotecnologia == 'Convencional') {
            return 'RR1/RR2 - BT/Convencional';
        }
        return biotecnologia;
    }

    private static Set<String> obtenerBiotecnologiasDelGrupo(String tecnologiaAgrupada) {
        if (tecnologiaAgrupada == 'Enlist E3/Conkesta E3') {
            return new Set<String>{ 'Enlist E3', 'Conkesta E3' };
        }
        if (tecnologiaAgrupada == 'RR1/RR2 - BT/Convencional') {
            return new Set<String>{ 'RR1', 'RR2 - BT', 'Convencional' };
        }
        return new Set<String>{ tecnologiaAgrupada };
    }

    private static List<Tonelada__c> consultarLotesCompraHT(
        Id productorId, Id cultivoId, String tecnologiaAgrupada, Id htCuentaId
    ) {
        Set<String> biotechs = obtenerBiotecnologiasDelGrupo(tecnologiaAgrupada);
        List<Tonelada__c> lotesCampania = [
            SELECT Id, Cantidad_con_Signo__c, Fecha_Fin__c, Variedad__c, N_CUIT__c
            FROM Tonelada__c
            WHERE Productor__c = :productorId
                AND Cultivo__c = :cultivoId
                AND Biotecnologia__c IN :biotechs
                AND Origen__c = 'Compra HT'
                AND HT_Id__r.Linea_de_Compra_HT__r.Tipo_de_Compra__c = 'Disponible'
                AND Etapa__c != 'Pendiente'
                AND Fecha_Inicio__c <= TODAY
                AND Campania__c != null
                AND Campania__r.Estado__c IN ('Completa', 'Activa')
            ORDER BY Fecha_Fin__c ASC
            LIMIT 10000
        ];
        return mergeLotesCompraHTOrdenados(
            lotesCampania,
            consultarLotesCompraHTEnCuenta(htCuentaId, productorId, cultivoId, biotechs)
        );
    }

    /**
     * Toneladas Compra HT ya asignadas a la CG sin campaña (p. ej. cargadas manualmente
     * o con campaña antigua/inactiva). El saldo HT las incluye pero la query por campaña no.
     */
    private static List<Tonelada__c> consultarLotesCompraHTEnCuenta(
        Id htCuentaId, Id productorId, Id cultivoId, Set<String> biotechs
    ) {
        if (htCuentaId == null) {
            return new List<Tonelada__c>();
        }
        return [
            SELECT Id, Cantidad_con_Signo__c, Fecha_Fin__c, Variedad__c, N_CUIT__c
            FROM Tonelada__c
            WHERE Cuenta_Granaria__c = :htCuentaId
                AND Productor__c = :productorId
                AND Cultivo__c = :cultivoId
                AND Biotecnologia__c IN :biotechs
                AND Origen__c = 'Compra HT'
                AND Etapa__c != 'Pendiente'
                AND Fecha_Inicio__c <= TODAY
                AND Cantidad_con_Signo__c > 0
            ORDER BY Fecha_Fin__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 10000
        ];
    }

    private static List<Tonelada__c> mergeLotesCompraHTOrdenados(
        List<Tonelada__c> lotesCampania, List<Tonelada__c> lotesEnCuenta
    ) {
        Map<Id, Tonelada__c> porId = new Map<Id, Tonelada__c>();
        for (Tonelada__c lote : lotesCampania) {
            porId.put(lote.Id, lote);
        }
        for (Tonelada__c lote : lotesEnCuenta) {
            porId.put(lote.Id, lote);
        }
        List<Tonelada__c> merged = new List<Tonelada__c>(porId.values());
        merged.sort(new LoteHTFechaFinComparator());
        return merged;
    }

    private class LoteHTFechaFinComparator implements System.Comparator<Tonelada__c> {
        public Integer compare(Tonelada__c a, Tonelada__c b) {
            if (a.Fecha_Fin__c == b.Fecha_Fin__c) {
                return 0;
            }
            if (a.Fecha_Fin__c == null) {
                return 1;
            }
            if (b.Fecha_Fin__c == null) {
                return -1;
            }
            return a.Fecha_Fin__c < b.Fecha_Fin__c ? -1 : 1;
        }
    }

    private static Map<Id, Decimal> calcularRemainingPorLote(List<Tonelada__c> todosLotesHT) {
        Map<Id, Decimal> remainingPerLote = new Map<Id, Decimal>();
        List<Tonelada__c> lotesPositivos = new List<Tonelada__c>();

        for (Tonelada__c lote : todosLotesHT) {
            if (lote.Cantidad_con_Signo__c != null && lote.Cantidad_con_Signo__c > 0) {
                lotesPositivos.add(lote);
                remainingPerLote.put(lote.Id, lote.Cantidad_con_Signo__c);
            }
        }

        for (Tonelada__c lote : todosLotesHT) {
            if (lote.Cantidad_con_Signo__c != null && lote.Cantidad_con_Signo__c < 0) {
                Decimal negativo = Math.abs(lote.Cantidad_con_Signo__c);
                for (Tonelada__c posLote : lotesPositivos) {
                    if (negativo <= 0) {
                        break;
                    }
                    Decimal remaining = remainingPerLote.get(posLote.Id);
                    if (remaining <= 0) {
                        continue;
                    }
                    Decimal descuento = Math.min(negativo, remaining);
                    remainingPerLote.put(posLote.Id, remaining - descuento);
                    negativo -= descuento;
                }
            }
        }

        Set<Id> loteIds = remainingPerLote.keySet();
        if (!loteIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Tonelada_Compra_HT__c loteId, SUM(Cantidad__c) totalConsumido
                FROM Tonelada__c
                WHERE Tonelada_Compra_HT__c IN :loteIds
                    AND Origen__c = 'Consumo'
                    AND Signo__c = 1
                GROUP BY Tonelada_Compra_HT__c
            ]) {
                Id loteId = (Id) ar.get('loteId');
                Decimal totalConsumido = (Decimal) ar.get('totalConsumido');
                if (remainingPerLote.containsKey(loteId)) {
                    remainingPerLote.put(
                        loteId,
                        Math.max(remainingPerLote.get(loteId) - totalConsumido, 0)
                    );
                }
            }
        }

        return remainingPerLote;
    }

    private static Decimal calcularSaldoDesdeToneladas(Id cuentaGranariaId) {
        AggregateResult ar = [
            SELECT SUM(Cantidad_con_Signo__c) total
            FROM Tonelada__c
            WHERE Cuenta_Granaria__c = :cuentaGranariaId
                AND Fecha_Inicio__c <= TODAY
                AND Etapa__c != 'Pendiente'
                AND Origen__c != 'Balance Anual'
        ];
        return ar.get('total') != null ? (Decimal) ar.get('total') : 0;
    }
}