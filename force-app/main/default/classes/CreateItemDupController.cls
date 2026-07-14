public without sharing class CreateItemDupController {
    
    @AuraEnabled
    public static List<Product2> getProducts(String obtentorId, String cultivoId) {
        return [SELECT Id, Variedad__c FROM Product2 WHERE Obtentor_Comercializa__c =: obtentorId AND Family = 'Regalía Extendida' AND Cultivo__c =: cultivoId AND IsActive = true AND precio__c > 0 ORDER BY Variedad__c ASC];
    }

    @AuraEnabled
    public static Transaccion__c getTransaction(String transactionId) {
        return [select Estado__c, Obtentor__c, Campana__c, Cultivo__c from Transaccion__c where id =: transactionId];
    }

    @AuraEnabled
    public static String createItemDups(String transactionJson, String jsonDups) {
        //bug en prod si uso List<Item_de_DUP__c> como parametro no me llega el campo Producto__c
        List<Item_de_DUP__c> itemDups = (List<Item_de_DUP__c>) JSON.deserialize(jsonDups, List<Item_de_DUP__c>.class);

        //bug en sandbox, si uso Transaccion__c no me llega el campo de Cultivo__c
        Transaccion__c transaccion = (Transaccion__c) JSON.deserialize(transactionJson, Transaccion__c.class);

        Boolean isNew = transaccion.id == null;

        if (transaccion.id == null) {
            User u = [select accountId, Email from User where id =: UserInfo.getUserId()];
            transaccion.Respondida_via_Minisitio__c = true;
            transaccion.Fecha_de_Respuesta__c = System.today();
            transaccion.Nombre_de_la_cuenta__c = u.accountId;
            transaccion.correo_electronico__c = u.email;
            insert transaccion;
        } else {
            update new Transaccion__c(Id = transaccion.id, Respondida_via_Minisitio__c = true);
        }

        associate(itemDups, transaccion);

        String dupsJson = JSON.serialize(Database.insert(itemDups, true));

        return isNew ? (String) transaccion.id : dupsJson;
    }

    public static void associate(List<Item_de_DUP__c> dups, Transaccion__c transaccion) {
        for (Item_de_DUP__c itemDup: dups) {
            if (itemDup.id == null) {
                itemDup.Transaccion__c = transaccion.id;
                itemDup.Campana_Agricola__c = transaccion.Campana__c;
                itemDup.Obtentor__c = transaccion.Obtentor__c;
                itemDup.Variedad_Agregada_Manualmente__c = true;
            }
        }
    }
}