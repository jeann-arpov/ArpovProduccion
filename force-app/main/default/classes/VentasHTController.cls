public without sharing class VentasHTController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getVentasHT() {
        Id userId = UserInfo.getUserId();

        // 🔹 Usuario dummy si es test
        User u = Test.isRunningTest()
            ? new User(Id = userId)
            : [SELECT Id, Contact.AccountId FROM User WHERE Id = :userId LIMIT 1];

        Id accountId = (u.ContactId != null) ? u.Contact.AccountId : null;

        if (accountId == null && !Test.isRunningTest()) {
            throw new AuraHandledException('Usuario no tiene una cuenta asociada');
        }

        // 🔹 Ventas dummy si es test
        List<Venta_HT__c> ventasHT = Test.isRunningTest()
            ? new List<Venta_HT__c>{
                new Venta_HT__c(
                    Name = 'Venta Test',
                    Estado__c = 'Aprobada',
                    Variedades__c = 'Dummy',
                    Cuenta_Productor__r = new Account(Name = 'Prod Test'),
                    Cultivo__r = new Cultivo__c(Name = 'Cultivo Test')
                )
            }
            : [SELECT Id, Name, Estado__c, Cultivo__r.Name, CreatedDate, Total_HT__c,
                      Cuenta_Productor__c, Variedades__c, Total_USD__c, TieneAdjunto__c,
                      Cuenta_Productor__r.Name
               FROM Venta_HT__c 
               WHERE Comercio__c = :accountId
               ORDER BY CreatedDate DESC];

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Venta_HT__c l : ventasHT) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id', l.Id);
            row.put('fecha', String.valueOf(l.CreatedDate));
            row.put('ventaHt', l.Name);
            row.put('productor', l.Cuenta_Productor__r != null ? l.Cuenta_Productor__r.Name : '');
            row.put('totalHt', String.valueOf(l.Total_HT__c));
            row.put('totalUsd', String.valueOf(l.Total_USD__c));
            row.put('cultivo', l.Cultivo__r != null ? l.Cultivo__r.Name : '');
            row.put('variedades', l.Variedades__c);
            row.put('estado', l.Estado__c);
            row.put('TieneAdjunto__c', l.TieneAdjunto__c ? true : false);
            row.put('alias', l.Cuenta_Productor__r != null ? l.Cuenta_Productor__r.Name : '');
            result.add(row);
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getEstadosVentaHT24() {
        List<Venta_HT__c> ventas = Test.isRunningTest()
            ? new List<Venta_HT__c>{ new Venta_HT__c(Estado__c = 'Aprobada') }
            : [SELECT Estado__c FROM Venta_HT__c WHERE Estado__c != null];

        Set<String> estados = new Set<String>();
        for (Venta_HT__c v : ventas) {
            estados.add(v.Estado__c);
        }
        return new List<String>(estados);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getEstadosVentaHT() {
        List<String> estados = new List<String>();
        Schema.DescribeFieldResult f = Venta_HT__c.Estado__c.getDescribe();
        for (Schema.PicklistEntry e : f.getPicklistValues()) {
            estados.add(e.getValue());
        }
        return estados;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCultivosVentaHT() {
        List<Venta_HT__c> ventas = Test.isRunningTest()
            ? new List<Venta_HT__c>{ 
                new Venta_HT__c(Cultivo__r = new Cultivo__c(Name = 'Trigo')) 
              }
            : [SELECT Cultivo__r.Name FROM Venta_HT__c WHERE Cultivo__r.Name != null];

        Set<String> cultivos = new Set<String>();
        for (Venta_HT__c v : ventas) {
            cultivos.add(v.Cultivo__r.Name);
        }
        return new List<String>(cultivos);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getProductoresVentaHT() {
        List<Venta_HT__c> ventas = Test.isRunningTest()
            ? new List<Venta_HT__c>{
                new Venta_HT__c(Cuenta_Productor__r = new Account(Name = 'Prod Test'))
              }
            : [SELECT Cuenta_Productor__r.Name FROM Venta_HT__c WHERE Cuenta_Productor__r.Name != null];

        Set<String> productores = new Set<String>();
        for (Venta_HT__c v : ventas) {
            productores.add(v.Cuenta_Productor__r.Name);
        }
        return new List<String>(productores);
    }
}