/**
* @author Maximo Martinez
* @date 22/06/2020
* @description Clase con metodos utilitarios a toda la ORG
*/
public with sharing class Helper {
    
    /**
    * @author Maximo Martinez
    * @date 22/06/2020
    * @description Workaround para obtener un Session Id en Lightning para llamadas de API REST Internas de SF
    */
    public static String getSessionIdFromVFPage(PageReference visualforcePage){
        String content = (Test.isRunningTest()) ? 'Start_Of_Session_IdTESTEnd_Of_Session_Id' : visualforcePage.getContent().toString();
        Integer s = content.indexOf('Start_Of_Session_Id') + 'Start_Of_Session_Id'.length(),
                e = content.indexOf('End_Of_Session_Id');
        return content.substring(s, e);
    }


    /**
    * @author Maximo Martinez
    * @date 22/06/2020
    * @description Devuelve el Master RecordType de un SObject
    */
    public static Schema.RecordTypeInfo getMasterRecordType(String objectApiName){

        Schema.RecordTypeInfo masterRTInfo;

        Map<String,Schema.RecordTypeInfo> rtInfoByNames =  Schema.getGlobalDescribe().get(objectApiName).getDescribe().getRecordTypeInfosByName();

        for(String rtName : rtInfoByNames.keySet()){
            Schema.RecordTypeInfo rtInfo = rtInfoByNames.get(rtName);
            if(rtInfo.isMaster()){
                masterRTInfo = rtInfo;
                break;
            }
        }

        return masterRTInfo;

    }

    /**
    * @author Maximo Martinez
    * @date 07/07/2020
    * @description Obtenemos la cotizacion del dia de una moneda
    */
    public static Decimal getExchangeRate(String symbol){

        List<Tipo_de_Cambio__c> tipoDeCambio;
        
        //Obtengo la fecha de hoy
        Date today = Date.today();
        
        //Obtengo el día
        String dia = Datetime.now().format('E');
        
        if(dia == 'Mon' || dia == 'Tue' || dia == 'Wed' || dia == 'Thu' || dia == 'Fri'){
            tipoDeCambio = [SELECT Codigo_Univoco__c,Cotizacion__c,CreatedById,CreatedDate,Fecha__c,Id,IsDeleted,LastModifiedById,LastModifiedDate,LastReferencedDate,LastViewedDate,Moneda__c,Name,Nombre_Moneda__c,OwnerId,Simbolo__c,SystemModstamp,To_Currency__c FROM Tipo_de_Cambio__c WHERE To_Currency__c = 'ARS' AND moneda__r.Codigo_Univoco__c = :symbol  AND Fecha__c = :today LIMIT 1];
        }else{
            tipoDeCambio = [SELECT Codigo_Univoco__c,Cotizacion__c,CreatedById,CreatedDate,Fecha__c,Id,IsDeleted,LastModifiedById,LastModifiedDate,LastReferencedDate,LastViewedDate,Moneda__c,Name,Nombre_Moneda__c,OwnerId,Simbolo__c,SystemModstamp,To_Currency__c FROM Tipo_de_Cambio__c WHERE To_Currency__c = 'ARS' AND moneda__r.Codigo_Univoco__c = :symbol  AND Fecha__c <= :today LIMIT 1];    
        }

        return (tipoDeCambio.isEmpty()) ? 1 : tipoDeCambio[0].Cotizacion__c;

    }

}