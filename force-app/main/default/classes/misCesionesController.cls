public without sharing class misCesionesController {
    @AuraEnabled
    public static List<Cesion_HT__c> getCesiones() {
        Id userId = UserInfo.getUserId();
        Id accId = [SELECT AccountId from User where Id=: userId limit 1][0].AccountId; 
        list<Cesion_HT__c> Cesiones = [SELECT id,CreatedDate,  name,Cuenta_Cedente__r.Name, Tipo_de_Cesion__c,Estado__c, Variedades__c,Cultivo__r.Name from Cesion_HT__c where Cuenta_Cedente__c =: accId];
        return Cesiones;
    }
}