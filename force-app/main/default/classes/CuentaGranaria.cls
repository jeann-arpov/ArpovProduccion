public without sharing class CuentaGranaria {

    // Wrapper para devolver campañas con su total de toneladas
    public class CampanaConTotales {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String ano;
        @AuraEnabled public String estado;
        @AuraEnabled public String cultivoName;
        @AuraEnabled public Decimal totalToneladas;
        @AuraEnabled public Decimal totalCompraHT;
        @AuraEnabled public Decimal saldoCuentaGranaria;
        @AuraEnabled public Boolean pphAdherida;
        @AuraEnabled public Boolean esActual;
    }

    private static final Set<String> ESTADOS_VISIBLES = new Set<String>{ 'Activa', 'Completa', 'En Preparación' };
    private static final Integer CAMPANAS_ANTERIORES_VISIBLES = 2;

    /**
     * Campañas que muestra Cuenta Granaria por cultivo: la actual primero y luego las 2 anteriores.
     * La actual es la última cuya ventana Sembrá Evolución (Fecha_Fin_SE__c) ya cerró, mismo criterio
     * con el que ObtenerCampana asigna las TNs que no son Compra Futura. Así la campaña nueva aparece
     * según las fechas cargadas en cada cultivo (Soja: marzo; Trigo/Cebada: noviembre).
     * Cultivos sin fechas SE usan Fecha_de_Inicio__c.
     */
    public static Map<Id, List<Campana_Agricola__c>> getCampanasVisiblesPorCultivo(Set<Id> cultivoIds) {
        Map<Id, List<Campana_Agricola__c>> campanasPorCultivo = new Map<Id, List<Campana_Agricola__c>>();
        Set<Id> cultivosConFechasSE = new Set<Id>();
        for (Campana_Agricola__c c : [SELECT Id, Name, Ano__c, Estado__c, Cultivo__c, Cultivo__r.Name,
                                             Fecha_de_Inicio__c, Fecha_Fin_SE__c
                                      FROM   Campana_Agricola__c
                                      WHERE  Cultivo__c IN :cultivoIds
                                      AND    Estado__c IN :ESTADOS_VISIBLES
                                      ORDER BY Ano__c DESC]) {
            if (String.isBlank(c.Ano__c) || !c.Ano__c.isNumeric()) continue;
            if (!campanasPorCultivo.containsKey(c.Cultivo__c)) {
                campanasPorCultivo.put(c.Cultivo__c, new List<Campana_Agricola__c>());
            }
            campanasPorCultivo.get(c.Cultivo__c).add(c);
            if (c.Fecha_Fin_SE__c != null) cultivosConFechasSE.add(c.Cultivo__c);
        }

        Date hoy = Date.today();
        Map<Id, List<Campana_Agricola__c>> result = new Map<Id, List<Campana_Agricola__c>>();
        for (Id cultivoId : campanasPorCultivo.keySet()) {
            List<Campana_Agricola__c> campanas = campanasPorCultivo.get(cultivoId);
            Boolean usaFechasSE = cultivosConFechasSE.contains(cultivoId);

            Campana_Agricola__c actual;
            Date fechaActual;
            for (Campana_Agricola__c c : campanas) {
                Date fecha = usaFechasSE ? c.Fecha_Fin_SE__c : c.Fecha_de_Inicio__c;
                Boolean iniciada = fecha != null && (usaFechasSE ? fecha < hoy : fecha <= hoy);
                if (iniciada && (fechaActual == null || fecha > fechaActual)) {
                    actual = c;
                    fechaActual = fecha;
                }
            }
            if (actual == null) continue;

            List<Campana_Agricola__c> visibles = new List<Campana_Agricola__c>{ actual };
            Integer anoActual = Integer.valueOf(actual.Ano__c);
            for (Campana_Agricola__c c : campanas) {
                if (visibles.size() > CAMPANAS_ANTERIORES_VISIBLES) break;
                if (Integer.valueOf(c.Ano__c) < anoActual) visibles.add(c);
            }
            result.put(cultivoId, visibles);
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> getLoadData(){
       return new Map<String, Object>{'cultivos' => [SELECT Id, Name, Fecha_Vencimiento_de_Tonelada__c, Fecha_Vencimiento_Tonelada__c FROM Cultivo__c WHERE Sembra_Evolucion__c = true]};
    }

    @AuraEnabled
    public static List<Plan_de_Siembra__c> getAdhesion(String cultivoId){
        List<Plan_de_Siembra__c> planesSiembra = [
            SELECT Parametro_PPH__r.Fecha_Vencimiento_PPH__c, Parametro_PPH__r.Campana__c 
            FROM Plan_de_Siembra__c 
            WHERE Productor__c = :CrearCompraController.getAccount().Id 
            AND Estado__c = 'Adherido' 
            AND Parametro_PPH__r.Cultivo__c = :cultivoId
            
        ];
        return planesSiembra;
    }

    // Obtiene las 3 campañas vigentes (actual + 2 anteriores) con el total de toneladas de cada una
    @AuraEnabled
    public static List<CampanaConTotales> getCampanasConTotales(String cultivoId, String tecnologias){
        List<String> values = tecnologias.split('/');
        // 1. Campañas visibles del cultivo, la actual primero
        Id cultivoIdValue = (Id) cultivoId;
        List<Campana_Agricola__c> campanas = getCampanasVisiblesPorCultivo(new Set<Id>{ cultivoIdValue }).get(cultivoIdValue);

        if (campanas == null || campanas.isEmpty()) return new List<CampanaConTotales>();
        Id campanaActualId = campanas[0].Id;

        // 2. Obtenemos los IDs de las campañas
        Set<Id> campanaIds = new Set<Id>();
        for (Campana_Agricola__c c : campanas) {
            campanaIds.add(c.Id);
        }

        // 3. Agregamos toneladas por campana para el productor (Compra HT Futura se suma aqui)
        Id productorId = CrearCompraController.getAccount().Id;
        Map<Id, Decimal> totalesPorCampana = new Map<Id, Decimal>();
        for (AggregateResult ar : [SELECT Campania__c campId, SUM(Cantidad_con_Signo__c) total
                                    FROM   Tonelada__c
                                    WHERE  Productor__c = :productorId
                                    AND    Campania__c IN :campanaIds
                                    AND    Biotecnologia__c IN :values
                                    AND    Fecha_Inicio__c <= TODAY
                                    AND    Etapa__c != 'Pendiente'
                                    AND    Origen__c != 'Balance Anual'
                                    AND    (Origen__c != 'Compra HT' 
                                           OR HT_Id__r.Linea_de_Compra_HT__r.Tipo_de_Compra__c != 'Disponible')
                                    AND (Origen__c != 'Consumo' OR Signo__c != -1)

                                    GROUP BY Campania__c]) {
            totalesPorCampana.put((Id)ar.get('campId'), (Decimal)ar.get('total'));
        }

        // 3b. Compra HT Disponible: obtener saldo de la Cuenta Granaria HT (sin campaña)
        Decimal totalCompraHTDisponible = 0;
        List<Cuenta_Granaria__c> cgHT = [SELECT Saldo_Cuenta__c
                                          FROM   Cuenta_Granaria__c
                                          WHERE  Productor__c = :productorId
                                          AND    Cultivo__c = :cultivoId
                                          AND    Tecnologia__c = :tecnologias
                                          AND    Campania__c = null
                                          LIMIT 1];
        if (!cgHT.isEmpty() && cgHT[0].Saldo_Cuenta__c != null) {
            totalCompraHTDisponible = cgHT[0].Saldo_Cuenta__c;
        }

        System.debug('productorId: ' + productorId);
        System.debug('Campanas encontradas: ' + campanas);
        System.debug('CultivoId: ' + cultivoId);

        // 3c. Saldos de Cuentas Granarias por campaña
        Map<Id, Decimal> saldosCuentaGranaria = new Map<Id, Decimal>();
        Map<Id, Boolean> pphAdheridaPorCampana = new Map<Id, Boolean>();
        for (Cuenta_Granaria__c cg : [SELECT Campania__c, Saldo_Cuenta__c, PPH_Adherida__c
                                       FROM   Cuenta_Granaria__c
                                       WHERE  Productor__c = :productorId
                                       AND    Campania__c IN :campanaIds
                                       AND Tecnologia__c = :tecnologias
                                       AND    Cultivo__c = :cultivoId]) {
            Decimal saldo = cg.Saldo_Cuenta__c != null ? cg.Saldo_Cuenta__c : 0;
            saldosCuentaGranaria.put(cg.Campania__c, saldo);
            if (cg.PPH_Adherida__c == true) {
                pphAdheridaPorCampana.put(cg.Campania__c, true);
            }
        }
        System.debug('Saldos de Cuenta Granaria encontrados: ' + saldosCuentaGranaria);

        // 4. Armamos la respuesta
        List<CampanaConTotales> result = new List<CampanaConTotales>();
        for (Campana_Agricola__c c : campanas) {
            CampanaConTotales cct = new CampanaConTotales();
            cct.id = c.Id;
            cct.name = c.Name;
            cct.ano = c.Ano__c;
            cct.estado = c.Estado__c;
            cct.cultivoName = c.Cultivo__r.Name;
            cct.totalToneladas = totalesPorCampana.containsKey(c.Id) ? totalesPorCampana.get(c.Id) : 0;
            cct.totalCompraHT = totalCompraHTDisponible;
            cct.saldoCuentaGranaria = saldosCuentaGranaria.containsKey(c.Id) ? saldosCuentaGranaria.get(c.Id) : 0;
            cct.pphAdherida = pphAdheridaPorCampana.containsKey(c.Id) ? pphAdheridaPorCampana.get(c.Id) : false;
            cct.esActual = c.Id == campanaActualId;
            result.add(cct);
        }

        return result;
    }

    // Plataformas que elige el productor en Cuenta Granaria (biotecnologías separadas por '/').
    public static final List<String> PLATAFORMAS = new List<String>{ 'Enlist E3/Conkesta E3', 'RR1/RR2 - BT/Convencional' };

    /**
     * Toneladas por campaña y plataforma (clave campanaId|plataforma), con los mismos filtros
     * que la tarjeta de campaña de getCampanasConTotales: mantener ambas consultas alineadas.
     */
    public static Map<String, Decimal> getTotalesPorCampanaYPlataforma(Id productorId, Set<Id> campanaIds) {
        Map<String, Decimal> totales = new Map<String, Decimal>();
        if (productorId == null || campanaIds == null || campanaIds.isEmpty()) return totales;

        Map<String, String> plataformaPorBiotecnologia = new Map<String, String>();
        for (String plataforma : PLATAFORMAS) {
            for (String biotecnologia : plataforma.split('/')) {
                plataformaPorBiotecnologia.put(biotecnologia.toLowerCase(), plataforma);
            }
        }
        List<String> biotecnologias = new List<String>();
        for (String plataforma : PLATAFORMAS) biotecnologias.addAll(plataforma.split('/'));

        for (AggregateResult ar : [SELECT Campania__c campId, Biotecnologia__c bio, SUM(Cantidad_con_Signo__c) total
                                    FROM   Tonelada__c
                                    WHERE  Productor__c = :productorId
                                    AND    Campania__c IN :campanaIds
                                    AND    Biotecnologia__c IN :biotecnologias
                                    AND    Fecha_Inicio__c <= TODAY
                                    AND    Etapa__c != 'Pendiente'
                                    AND    Origen__c != 'Balance Anual'
                                    AND    (Origen__c != 'Compra HT'
                                           OR HT_Id__r.Linea_de_Compra_HT__r.Tipo_de_Compra__c != 'Disponible')
                                    AND (Origen__c != 'Consumo' OR Signo__c != -1)
                                    GROUP BY Campania__c, Biotecnologia__c]) {
            String bio = (String) ar.get('bio');
            String plataforma = bio == null ? null : plataformaPorBiotecnologia.get(bio.toLowerCase());
            if (plataforma == null) continue;
            String key = (Id) ar.get('campId') + '|' + plataforma;
            Decimal total = (Decimal) ar.get('total');
            totales.put(key, (totales.containsKey(key) ? totales.get(key) : 0) + (total == null ? 0 : total));
        }
        return totales;
    }

    // Mantiene el método original por si se necesita solo la lista de campañas
    @AuraEnabled
    public static List<Campana_Agricola__c> getCampanas(String cultivoId){
        return [SELECT Id, Name, Ano__c, Estado__c, Cultivo__c, Cultivo__r.Name
                FROM   Campana_Agricola__c
                WHERE  Cultivo__c = :cultivoId
                AND    Ano__c != '2212'
                ORDER BY Ano__c DESC
                LIMIT 3];
    }

    // Obtiene toneladas por campaña (nuevo flujo por campaña)
    @AuraEnabled
    public static List<Tonelada__c> getToneladasByCampana(String cultivoId, String campanaId, String tecnologias){
        List<String> values = tecnologias.split('/');
        return [SELECT Fecha_Inicio__c, 
                       Fecha_Fin__c, 
                       Origen__c,
                       Cantidad_con_Signo__c,
                       CreatedDate,
                       Etapa__c,
                       TN_Vigente__c,
                       Campania__c,
                       Campania__r.Name
                FROM   Tonelada__c
                WHERE  Productor__c = :CrearCompraController.getAccount().Id 
                AND    Cultivo__c = :cultivoId 
                AND    Campania__c = :campanaId
                AND    Biotecnologia__c IN :values
                AND    Fecha_Inicio__c <= TODAY
                AND    Etapa__c != 'Pendiente'
                AND    Origen__c != 'Balance Anual'

                AND    HT_Id__r.Linea_de_Compra_HT__r.Tipo_de_Compra__c != 'Disponible'
            AND (Origen__c != 'Consumo' OR Signo__c != -1)
        ];
    }

    /* COMENTADO - Método original que filtraba por biotecnología
    @AuraEnabled
    public static List<Tonelada__c> getToneladas(String cultivoId, String tecnologias){
        List<String> values = tecnologias.split('/');
        return [SELECT Fecha_Inicio__c, 
                       Fecha_Fin__c, 
                       Origen__c,
                       Cantidad_con_Signo__c,
                       CreatedDate,
                       Etapa__c,
                       TN_Vigente__c
                FROM   Tonelada__c
                WHERE  Productor__c = :CrearCompraController.getAccount().Id 
                AND  Cultivo__c = :cultivoId 
                AND  Biotecnologia__c IN :values
                AND  Etapa__c != 'Pendiente'
                AND  TN_Vigente__c = true];
    }
    */

    @AuraEnabled
    public static String getDetalleBT(List<String> toneladasIds){

        List<Tonelada__c> toneladasBT = [SELECT Id, Mov_BolsaTech__r.CTG__c, Mov_BolsaTech__r.Peso_Neto__c, Mov_BolsaTech__r.CUIT_Titular__c, Mov_BolsaTech__r.Razon_Social_Destinatario__c, Mov_BolsaTech__r.Fecha_de_Entrega__c FROM Tonelada__c WHERE Id IN :toneladasIds AND Mov_Bolsatech__c != null];

        String columns = 'Codigo de Trazabilidad de Granos;Razon Social Destinatario;Fecha de Entrega;Peso neto;Cuit del titular' + '\n';

        String detail = '';
        for(Tonelada__c tn : toneladasBT){
            detail += tn.Mov_BolsaTech__r.CTG__c + ';' + tn.Mov_BolsaTech__r.Razon_Social_Destinatario__c + ';' + tn.Mov_BolsaTech__r.Fecha_de_Entrega__c + ';' + tn.Mov_Bolsatech__r.Peso_Neto__c + ';' + tn.Mov_Bolsatech__r.CUIT_Titular__c + '\n';
        }

        return columns + detail;
    }
}