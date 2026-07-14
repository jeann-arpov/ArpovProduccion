public without sharing class GraficoObtentor {
    
    @AuraEnabled(cacheable=true)
    public static List<Campana> getData(Id accountId){
        if (accountId == null) accountId = (!Test.isRunningTest()) ? [SELECT Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId()].Contact.AccountId : [SELECT Id FROM Account LIMIT 1].Id;

        System.debug(accountId);
        Map<String,Campana> campanaByName = new Map<String,Campana>();
        Map<String,Obtentor> obtentorByKey = new Map<String,Obtentor>();

        for(AggregateResult ag : [SELECT Campana_Agricola__c, SUM(Bolsas_UP_Bolsas_50Kg__c) sumaBolsasUP, SUM(Bolsas_SF_50_Kg__c) sumaBolsasSF FROM Historial_UP_y_Fiscalizada__c WHERE Cuenta__c = :accountId GROUP BY Campana_Agricola__c]){

            Campana cp = new Campana();
            cp.key = String.valueOf(ag.get('Campana_Agricola__c'));
            cp.campana = String.valueOf(ag.get('Campana_Agricola__c'));
            cp.sumaBolsasUP = Integer.valueOf(ag.get('sumaBolsasUP'));
            cp.sumaBolsasSF = Integer.valueOf(ag.get('sumaBolsasSF'));
            cp.cantidad = getCantidad(cp.sumaBolsasSF,cp.sumaBolsasUP);

            campanaByName.put(cp.campana,cp);

        }

        for(AggregateResult ag : [SELECT Campana_Agricola__c, Obtentor__c, SUM(Bolsas_UP_Bolsas_50Kg__c) sumaBolsasUP, SUM(Bolsas_SF_50_Kg__c) sumaBolsasSF FROM Historial_UP_y_Fiscalizada__c WHERE Cuenta__c = :accountId GROUP BY Campana_Agricola__c,Obtentor__c]){

            String campana = String.valueOf(ag.get('Campana_Agricola__c'));

            if(!campanaByName.containsKey(campana)){
                continue;
            }

            Campana cp = campanaByName.get(campana);

            Obtentor ob = new Obtentor();

            ob.obtentor = String.valueOf(ag.get('Obtentor__c'));
            ob.sumaBolsasUP = Integer.valueOf(ag.get('sumaBolsasUP'));
            ob.sumaBolsasSF = Integer.valueOf(ag.get('sumaBolsasSF'));
            ob.cantidad = getCantidad(ob.sumaBolsasSF,ob.sumaBolsasUP);
            cp.children.add(ob);

            String key = campana+ob.obtentor;
            ob.key = key;

            obtentorByKey.put(key,ob);

        }

        for(AggregateResult ag : [SELECT Campana_Agricola__c, Obtentor__c, Variedad__c, SUM(Bolsas_UP_Bolsas_50Kg__c) sumaBolsasUP, SUM(Bolsas_SF_50_Kg__c) sumaBolsasSF FROM Historial_UP_y_Fiscalizada__c WHERE Cuenta__c = :accountId GROUP BY Campana_Agricola__c,Obtentor__c,Variedad__c]){

            String campana = String.valueOf(ag.get('Campana_Agricola__c'));
            String obtentor = String.valueOf(ag.get('Obtentor__c'));

            String key = campana+obtentor;

            if(!obtentorByKey.containsKey(key)){
                continue;
            }


            Variedad vd = new Variedad();

            vd.key = key + String.valueOf(ag.get('Variedad__c'));
            vd.variedad = String.valueOf(ag.get('Variedad__c'));
            vd.sumaBolsasUP = Integer.valueOf(ag.get('sumaBolsasUP'));
            vd.sumaBolsasSF = Integer.valueOf(ag.get('sumaBolsasSF'));
            vd.cantidad = getCantidad(vd.sumaBolsasSF,vd.sumaBolsasUP);
            
            obtentorByKey.get(key).children.add(vd);

        }

        return campanaByName.values();
    
    }

    private static Integer getCantidad(Integer bolsasSF, Integer bolsasUp){

        bolsasSF = (bolsasSF == null) ? 0 : bolsasSF;
        bolsasUp = (bolsasUp == null) ? 0 : bolsasUp;

        return bolsasSF * 40 + bolsasUp * 50;

    }

    public class Campana{
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String campana;
        @AuraEnabled
        public List<Obtentor> children = new List<Obtentor>();
        @AuraEnabled
        public Integer sumaBolsasUP;
        @AuraEnabled
        public Integer sumaBolsasSF; 
        @AuraEnabled
        public Integer cantidad; 
    }

    public class Obtentor{
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String obtentor;
        @AuraEnabled
        public List<Variedad> children = new List<Variedad>();
        @AuraEnabled
        public Integer sumaBolsasUP;
        @AuraEnabled
        public Integer sumaBolsasSF; 
        @AuraEnabled
        public Integer cantidad; 
    }

    public class Variedad{
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String variedad;
        @AuraEnabled
        public Integer sumaBolsasUP;
        @AuraEnabled
        public Integer sumaBolsasSF; 
        @AuraEnabled
        public Integer cantidad; 
    }


}