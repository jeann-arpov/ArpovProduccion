global with sharing class BatchApexDupsEliminarEmptyRemesas implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global Lote__c lote;
    
    global BatchApexDupsEliminarEmptyRemesas(Lote__c lote){
        this.lote = lote;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        return Database.getQueryLocator([SELECT ID FROM Remesa__c WHERE Lote__c = :lote.Id AND ID NOT IN (SELECT Remesa__c FROM Transaccion__c)]);
        
    }
    
    global void execute(Database.BatchableContext BC, List<Remesa__c> scope){
        
        delete scope;
        
    }
    
    global void finish(Database.BatchableContext BC){
        BatchApexDupsPDFs batch = new BatchApexDupsPDFs(lote);
        ID batchId = Database.executeBatch(batch, 50);
        Batch_Lote__c batchLote = new Batch_Lote__c();
        batchLote.ID_Batch__c = batchId;
        batchLote.Lote__c = lote.Id;
        insert batchLote;
    }
    
}