public without sharing class CreateTransactionController {

    @AuraEnabled(Cacheable=true)
    public static List<Account> getObtentores(){
       return [SELECT Id, Name FROM Account WHERE RecordType.DeveloperName = 'Obtentor' AND Id_SGL__c != 'AAA' AND Name != 'Sembrá Evolución' ORDER BY Name ASC];
    }

    @AuraEnabled(Cacheable=true)
    public static List<Campana_Agricola__c> getCampaigns(){
       return [SELECT Id, Name, Cultivo__r.Name FROM Campana_Agricola__c WHERE Estado__c = 'Activa' AND Mostrar_en_Minisitio__c = true ORDER BY Name ASC];
    }

}