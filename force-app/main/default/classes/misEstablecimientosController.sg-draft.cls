public without sharing class misEstablecimientosController {
    @AuraEnabled
    public static List<Establecimiento__c> getEstablecimientos() {
        Id userId = UserInfo.getUserId();
        Id accId = [SELECT AccountId from User where Id=: userId limit 1][0].AccountId; 
        list<Establecimiento__c> establecimientos = [
            SELECT Id, Name, Coordenadas__Latitude__s, Coordenadas__Longitude__s, Vigente__c
            FROM Establecimiento__c
            WHERE Productor__c =: accId
            ORDER BY Name ASC
            LIMIT 200
        ];
        return establecimientos;
    }
}
