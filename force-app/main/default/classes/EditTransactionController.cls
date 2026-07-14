public without sharing class EditTransactionController {
    
    @AuraEnabled
    public static Transaccion__c getTransaction(String transactionId) {
        return [select Estado__c, Obtentor__r.Name, Campana__r.Name, Campana__r.Cultivo__c, Cultivo__c, Nombre_de_la_cuenta__r.Name, (select Campana_Agricola__c, Producto__c, Unidad_de_Medida_Declarada__c, Cantidad_Declarada__c, Densidad_de_Siembra__c, Lugar_de_Siembra__c, Siembra_de_Segunda__c from Item_de_DUP__r) from Transaccion__c where id =: transactionId];
    }

    @AuraEnabled
    public static List<Item_de_DUP__c> saveChanges(String transactionId, String jsonDups) {
        //bug en prod si uso List<Item_de_DUP__c> como parametro no me llega el campo Producto__c
        List<Item_de_DUP__c> itemDups = (List<Item_de_DUP__c>) JSON.deserialize(jsonDups, List<Item_de_DUP__c>.class);

        //bug en sandbox, si uso Transaccion__c no me llega el campo de Cultivo__c
        Transaccion__c transaccion = [select id, campana__c, obtentor__c from Transaccion__c where id =: transactionId];

        User u = [select accountId, Email from User where id =: UserInfo.getUserId()];

        CreateItemDupController.associate(itemDups, transaccion);
        update new Transaccion__c(ID = transaccion.id, Respondida_via_Minisitio__c = true, Fecha_de_Respuesta__c = System.today(), correo_electronico__c = u.email);
        upsert itemDups;
        //delete [select id from Item_de_DUP__c where transaccion__c =: transaccion.id and id not in: itemDups];

        return itemDups;
    }
}