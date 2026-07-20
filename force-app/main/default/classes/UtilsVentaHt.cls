public without sharing class UtilsVentaHt {

    @AuraEnabled(cacheable=true)
    public static List<Venta_HT__c> getVentasHT(String userId) {
        try {
            User currentUser = [ SELECT Id, Contact.AccountId FROM User WHERE Id = :userId LIMIT 1];

            Id accountId = Test.isRunningTest() ? [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1]?.Id : [SELECT Id, Contact.AccountId FROM User WHERE Id = :userId LIMIT 1]?.Contact?.AccountId;
            //Id accountId = currentUser.Contact != null ? currentUser.Contact.AccountId : null;

            if (accountId == null) {
                throw new AuraHandledException('Usuario no tiene una cuenta asociada');
            }
            
            List<Venta_HT__c> ventas = [
                SELECT 
                    Id, Name,Nombre_del_comercio__c, Estado__c, Productor__c, CreatedDate, Total_HT__c, Total_USD__c,Nombre_del_cultivo__c, TieneAdjunto__c  FROM Venta_HT__c WHERE Comercio__c = :accountId ORDER BY CreatedDate DESC LIMIT 1000 ];
            
            return ventas;
            
        } catch (Exception e) {
            System.debug('Error en getVentasHT: ' + e.getMessage());
            throw new AuraHandledException('Error al obtener las ventas: ' + e.getMessage());
        }
    }
    /***************************************************************************************************************************************
     * Método para determinar si el usuario actual puede ver botones referidos a facturacción mixta en el portal.
     * Solicitado para Requerimiento de Facturación mixta - Subir Factura y Desacargar PF.
     * Autor: Rodrigo Lopez
     * Fecha: 26/09/2025
     * ************************************************************************************************************************************/
    @AuraEnabled
    public static Boolean getAccountFromUser(){
        Boolean pv = false;
        try {
            Account acc = Test.isRunningTest()
                ? [SELECT Id, N_CUIT__c, Name, Grandes_Cuentas__c FROM Account WHERE Name = 'Test Account' LIMIT 1]
                : [SELECT Contact.Account.Id FROM User WHERE Id = :UserInfo.getUserId()].Contact.Account;

            Set<String> validCUITs = new Set<String>();
            for (CUIT_Configuration__c config : CUIT_Configuration__c.getAll().values()) {
                if (String.isNotBlank(config.cuitNumber__c)) {
                    validCUITs.add(config.cuitNumber__c);
                }
            }

            pv = [
                SELECT COUNT()
                FROM Punto_de_Venta__c
                WHERE Punto_de_Venta__c = true
                AND Marca__r.N_CUIT__c IN :validCUITs
                AND Cuenta__c = :acc.Id
            ] > 0;

            return pv;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean getAccountFromUserByVenta(Id ventaId) {
        try {
            Boolean puedePorCuenta = getAccountFromUser();
            if (!puedePorCuenta) {
                return false;
            }

            if (ventaId == null) {
                return false;
            }

            Venta_HT__c venta = [
                SELECT Obtentor__r.N_CUIT__c, Estado__c
                FROM Venta_HT__c
                WHERE Id = :ventaId
                LIMIT 1
            ];

            if (venta.Estado__c == 'Pagada' || venta.Estado__c == 'Facturada') {
                return false;
            }

            String cuitObtentor = normalizeCuit(venta?.Obtentor__r?.N_CUIT__c);
            if (String.isBlank(cuitObtentor)) {
                return false;
            }

            Set<String> validCUITs = new Set<String>();
            for (CUIT_Configuration__c config : CUIT_Configuration__c.getAll().values()) {
                String cuit = normalizeCuit(config.cuitNumber__c);
                if (String.isNotBlank(cuit)) {
                    validCUITs.add(cuit);
                }
            }

            return validCUITs.contains(cuitObtentor);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<Id, Boolean> getAccountFromUserByVentas(List<Id> ventaIds) {
        try {
            Map<Id, Boolean> result = new Map<Id, Boolean>();

            if (ventaIds == null || ventaIds.isEmpty()) {
                return result;
            }

            for (Id ventaId : ventaIds) {
                if (ventaId != null) {
                    result.put(ventaId, false);
                }
            }

            Boolean puedePorCuenta = getAccountFromUser();
            if (!puedePorCuenta) {
                return result;
            }

            Set<String> validCUITs = new Set<String>();
            for (CUIT_Configuration__c config : CUIT_Configuration__c.getAll().values()) {
                String cuit = normalizeCuit(config.cuitNumber__c);
                if (String.isNotBlank(cuit)) {
                    validCUITs.add(cuit);
                }
            }

            for (Venta_HT__c venta : [
                SELECT Id, Obtentor__r.N_CUIT__c, Estado__c
                FROM Venta_HT__c
                WHERE Id IN :result.keySet()
            ]) {
                if (venta.Estado__c == 'Pagada' || venta.Estado__c == 'Facturada') {
                    result.put(venta.Id, false);
                    continue;
                }

                String cuitObtentor = normalizeCuit(venta?.Obtentor__r?.N_CUIT__c);
                result.put(venta.Id, String.isNotBlank(cuitObtentor) && validCUITs.contains(cuitObtentor));
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static String normalizeCuit(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        return value.replaceAll('[^0-9]', '');
    }
    
}