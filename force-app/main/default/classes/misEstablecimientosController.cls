public without sharing class misEstablecimientosController {
    @AuraEnabled
    public static List<Establecimiento__c> getEstablecimientos() {
        Id userId = UserInfo.getUserId();
        Id accId = [SELECT AccountId from User where Id=: userId limit 1][0].AccountId; 
        list<Establecimiento__c> establecimientos = [SELECT id, name, Coordenadas__Latitude__s, Coordenadas__Longitude__s from Establecimiento__c where Productor__c =: accId];
        return establecimientos;
    }
}