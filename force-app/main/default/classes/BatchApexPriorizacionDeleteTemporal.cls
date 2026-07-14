global with sharing class BatchApexPriorizacionDeleteTemporal implements Database.Batchable<sObject>, Database.Stateful {
    
    global Boolean isFirst;
    
    global BatchApexPriorizacionDeleteTemporal(Boolean isFirst){
        this.isFirst = isFirst;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        return Database.getQueryLocator([SELECT ID FROM Orden_Intragrupo__c]);
    }
    
    global void execute(Database.BatchableContext BC, List<Orden_Intragrupo__c> scope){
        
        delete scope;
        Database.emptyRecycleBin(scope);
        
    }
    
    global void finish(Database.BatchableContext BC){
        
        if(isFirst && !Test.isRunningTest()){
            BatchApexPriorizacion batch = new BatchApexPriorizacion();
            Database.executeBatch(batch, 500);
        }
        
    }
    
}