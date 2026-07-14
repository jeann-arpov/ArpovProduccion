public without sharing class GraficoSojaController {

    @AuraEnabled(cacheable=true)
    public static List<Data> getData(){

        String idAccount = (!Test.isRunningTest()) ? [SELECT Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId()].Contact.AccountId : [SELECT Id FROM Account LIMIT 1].Id;

        List<Data> result = new List<Data>();

        for(AggregateResult ag : [SELECT Campana_Agricola__c, SUM(Bolsas_UP_Bolsas_50Kg__c) sumaBolsasUP, SUM(Bolsas_SF_50_Kg__c) sumaBolsasSF FROM Historial_UP_y_Fiscalizada__c WHERE Cultivo__c = 'SOJA' AND Cuenta__c = :idAccount GROUP BY Campana_Agricola__c]){

            Data dt = new Data();
            dt.campana = String.valueOf(ag.get('Campana_Agricola__c'));
            dt.sumaBolsasUP = Integer.valueOf(ag.get('sumaBolsasUP'));
            dt.sumaBolsasSF = Integer.valueOf(ag.get('sumaBolsasSF'));

            result.add(dt);

        }

        return result;

    }

    public class Data{
        @AuraEnabled
        public String campana;
        @AuraEnabled
        public Integer sumaBolsasUP;
        @AuraEnabled
        public Integer sumaBolsasSF; 
    }

}