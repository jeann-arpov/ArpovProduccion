public without sharing class EstablecimientosMap {
    
    @AuraEnabled
    public static List<Establecimiento__c> getEstablecimientos(){
        return [SELECT Name, Coordenadas__latitude__s, Coordenadas__longitude__s FROM Establecimiento__c WHERE Productor__c = :CrearCompraController.getAccount().Id AND Origen__c = 'Propio'];
    }

    @AuraEnabled
    public static string getAccountId() {
        Id userId = UserInfo.getUserId();
        Id accId = [SELECT AccountId from User where Id=: userId limit 1][0].AccountId; 
        return accId;
    }


    @AuraEnabled
    public static String insertEstablecimiento(Map<String, Object> fieldMap) {
        try {
            Establecimiento__c Establecimiento = new Establecimiento__c();

            for (String key : fieldMap.keySet()) {
                // Usa el método SObject.put para asignar dinámicamente los valores
                Establecimiento.put(key, fieldMap.get(key));
            }
            insert Establecimiento;
            return 'Nuevo Establecimiento creado con exito';
        } catch (DmlException e) {
            return 'Error al crear el establecimiento: ' +e.getDmlMessage(0);
        } 
    }

}