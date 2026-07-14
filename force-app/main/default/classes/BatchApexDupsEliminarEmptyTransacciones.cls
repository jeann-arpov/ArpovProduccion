global with sharing class BatchApexDupsEliminarEmptyTransacciones implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global Lote__c lote;
    
    global BatchApexDupsEliminarEmptyTransacciones(Lote__c lote){
        this.lote = lote;
    }

    global BatchApexDupsEliminarEmptyTransacciones(){}
    
    
    global Database.QueryLocator start(Database.BatchableContext BC){

        if( lote == null){
            return Database.getQueryLocator([SELECT ID FROM Transaccion__c WHERE Lote__c!='a0MG000000dgtVA' AND RecordType.DeveloperName = 'DUP' AND ID NOT IN (SELECT Transaccion__c FROM Item_de_DUP__c)]);
        }
        
        return Database.getQueryLocator([SELECT ID FROM Transaccion__c WHERE Lote__c!='a0MG000000dgtVA' AND Lote__c = :lote.Id AND ID NOT IN (SELECT Transaccion__c FROM Item_de_DUP__c)]);
        
    }
    
    global void execute(Database.BatchableContext BC, List<Transaccion__c> scope){
        
        delete scope;
        
    }
    
    global void finish(Database.BatchableContext BC){
        
        if( lote == null){
            return;
        }

        BatchApexDupsEliminarEmptyRemesas batch = new BatchApexDupsEliminarEmptyRemesas(lote);
        ID batchId = Database.executeBatch(batch, 2000);
        Batch_Lote__c batchLote = new Batch_Lote__c();
        batchLote.ID_Batch__c = batchId;
        batchLote.Lote__c = lote.Id;
        insert batchLote;
    }
    
}