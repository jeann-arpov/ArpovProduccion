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

    public static Map<String, Object> getToneladas(Id cuentaGranariaId) {
        return getToneladas(cuentaGranariaId, null);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getToneladas(Id cuentaGranariaId, Id variedadId) {
        List<ToneladaWrapper> toneladas = new List<ToneladaWrapper>();
        Decimal total = 0;
        Decimal totalPositivo = 0;
        Decimal totalNegativo = 0;

        Cuenta_Granaria__c cuenta = [
            SELECT Id, Name, Productor__c, Productor__r.Name, Campania__c, Campania__r.Name, Campania__r.Ano__c,
                   Cultivo__c, Cultivo__r.Name, Tecnologia__c, Saldo_Cuenta__c, Es_Carga_Manual__c
            FROM Cuenta_Granaria__c
            WHERE Id = :cuentaGranariaId
            LIMIT 1
        ];

        String consulta = 'SELECT Id, Name, Origen__c, Cantidad_con_Signo__c, '
            + 'Fecha_Inicio__c, Etapa__c, CreatedDate '
            + 'FROM Tonelada__c '
            + 'WHERE Cuenta_Granaria__c = :cuentaGranariaId '
            + 'AND Fecha_Inicio__c <= TODAY '
            + 'AND Etapa__c != \'Pendiente\' '
            + 'AND Origen__c != \'Balance Anual\' ';
        if (variedadId != null) {
            consulta += 'AND Variedad__c = :variedadId ';
        }
        consulta += 'ORDER BY CreatedDate DESC';

        for (Tonelada__c tn : Database.query(consulta)) {
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
                'campaniaPeriodo' => periodoCampania(cuenta.Campania__c != null ? cuenta.Campania__r.Ano__c : null),
                'cultivo' => cuenta.Cultivo__r.Name,
                'tecnologia' => cuenta.Tecnologia__c,
                'tecnologiaEtiqueta' => etiquetaTecnologia(cuenta.Tecnologia__c, cuenta.Cultivo__r?.Name),
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
            throw new AuraHandledException(Label.DUP_Sin_Toneladas_HT);
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
            throw new AuraHandledException(Label.DUP_Error_Crear_Toneladas);
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

    private static final Integer DETALLE_PAGE = 40;
    private static final Integer CSV_MAX = 10000;

    private static final List<String> ORDEN_ORIGEN = new List<String>{
        'Compra SF',
        'Compra HT',
        'Cesión HT',
        'Semilla Original',
        'BolsaTech',
        'Escáner varietal',
        'Regalía Enlist',
        'Semilla Pre Básica',
        'Ensayo',
        'PPH',
        'Aplicada',
        'Consumo',
        'Transferencia'
    };

    private static final Map<String, String> ETIQUETA_ORIGEN = new Map<String, String>{
        'Compra SF' => 'Compra Semilla Fiscalizada',
        'Compra HT' => 'Compra HT',
        'Cesión HT' => 'Cesión',
        'Semilla Original' => 'Semilla Original',
        'BolsaTech' => 'Entregas (Bolsatech)',
        'Escáner varietal' => 'Entregas (escáner varietal)',
        'Regalía Enlist' => 'Regalía pagada'
    };

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getResumen(Id cuentaGranariaId, Id variedadId) {
        Cuenta_Granaria__c cuenta = consultarCuenta(cuentaGranariaId);
        String filtroVariedad = variedadId == null ? '' : ' AND Variedad__c = :variedadId';
        String base = 'SELECT Origen__c origen, COUNT(Id) movimientos, SUM(Cantidad_con_Signo__c) toneladas'
            + ' FROM Tonelada__c WHERE ' + String.join(filtrosBase(), ' AND ') + filtroVariedad;

        List<OrigenAcum> creditos = ordenarOrigenes(acumular(
            Database.query(base + ' AND Cantidad_con_Signo__c >= 0 GROUP BY Origen__c'), TIPO_CREDITO
        ));
        List<OrigenAcum> debitos = ordenarOrigenes(acumular(
            Database.query(base + ' AND Cantidad_con_Signo__c < 0 GROUP BY Origen__c'), TIPO_DEBITO
        ));

        Decimal credito = 0;
        Decimal debito = 0;
        Integer movimientos = 0;
        List<Map<String, Object>> origenes = new List<Map<String, Object>>();
        for (OrigenAcum acum : creditos) {
            credito += acum.toneladas;
            movimientos += acum.movimientos;
            origenes.add(acum.toMap());
        }
        for (OrigenAcum acum : debitos) {
            debito += acum.toneladas;
            movimientos += acum.movimientos;
            origenes.add(acum.toMap());
        }

        Boolean esTrigo = cuenta.Cultivo__r != null && cuenta.Cultivo__r.Name == 'TRIGO';
        String variedadNombre = null;
        if (variedadId != null) {
            for (Variedad__c v : [SELECT Name FROM Variedad__c WHERE Id = :variedadId LIMIT 1]) {
                variedadNombre = v.Name;
            }
        }

        return new Map<String, Object>{
            'origenes' => origenes,
            'credito' => credito,
            'debito' => debito,
            'saldo' => credito + debito,
            'movimientos' => movimientos,
            'esTrigo' => esTrigo,
            'variedades' => esTrigo && variedadId == null ? resumirVariedades(cuentaGranariaId) : new List<Map<String, Object>>(),
            'variedadNombre' => variedadNombre,
            'cuenta' => armarCuenta(cuenta)
        };
    }

    private static final String TIPO_CREDITO = 'credito';
    private static final String TIPO_DEBITO = 'debito';

    private static Map<String, OrigenAcum> acumular(List<AggregateResult> filas, String tipo) {
        Map<String, OrigenAcum> porOrigen = new Map<String, OrigenAcum>();
        for (AggregateResult ar : filas) {
            String origen = (String) ar.get('origen');
            if (String.isBlank(origen)) {
                origen = 'Sin origen';
            }
            OrigenAcum acum = new OrigenAcum(origen, tipo);
            acum.toneladas = ar.get('toneladas') == null ? 0 : (Decimal) ar.get('toneladas');
            acum.movimientos = (Integer) ar.get('movimientos');
            porOrigen.put(origen, acum);
        }
        return porOrigen;
    }

    private static List<OrigenAcum> ordenarOrigenes(Map<String, OrigenAcum> porOrigen) {
        List<OrigenAcum> ordenados = new List<OrigenAcum>();
        for (String clave : ORDEN_ORIGEN) {
            if (porOrigen.containsKey(clave)) {
                ordenados.add(porOrigen.remove(clave));
            }
        }
        List<String> restantes = new List<String>(porOrigen.keySet());
        restantes.sort();
        for (String clave : restantes) {
            ordenados.add(porOrigen.get(clave));
        }
        return ordenados;
    }

    private static List<Map<String, Object>> resumirVariedades(Id cuentaGranariaId) {
        Map<Id, VariedadAcum> porVariedad = new Map<Id, VariedadAcum>();
        VariedadAcum sinVariedad = null;
        String base = 'SELECT Variedad__c variedadId, SUM(Cantidad_con_Signo__c) toneladas'
            + ' FROM Tonelada__c WHERE ' + String.join(filtrosBase(), ' AND ');

        for (AggregateResult ar : Database.query(base + ' AND Cantidad_con_Signo__c >= 0 GROUP BY Variedad__c')) {
            VariedadAcum acum = variedadAcum(porVariedad, (Id) ar.get('variedadId'));
            if (acum == null) {
                sinVariedad = sinVariedad == null ? new VariedadAcum(null) : sinVariedad;
                acum = sinVariedad;
            }
            acum.credito += ar.get('toneladas') == null ? 0 : (Decimal) ar.get('toneladas');
        }
        for (AggregateResult ar : Database.query(base + ' AND Cantidad_con_Signo__c < 0 GROUP BY Variedad__c')) {
            VariedadAcum acum = variedadAcum(porVariedad, (Id) ar.get('variedadId'));
            if (acum == null) {
                sinVariedad = sinVariedad == null ? new VariedadAcum(null) : sinVariedad;
                acum = sinVariedad;
            }
            acum.debito += ar.get('toneladas') == null ? 0 : (Decimal) ar.get('toneladas');
        }
        Set<String> origenesEntrega = EstadoVarietal.ORIGENES_ENTREGA;
        for (AggregateResult ar : Database.query(base + ' AND Origen__c IN :origenesEntrega GROUP BY Variedad__c')) {
            VariedadAcum acum = variedadAcum(porVariedad, (Id) ar.get('variedadId'));
            if (acum == null) {
                acum = sinVariedad;
            }
            if (acum != null) {
                acum.entregas += ar.get('toneladas') == null ? 0 : (Decimal) ar.get('toneladas');
            }
        }

        try {
            for (SObject hijo : Database.query(
                'SELECT Variedad__c FROM Detalle_Variedad_CG__c WHERE Cuenta_Granaria__c = :cuentaGranariaId AND Variedad__c != null'
            )) {
                variedadAcum(porVariedad, (Id) hijo.get('Variedad__c'));
            }
        } catch (QueryException e) {
            System.debug(LoggingLevel.WARN, 'Detalle_Variedad_CG__c no disponible: ' + e.getMessage());
        }

        if (!porVariedad.isEmpty()) {
            for (Variedad__c v : [
                SELECT Id, Name, Nombre_Obtentor__c, Obtentor_Comercializa__r.Nombre_Obtentor__c
                FROM Variedad__c
                WHERE Id IN :porVariedad.keySet()
            ]) {
                VariedadAcum acum = porVariedad.get(v.Id);
                acum.nombre = v.Name;
                String comercial = v.Obtentor_Comercializa__r?.Nombre_Obtentor__c;
                acum.semillero = String.isNotBlank(comercial) ? comercial : v.Nombre_Obtentor__c;
            }
        }

        List<VariedadAcum> lista = new List<VariedadAcum>(porVariedad.values());
        if (sinVariedad != null) {
            sinVariedad.nombre = 'Sin variedad';
            lista.add(sinVariedad);
        }
        lista.sort();

        List<Map<String, Object>> salida = new List<Map<String, Object>>();
        for (VariedadAcum acum : lista) {
            salida.add(acum.toMap());
        }
        return salida;
    }

    private static VariedadAcum variedadAcum(Map<Id, VariedadAcum> porVariedad, Id variedadId) {
        if (variedadId == null) {
            return null;
        }
        if (!porVariedad.containsKey(variedadId)) {
            porVariedad.put(variedadId, new VariedadAcum(variedadId));
        }
        return porVariedad.get(variedadId);
    }

    @AuraEnabled
    public static Map<String, Object> getDetalle(
        Id cuentaGranariaId,
        String origen,
        String tipo,
        Id variedadId,
        String buscar,
        String cursorFecha,
        String cursorId
    ) {
        Datetime cursorDt = parseCursor(cursorFecha);
        Id cursorRecordId = String.isBlank(cursorId) ? null : (Id) cursorId;
        String buscarLike = likeTerm(buscar);

        List<String> filtros = filtrosBase();
        if (String.isNotBlank(origen)) {
            filtros.add('Origen__c = :origen');
        }
        agregarFiltrosTipoVariedad(filtros, tipo, variedadId);
        if (buscarLike != null) {
            filtros.add('Name LIKE :buscarLike');
        }
        if (cursorDt != null && cursorRecordId != null) {
            filtros.add('(CreatedDate < :cursorDt OR (CreatedDate = :cursorDt AND Id < :cursorRecordId))');
        }

        String soql = 'SELECT Id, Name, Origen__c, Cantidad_con_Signo__c, Fecha_Inicio__c, Etapa__c, CreatedDate'
            + ' FROM Tonelada__c WHERE ' + String.join(filtros, ' AND ')
            + ' ORDER BY CreatedDate DESC, Id DESC LIMIT ' + String.valueOf(DETALLE_PAGE + 1);

        List<Tonelada__c> filas = Database.query(soql);
        Boolean hayMas = filas.size() > DETALLE_PAGE;
        if (hayMas) {
            filas.remove(filas.size() - 1);
        }

        List<ToneladaWrapper> wrappers = new List<ToneladaWrapper>();
        for (Tonelada__c tn : filas) {
            wrappers.add(toWrapper(tn));
        }

        String nextFecha;
        String nextId;
        if (!filas.isEmpty()) {
            Tonelada__c ultima = filas[filas.size() - 1];
            nextFecha = ultima.CreatedDate.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
            nextId = ultima.Id;
        }

        return new Map<String, Object>{
            'filas' => wrappers,
            'hayMas' => hayMas,
            'cursorFecha' => nextFecha,
            'cursorId' => nextId
        };
    }

    @AuraEnabled
    public static String exportarCsv(Id cuentaGranariaId, String origen, String tipo, Id variedadId) {
        if (String.isBlank(origen)) {
            throw new AuraHandledException('Elegí un origen para descargar el CSV.');
        }

        List<String> filtros = filtrosBase();
        filtros.add('Origen__c = :origen');
        agregarFiltrosTipoVariedad(filtros, tipo, variedadId);
        String condicion = ' FROM Tonelada__c WHERE ' + String.join(filtros, ' AND ');

        Integer total = Database.countQuery('SELECT COUNT()' + condicion);
        if (total > CSV_MAX) {
            throw new AuraHandledException(
                'Ese origen tiene ' + total + ' movimientos. El CSV admite hasta ' + CSV_MAX + '. Usá Ver detalle para recorrerlo.'
            );
        }

        Cuenta_Granaria__c cuenta = consultarCuenta(cuentaGranariaId);
        Boolean trigo = cuenta.Cultivo__r != null && cuenta.Cultivo__r.Name == 'TRIGO';
        String campos = 'SELECT Name, Origen__c, Etapa__c, CreatedDate, Cantidad_con_Signo__c'
            + (trigo ? ', Variedad__r.Name' : '');
        List<Tonelada__c> filas = Database.query(
            campos + condicion
            + ' ORDER BY CreatedDate DESC, Id DESC LIMIT ' + String.valueOf(CSV_MAX)
        );

        String sep = ';';
        List<String> lineas = new List<String>();
        lineas.add(
            trigo
                ? 'Nombre' + sep + 'Origen' + sep + 'Etapa' + sep + 'Fecha creación' + sep + 'Variedad' + sep + 'Cantidad'
                : 'Nombre' + sep + 'Origen' + sep + 'Etapa' + sep + 'Fecha creación' + sep + 'Cantidad'
        );
        for (Tonelada__c tn : filas) {
            Decimal cantidad = tn.Cantidad_con_Signo__c == null ? 0 : tn.Cantidad_con_Signo__c;
            String fila = csvCampo(tn.Name) + sep
                + csvCampo(etiquetaOrigen(tn.Origen__c)) + sep
                + csvCampo(tn.Etapa__c) + sep
                + csvCampo(tn.CreatedDate == null ? '' : tn.CreatedDate.format('dd/MM/yyyy')) + sep;
            if (trigo) {
                fila += csvCampo(tn.Variedad__r == null ? '' : tn.Variedad__r.Name) + sep;
            }
            fila += String.valueOf(cantidad);
            lineas.add(fila);
        }
        return '\uFEFF' + String.join(lineas, '\n');
    }

    private static Cuenta_Granaria__c consultarCuenta(Id cuentaGranariaId) {
        return [
            SELECT Id, Name, Productor__c, Productor__r.Name, Campania__c, Campania__r.Name, Campania__r.Ano__c,
                   Cultivo__c, Cultivo__r.Name, Tecnologia__c, Saldo_Cuenta__c, Es_Carga_Manual__c,
                   Variedad__c, Variedad__r.Name, N_CUIT__c
            FROM Cuenta_Granaria__c
            WHERE Id = :cuentaGranariaId
            LIMIT 1
        ];
    }

    private static Map<String, Object> armarCuenta(Cuenta_Granaria__c cuenta) {
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

        return new Map<String, Object>{
            'nombre' => cuenta.Name,
            'productor' => cuenta.Productor__r.Name,
            'cuit' => cuenta.N_CUIT__c,
            'campania' => cuenta.Campania__c != null ? cuenta.Campania__r.Name : null,
            'campaniaPeriodo' => periodoCampania(cuenta.Campania__c != null ? cuenta.Campania__r.Ano__c : null),
            'cultivo' => cuenta.Cultivo__r.Name,
            'variedad' => cuenta.Variedad__r == null ? null : cuenta.Variedad__r.Name,
            'tecnologia' => cuenta.Tecnologia__c,
            'tecnologiaEtiqueta' => etiquetaTecnologia(cuenta.Tecnologia__c, cuenta.Cultivo__r?.Name),
            'saldo' => cuenta.Saldo_Cuenta__c,
            'esCompraHT' => cuenta.Campania__c == null,
            'esCargaManual' => cuenta.Es_Carga_Manual__c == true,
            'puedeGenerarConsumo' => evaluarPuedeGenerarConsumo(cuenta, saldoCompraHT),
            'saldoCompraHT' => saldoCompraHT,
            'compraHTId' => compraHTId,
            'cuentasRelacionadas' => cuentasRelacionadas
        };
    }

    private static String etiquetaTecnologia(String tecnologia, String cultivo) {
        if (tecnologia == 'Enlist E3/Conkesta E3') {
            return 'Enlist / Conkesta';
        }
        if (tecnologia == 'RR1/RR2 - BT/Convencional') {
            return cultivo == 'CEBADA' ? 'Convencional' : 'Aporte genético';
        }
        return tecnologia;
    }

    private static String periodoCampania(String ano) {
        if (String.isBlank(ano) || !ano.isNumeric() || ano.length() != 4) {
            return ano;
        }
        Integer anio = Integer.valueOf(ano);
        return String.valueOf(anio).right(2) + '/' + String.valueOf(anio + 1).right(2);
    }

    private static ToneladaWrapper toWrapper(Tonelada__c tn) {
        ToneladaWrapper wrapper = new ToneladaWrapper();
        wrapper.id = tn.Id;
        wrapper.nombre = tn.Name != null ? tn.Name : 'Sin nombre';
        wrapper.origen = etiquetaOrigen(tn.Origen__c);
        wrapper.cantidad = tn.Cantidad_con_Signo__c != null ? tn.Cantidad_con_Signo__c : 0;
        wrapper.esPositivo = wrapper.cantidad >= 0;
        wrapper.fechaInicio = tn.Fecha_Inicio__c != null ? String.valueOf(tn.Fecha_Inicio__c) : '';
        wrapper.fechaCreacion = tn.CreatedDate != null ? tn.CreatedDate.format('dd/MM/yyyy') : '';
        wrapper.etapa = tn.Etapa__c;
        return wrapper;
    }

    private static String etiquetaOrigen(String origen) {
        if (String.isBlank(origen)) {
            return 'Sin origen';
        }
        return ETIQUETA_ORIGEN.containsKey(origen) ? ETIQUETA_ORIGEN.get(origen) : origen;
    }

    private static List<String> filtrosBase() {
        return new List<String>{
            'Cuenta_Granaria__c = :cuentaGranariaId',
            'Fecha_Inicio__c <= TODAY',
            'Etapa__c != \'Pendiente\'',
            'Origen__c != \'Balance Anual\''
        };
    }

    private static void agregarFiltrosTipoVariedad(List<String> filtros, String tipo, Id variedadId) {
        if (tipo == TIPO_CREDITO) {
            filtros.add('Cantidad_con_Signo__c >= 0');
        } else if (tipo == TIPO_DEBITO) {
            filtros.add('Cantidad_con_Signo__c < 0');
        }
        if (variedadId != null) {
            filtros.add('Variedad__c = :variedadId');
        }
    }

    private static Datetime parseCursor(String cursorFecha) {
        if (String.isBlank(cursorFecha)) {
            return null;
        }
        return (Datetime) JSON.deserialize('"' + cursorFecha + '"', Datetime.class);
    }

    private static String likeTerm(String buscar) {
        if (String.isBlank(buscar)) {
            return null;
        }
        String clean = buscar.trim().replace('\\', '').replace('%', '').replace('_', '');
        return String.isBlank(clean) ? null : '%' + clean + '%';
    }

    private static String csvCampo(String valor) {
        String texto = valor == null ? '' : valor;
        if (texto.contains(';') || texto.contains('"') || texto.contains('\n')) {
            return '"' + texto.replace('"', '""') + '"';
        }
        return texto;
    }

    private class OrigenAcum {
        String origen;
        String tipo;
        Decimal toneladas = 0;
        Integer movimientos = 0;

        OrigenAcum(String origen, String tipo) {
            this.origen = origen;
            this.tipo = tipo;
        }

        Map<String, Object> toMap() {
            return new Map<String, Object>{
                'clave' => origen + '|' + tipo,
                'origen' => origen,
                'tipo' => tipo,
                'etiqueta' => etiquetaOrigen(origen),
                'toneladas' => toneladas,
                'movimientos' => movimientos,
                'esNegativo' => tipo == TIPO_DEBITO
            };
        }
    }

    private class VariedadAcum implements Comparable {
        Id variedadId;
        String nombre;
        String semillero;
        Decimal credito = 0;
        Decimal debito = 0;
        Decimal entregas = 0;

        VariedadAcum(Id variedadId) {
            this.variedadId = variedadId;
        }

        Decimal saldo() {
            return credito + debito;
        }

        String estado() {
            return EstadoVarietal.calcular(saldo(), entregas);
        }

        Integer grupo() {
            String e = estado();
            return e == 'Debe regularizar' ? 0 : (e == 'En regla' ? 1 : 2);
        }

        public Integer compareTo(Object otro) {
            VariedadAcum v = (VariedadAcum) otro;
            if (grupo() != v.grupo()) return grupo() - v.grupo();
            if (grupo() == 0 && saldo() != v.saldo()) return saldo() < v.saldo() ? -1 : 1;
            return (nombre == null ? '' : nombre).compareTo(v.nombre == null ? '' : v.nombre);
        }

        Map<String, Object> toMap() {
            return new Map<String, Object>{
                'variedadId' => variedadId,
                'nombre' => nombre,
                'semillero' => semillero,
                'credito' => credito,
                'debito' => debito,
                'saldo' => saldo(),
                'estado' => estado()
            };
        }
    }
}