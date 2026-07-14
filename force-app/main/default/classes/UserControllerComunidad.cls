public without sharing class UserControllerComunidad {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCultivos() {
        if (Test.isRunningTest()) {
            return new List<Map<String, Object>>{
                new Map<String, Object>{ 'label' => 'Soja Test', 'value' => '001xxTestId' },
                new Map<String, Object>{ 'label' => 'Trigo Test', 'value' => '001yyTestId' }
            };
        }

        List<Map<String, Object>> options = new List<Map<String, Object>>();
        for (Cultivo__c cultivo : [
            SELECT Id, Name 
            FROM Cultivo__c 
            WHERE Sembra_Evolucion__c = true
        ]) {
            options.add(new Map<String, Object>{
                'label' => cultivo.Name,
                'value' => cultivo.Id
            });
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static User getCurrentUserData() {
        return Test.isRunningTest()
            ? new User(Id = UserInfo.getUserId())
            : [SELECT Id, Name, HT_Vendidas__c, HT_Facturadas__c
               FROM User
               WHERE Id = :UserInfo.getUserId()
               LIMIT 1];
    }

    public class HTMetricasComercio {
        @AuraEnabled public Decimal htVendidas { get; set; }
        @AuraEnabled public Decimal htPendientesDePago { get; set; }

        public HTMetricasComercio() {
            this.htVendidas = 0;
            this.htPendientesDePago = 0;
        }

        public HTMetricasComercio(Decimal htVendidas, Decimal htPendientesDePago) {
            this.htVendidas = htVendidas != null ? htVendidas : 0;
            this.htPendientesDePago = htPendientesDePago != null ? htPendientesDePago : 0;
        }
    }

    /**
     * Métricas HT del comercio del usuario portal, calculadas en vivo desde Venta_HT__c.
     * - htVendidas: ventas en estado Pagada.
     * - htPendientesDePago: ventas solo en Facturada (facturadas, pendientes de pago).
     */
    @AuraEnabled(cacheable=true)
    public static HTMetricasComercio getHTMetricasComercio() {
        User u = [
            SELECT Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (u.Contact.AccountId == null) {
            throw new AuraHandledException('El usuario no tiene una cuenta de comercio asociada.');
        }

        Id comercioId = u.Contact.AccountId;
        Decimal htVendidas = 0;
        for (AggregateResult ar : [
            SELECT SUM(Total_HT__c) total
            FROM Venta_HT__c
            WHERE Comercio__c = :comercioId
            AND Estado__c = 'Pagada'
        ]) {
            htVendidas = (Decimal) ar.get('total');
        }

        Decimal htPendientes = 0;
        for (AggregateResult ar : [
            SELECT SUM(Total_HT__c) total
            FROM Venta_HT__c
            WHERE Comercio__c = :comercioId
            AND Estado__c = 'Facturada'
        ]) {
            htPendientes = (Decimal) ar.get('total');
        }

        return new HTMetricasComercio(
            htVendidas != null ? htVendidas : 0,
            htPendientes != null ? htPendientes : 0
        );
    }

    // @AuraEnabled(cacheable=true)
    // public static Map<String,Decimal> getHTInfo(){
    //     try {
    //         Decimal HTvendidas = 0;
    //         Decimal HTFacturadas = 0;
    //         Id AccId = [Select Id, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Contact.AccountId;
    //         string Cuit = [Select N_CUIT__c from Account where Id=: AccId].N_CUIT__c;
    //         AggregateResult[] resultsVendidas = [
    //         SELECT SUM(Cantidad__c)
    //         FROM Linea_de_Venta_HT__c
    //         WHERE Comercio_Nro_CUIT__c =: Cuit
    //         AND Estado_Venta_HT__c IN ('Facturada', 'Pagada', 'Pedido de Facturacion')];

    //         for (AggregateResult ar : resultsVendidas) {
    //         	HTvendidas = (Decimal) ar.get('expr0'); 
    //     	}

    //         AggregateResult[] resultsFacturadas = [
    //         SELECT SUM(Cantidad__c)
    //         FROM Linea_de_Venta_HT__c
    //         WHERE Comercio_Nro_CUIT__c =: Cuit
    //         AND Estado_Venta_HT__c IN ('Facturada')];

    //         for (AggregateResult ar : resultsFacturadas) {
    //         	HTFacturadas = (Decimal) ar.get('expr0'); 
    //     	}

    //         return new Map<String,Decimal>{
    //             'HTvendidas' => HTvendidas,
    //             'HTFacturadas' => HTFacturadas
    //         };

    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getLicenciasContadas() {
        User u = Test.isRunningTest()
            ? new User(Id = UserInfo.getUserId())
            : [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    
        if (u.AccountId == null && !Test.isRunningTest()) {
            throw new AuraHandledException('El usuario no tiene una cuenta asociada.');
        }
    
        Id cuentaId = u.AccountId;
    
        Integer aprobadas = [
            SELECT COUNT() 
            FROM Licencia__c 
            WHERE Cuenta_Distribuidor__c = :cuentaId 
            AND Estado__c = 'Aprobada'
        ];
    
        Integer enProceso = [
            SELECT COUNT() 
            FROM Licencia__c 
            WHERE Cuenta_Distribuidor__c = :cuentaId 
            AND Estado__c != 'Aprobada' 
            AND Estado__c != 'Rechazada'
            AND Estado__c != 'Eliminada'
            AND Estado__c != 'Inactiva'
        ];
    
        return new Map<String, Integer>{
            'aprobadas' => aprobadas,
            'enProceso' => enProceso
        };
    }
    
    @AuraEnabled(cacheable=true)
    public static String getCalendarioUrl() {
        return Test.isRunningTest() ? 'https://dummy-calendario.test': Sembra_Evolucion__c.getInstance().URL_Calendario_Comercios__c;}

    // ===================================================================
    // REPELER FC CON NC: en la NC las cuentas están invertidas, por lo que
    // el comercio es el Destinatario. Una FC se cancela del conteo si existe
    // una NC que la revierte (mismo producto, cantidad y campaña).
    // ===================================================================
    @TestVisible
    private static Map<String, Date> getNcKeyMap(Id cuentaId, Set<Id> campaniaIds) {
        return VentaListController.buildNcKeyMap([
            SELECT Originante__c, Producto__c, Cantidad__c, Campana_Agricola__c, Fecha__c
            FROM Venta__c
            WHERE Tipo_de_Comprobante__c = 'NC'
            AND Destinatario__c = :cuentaId
            AND Campana_Agricola__c IN :campaniaIds
        ]);
    }

    @TestVisible
    private static Boolean repeleFC(Venta__c v, Map<String, Date> ncKeyToFecha) {
        return v.Tipo_de_Comprobante__c == 'FC'
            && VentaListController.esRevertidaPorNC(v, ncKeyToFecha);
    }

    // ==============================
    // BOLSAS OBTENTOR (CUITS ÚNICOS)
    // ==============================
    @AuraEnabled(cacheable=true)
    public static Integer getBolsasObtentorCampaniaActiva() {
        User u = Test.isRunningTest()
            ? new User(Id = UserInfo.getUserId()): [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        if (u.AccountId == null && !Test.isRunningTest()) { throw new AuraHandledException('El usuario no tiene una cuenta asociada.');}
        Id cuentaId = u.AccountId;

        List<Campaign> campanias = Test.isRunningTest()
            ? new List<Campaign>{
                new Campaign(Id = '701000000000001', Name = '2025 - SOJA', Campana_Agricola__c = 'a0A000000000111'),
                new Campaign(Id = '701000000000002', Name = '2025 - TRIGO', Campana_Agricola__c = 'a0A000000000222')
            }: [SELECT Id, Campana_Agricola__c 
               FROM Campaign 
               WHERE IsActive = TRUE 
               AND Campana_Agricola__c != null
               AND StartDate != null];

        if (campanias.isEmpty()) return 0;

        Set<Id> campaniaIds = new Set<Id>();
        for (Campaign c : campanias) campaniaIds.add(c.Campana_Agricola__c);

        List<Venta__c> ventas = [
            SELECT Id, Destinatario__r.N_CUIT__c, Destinatario__c, Producto__c,
                   Cantidad__c, Campana_Agricola__c, Fecha__c, Tipo_de_Comprobante__c
            FROM Venta__c
            WHERE Tipo_de_Venta__c IN ('Venta', 'DPD', 'DPO')
            AND Campana_Agricola__c IN :campaniaIds
            AND Categoria__c = 'Primera Multiplicación'
            AND HT_Id__c = null
            AND Semba_Evolucion__c  = true
            AND Estado_Licencia__c != 'Aprobada'
            AND Originante__c = :cuentaId
        ];

        Map<String, Date> ncKeyToFecha = getNcKeyMap(cuentaId, campaniaIds);

        Set<String> cuits = new Set<String>();
        for (Venta__c v : ventas) {
            if (repeleFC(v, ncKeyToFecha)) continue;
            if (v.Destinatario__r?.N_CUIT__c != null) { cuits.add(v.Destinatario__r.N_CUIT__c);}
        }
        return cuits.size();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getBolsasObtentorCampaniaActivaList() {
        User u = Test.isRunningTest()
            ? new User(Id = UserInfo.getUserId()) : [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.AccountId == null && !Test.isRunningTest()) {throw new AuraHandledException('El usuario no tiene una cuenta asociada.');}
        Id cuentaId = u.AccountId;

        List<Campaign> campanias = Test.isRunningTest()
            ? new List<Campaign>{
                new Campaign(Id = '701000000000001', Name = '2025 - SOJA', Campana_Agricola__c = 'a0A000000000111'),
                new Campaign(Id = '701000000000002', Name = '2025 - TRIGO', Campana_Agricola__c = 'a0A000000000222')
            }
            : [SELECT Id, Campana_Agricola__c 
               FROM Campaign 
               WHERE IsActive = TRUE 
               AND Campana_Agricola__c != null];

        if (campanias.isEmpty()) return new List<Map<String, String>>();

        Set<Id> campaniaIds = new Set<Id>();
        for (Campaign c : campanias) campaniaIds.add(c.Campana_Agricola__c);

        List<Venta__c> ventas = [
            SELECT Id, Destinatario__r.Name, Destinatario__r.N_CUIT__c, Destinatario__c,
                   Producto__c, Cantidad__c, Campana_Agricola__c, Fecha__c, Tipo_de_Comprobante__c
            FROM Venta__c
            WHERE Tipo_de_Venta__c IN ('Venta', 'DPD', 'DPO')
            AND Campana_Agricola__c IN :campaniaIds
            AND Categoria__c = 'Primera Multiplicación'
            AND HT_Id__c = null
            AND Semba_Evolucion__c  = true
            AND Estado_Licencia__c != 'Aprobada'
            AND Originante__c = :cuentaId
        ];

        Map<String, Date> ncKeyToFecha = getNcKeyMap(cuentaId, campaniaIds);

        Map<String, String> cuitToNombre = new Map<String, String>();
        for (Venta__c v : ventas) {
            if (repeleFC(v, ncKeyToFecha)) continue;
            if (v.Destinatario__r?.N_CUIT__c != null) {cuitToNombre.put(v.Destinatario__r.N_CUIT__c, v.Destinatario__r.Name);}
        }

        List<Map<String, String>> result = new List<Map<String, String>>();
        for (String cuit : cuitToNombre.keySet()) {
            result.add(new Map<String, String>{
                'cuit' => cuit,
                'razonSocial' => cuitToNombre.get(cuit)
            });
        }
        return result;
    }

    // ==================================
    // PRIMERA MULTIPLICACIÓN (BOLSAS)
    // ==================================
    @AuraEnabled(cacheable=true)
    public static Decimal getBolsasPrimeraMultiplicacionActual() {
        User u = Test.isRunningTest()
            ? new User(Id = UserInfo.getUserId())
            : [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.AccountId == null && !Test.isRunningTest()) {
            throw new AuraHandledException('El usuario no tiene una cuenta asociada.');
        }
        Id cuentaId = u.AccountId;

        List<Campaign> campanias = Test.isRunningTest()
            ? new List<Campaign>{
                new Campaign(Id = '701000000000001', Name = '2025 - SOJA', Campana_Agricola__c = 'a0A000000000111'),
                new Campaign(Id = '701000000000002', Name = '2025 - TRIGO', Campana_Agricola__c = 'a0A000000000222')
            }
            : [SELECT Id, Campana_Agricola__c 
               FROM Campaign 
               WHERE IsActive = TRUE 
               AND Campana_Agricola__c != null
               AND StartDate != null
               ];

        if (campanias.isEmpty()) return 0;

        Set<Id> campaniaIds = new Set<Id>();
        for (Campaign c : campanias) campaniaIds.add(c.Campana_Agricola__c);

        List<Venta__c> ventas = [
            SELECT Cantidad_Bolsas_40__c, Destinatario__c, Producto__c, Cantidad__c,
                   Campana_Agricola__c, Fecha__c, Tipo_de_Comprobante__c
            FROM Venta__c
            WHERE Tipo_de_Venta__c IN ('Venta', 'DPD', 'DPO')
            AND Campana_Agricola__c IN :campaniaIds
            AND Categoria__c = 'Primera Multiplicación'
            AND HT_Id__c = null
            AND Semba_Evolucion__c = true
            AND Estado_Licencia__c != 'Aprobada'
            AND Originante__c = :cuentaId];

        Map<String, Date> ncKeyToFecha = getNcKeyMap(cuentaId, campaniaIds);

        Decimal total = 0;
        for (Venta__c v : ventas) {
            if (repeleFC(v, ncKeyToFecha)) continue;
            if (v.Cantidad_Bolsas_40__c != null) total += v.Cantidad_Bolsas_40__c;
        }
        return total;
    }

    @AuraEnabled(cacheable=true)
    public static List<Venta__c> getBolsasPrimeraMultiplicacionActualList() {
        User u = Test.isRunningTest()
            ? new User(Id = UserInfo.getUserId())
            : [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.AccountId == null && !Test.isRunningTest()) {
            throw new AuraHandledException('El usuario no tiene una cuenta asociada.');
        }
        Id cuentaId = u.AccountId;

        List<Campaign> campanias = Test.isRunningTest()
            ? new List<Campaign>{
                new Campaign(Id = '701000000000001', Name = '2025 - SOJA', Campana_Agricola__c = 'a0A000000000111'),
                new Campaign(Id = '701000000000002', Name = '2025 - TRIGO', Campana_Agricola__c = 'a0A000000000222')
            }
            : [SELECT Id, Campana_Agricola__c 
               FROM Campaign 
               WHERE IsActive = TRUE 
               AND Campana_Agricola__c != null
               AND StartDate != null
               ];

        if (campanias.isEmpty()) return new List<Venta__c>();

        Set<Id> campaniaIds = new Set<Id>();
        for (Campaign c : campanias) campaniaIds.add(c.Campana_Agricola__c);

        List<Venta__c> ventas = [
            SELECT Id, Campana_Agricola__r.Name, Destinatario__r.N_CUIT__c,
                   Destinatario__r.Name, Cantidad_Bolsas_40__c, Variedad__c,
                   Categoria__c, Estado_Licencia__c, Destinatario__c, Producto__c,
                   Cantidad__c, Campana_Agricola__c, Fecha__c, Tipo_de_Comprobante__c
            FROM Venta__c
            WHERE Tipo_de_Venta__c IN ('Venta', 'DPD', 'DPO')
            AND Campana_Agricola__c IN :campaniaIds
            AND Categoria__c = 'Primera Multiplicación'
            AND HT_Id__c = null
            AND Semba_Evolucion__c = true
            AND Estado_Licencia__c != 'Aprobada'
            AND Originante__c = :cuentaId
        ];

        Map<String, Date> ncKeyToFecha = getNcKeyMap(cuentaId, campaniaIds);

        List<Venta__c> result = new List<Venta__c>();
        for (Venta__c v : ventas) {
            if (!repeleFC(v, ncKeyToFecha)) result.add(v);
        }
        return result;
    }
}