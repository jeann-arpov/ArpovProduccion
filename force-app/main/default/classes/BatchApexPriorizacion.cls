global with sharing class BatchApexPriorizacion implements Database.Batchable<sObject>, Database.Stateful {
    
    global PriorizacionesUtil util;
    
    global BatchApexPriorizacion (){
        this.util = new PriorizacionesUtil();
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        Map<String, Id> rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType);
        rtId.remove('Obtentor');
        String qry = 'SELECT ID, N_CUIT__c, Segmentacion_Productor_Invierno__c, Segmentacion_Productor_Verano__c FROM Account WHERE RecordTypeId IN (\'' + String.join(rtId.values(), '\',\'') + '\')';
        if(Test.isRunningTest()){
            qry += ' LIMIT 100';
        }
        System.debug(LoggingLevel.INFO, 'qry: ' + qry); 
        return Database.getQueryLocator(qry);
    }
    
    global void execute(Database.BatchableContext BC, List<Account> scope){
        Set<String> cuentasIds = new Set<String>();
        for(Account a : scope){
            cuentasIds.add(a.Id);
        }
        Date today = Date.today();
        List<Case> casosReprogramados = [SELECT ID, AccountId, (SELECT WhatId FROM Events WHERE ActivityDate > :today) FROM Case WHERE AccountId IN :cuentasIds];
        cuentasIds.clear();
        for(Case c : casosReprogramados){
            if(!c.Events.isEmpty()){
                cuentasIds.add(c.AccountId);
            }
        }
        util.armarGrupos(scope, cuentasIds);
    }
    
    global void finish(Database.BatchableContext BC){
        if(!Test.isRunningTest()){
            List<Campana_Agricola__c> campanas = [SELECT Temporada__c FROM Campana_Agricola__c WHERE Estado__c = 'Activa'];
            BatchApexPriorizacionDUPSUpdate batch = new BatchApexPriorizacionDUPSUpdate(100000, 1, campanas);
            Database.executeBatch(batch, 500);
        }
    }
    
}