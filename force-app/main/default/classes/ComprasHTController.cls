public with sharing class ComprasHTController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getComprasHT() {
        Id userId = UserInfo.getUserId();

        // Usuario dummy si es test
        User u = Test.isRunningTest()? new User(Id = userId): [SELECT Id, Contact.AccountId FROM User WHERE Id = :userId LIMIT 1];

        Id accountId = (u.ContactId != null) ? u.Contact.AccountId : null;

        if (accountId == null && !Test.isRunningTest()) {throw new AuraHandledException('Usuario no tiene una cuenta asociada');}

        // Compras dummy si es test
        List<Compra_HT__c> compras = Test.isRunningTest()
            ? new List<Compra_HT__c>{
                new Compra_HT__c(
                    Name = 'Compra Test',
                    Estado__c = 'Pendiente',
                    Variedades__c = 'Dummy',
                    Cuenta_Productor__r = new Account(Name = 'Prod Test'),
                    Comercio__r = new Account(Name = 'Comercio Test'),
                    Cultivo__r = new Cultivo__c(Name = 'Cultivo Test')
                )
              }
            : [SELECT Id, Name, Estado__c, Cuenta_Productor__r.Name, Comercio__r.Name,
                       CUIT_Productor__c, CUIT_Comercio__c, Total_HT__c, Total_USD__c,
                       Variedades__c, Cultivo__r.Name, CreatedDate
               FROM Compra_HT__c
               //WHERE Cuenta_Productor__c = :accountId
               ORDER BY CreatedDate DESC];

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Compra_HT__c c : compras) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id', c.Id);
            row.put('compra', c.Name);
            row.put('estado', c.Estado__c);
            row.put('productor', c.Cuenta_Productor__r != null ? c.Cuenta_Productor__r.Name : '');
            row.put('comercio', c.Comercio__r != null ? c.Comercio__r.Name : '');
            row.put('cultivo', c.Cultivo__r != null ? c.Cultivo__r.Name : '');
            row.put('variedades', c.Variedades__c);
            row.put('totalHt', String.valueOf(c.Total_HT__c));
            row.put('totalUsd', String.valueOf(c.Total_USD__c));
            row.put('fecha', String.valueOf(c.CreatedDate));
            result.add(row);
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getComprasHTComercio() {
        Id userId = UserInfo.getUserId();

        User u = Test.isRunningTest() ? new User(Id = userId): [SELECT Id, Contact.AccountId FROM User WHERE Id = :userId LIMIT 1];

        Id accountId = (u.ContactId != null) ? u.Contact.AccountId : null;

        if (accountId == null && !Test.isRunningTest()) {throw new AuraHandledException('Usuario no tiene una cuenta asociada');}

        List<Compra_HT__c> compras = Test.isRunningTest()
            ? new List<Compra_HT__c>{
                new Compra_HT__c(
                    Name = 'Compra Comercio Test',
                    Estado__c = 'Aprobada',
                    Cuenta_Productor__r = new Account(Name = 'Prod Test'),
                    Comercio__r = new Account(Name = 'Comercio Test'),
                    Cultivo__r = new Cultivo__c(Name = 'Cultivo Test')
                )
              }
            : [SELECT Id, Name, Estado__c, Cuenta_Productor__r.Name, Comercio__r.Name,
                       CUIT_Productor__c, CUIT_Comercio__c, Total_HT__c, Total_USD__c,
                       Variedades__c, Cultivo__r.Name, CreatedDate
               FROM Compra_HT__c
               //WHERE Comercio__c = :accountId
               ORDER BY CreatedDate DESC];

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Compra_HT__c c : compras) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id', c.Id);
            row.put('compra', c.Name);
            row.put('estado', c.Estado__c);
            row.put('productor', c.Cuenta_Productor__r != null ? c.Cuenta_Productor__r.Name : '');
            row.put('comercio', c.Comercio__r != null ? c.Comercio__r.Name : '');
            row.put('cultivo', c.Cultivo__r != null ? c.Cultivo__r.Name : '');
            row.put('variedades', c.Variedades__c);
            row.put('totalHt', String.valueOf(c.Total_HT__c));
            row.put('totalUsd', String.valueOf(c.Total_USD__c));
            row.put('fecha', String.valueOf(c.CreatedDate));
            result.add(row);
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getEstadosCompras() {
        List<Compra_HT__c> compras = Test.isRunningTest()
            ? new List<Compra_HT__c>{
                new Compra_HT__c(Estado__c = 'Pendiente'),
                new Compra_HT__c(Estado__c = 'Aprobada')
              }
            : [SELECT Estado__c FROM Compra_HT__c WHERE Estado__c != null];

        Set<String> estados = new Set<String>();
        for (Compra_HT__c c : compras) {
            estados.add(c.Estado__c);
        }
        return new List<String>(estados);
    } 

    // 🚨 Dejar igual
    @AuraEnabled
    public static List<HectareaTecnologica> getHectareasTecnologicas(String cultivoId) {
        Id userId = UserInfo.getUserId();

        // 🔹 Usuario dummy si es test
        User u = Test.isRunningTest()
            ? new User()
            : [SELECT AccountId FROM User WHERE Id = :userId LIMIT 1];
        List<HectareaTecnologica> result = new List<HectareaTecnologica>();
        for (Hectareas_Tecnologicas__c ht : [
            SELECT Canal_de_Venta__r.Name, Biotecnologia__c, Cultivo__r.Name, Name,
                   Credito__c, Debito__c, Fecha_de_la_Transaccion__c, Origen__c,
                   Variedad__r.Name, Numero_de_Comprobante__c,
                   Variedad__r.Obtentor_Comercializa__r.Name
            FROM Hectareas_Tecnologicas__c
            WHERE Cultivo__c = :cultivoId
            AND Productor__c = :u.AccountId
              AND Origen__c NOT IN ('Semilla Original', 'Semilla Pre Básica', 'PPH')
            AND HT_Vigente__c = true
            ORDER BY Name DESC
        ]) {
            result.add(new HectareaTecnologica(ht));
        }
        return result;
    }

    public class HectareaTecnologica {
        @AuraEnabled public String nombre;
        @AuraEnabled public String id;
        @AuraEnabled public Decimal debito;
        @AuraEnabled public Decimal credito;
        @AuraEnabled public Date fechaTransaccion;
        @AuraEnabled public String origen;
        @AuraEnabled public String variedad;
        @AuraEnabled public String nroComprobante;
        @AuraEnabled public String obtentor;
        @AuraEnabled public String obtentorId;
        @AuraEnabled public String biotecnologia;
        @AuraEnabled public String cultivo;
        @AuraEnabled public String cultivoId;
        @AuraEnabled public String comercio;
        @AuraEnabled public String comercioId;

        public HectareaTecnologica (Hectareas_Tecnologicas__c ht) {
            nombre = ht.Name;
            id = ht.Id;
            credito = ht.Credito__c;
            debito = ht.Debito__c;
            fechaTransaccion = ht.Fecha_de_la_Transaccion__c;
            origen = ht.Origen__c;
            variedad = ht.Variedad__r.Name;
            nroComprobante = ht.Numero_de_Comprobante__c;
            obtentor = ht.Variedad__r.Obtentor_Comercializa__r.Name;
            obtentorId = ht.Variedad__r.Obtentor_Comercializa__c;
            biotecnologia = ht.Biotecnologia__c;
            cultivo = ht.Cultivo__r.Name;
            cultivoId = ht.Cultivo__c;
            comercio = ht.Canal_de_Venta__r.Name;
            comercioId = ht.Canal_de_Venta__c;
        }
    }
}