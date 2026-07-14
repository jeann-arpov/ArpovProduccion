global with sharing class BatchApexDupsEliminarLogs implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global Lote__c lote;
    
    global BatchApexDupsEliminarLogs(Lote__c lote){
        this.lote = lote;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        return Database.getQueryLocator([SELECT ID FROM Log__c WHERE Lote__c = :lote.Id]);
        
    }
    
    global void execute(Database.BatchableContext BC, List<Log__c> scope){
        
        delete scope;
    }
    
    global void finish(Database.BatchableContext BC){
        BatchApexDupsEliminarTransacciones batch = new BatchApexDupsEliminarTransacciones(lote);
        ID batchId = Database.executeBatch(batch, 2000);
        Batch_Lote__c batchLote = new Batch_Lote__c();
        batchLote.ID_Batch__c = batchId;
        batchLote.Lote__c = lote.Id;
        insert batchLote;
    }
    
}