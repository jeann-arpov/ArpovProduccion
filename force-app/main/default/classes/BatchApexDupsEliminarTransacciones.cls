global with sharing class BatchApexDupsEliminarTransacciones implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global Lote__c lote;
    
    global BatchApexDupsEliminarTransacciones(Lote__c lote){
        this.lote = lote;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        return Database.getQueryLocator([SELECT ID FROM Transaccion__c WHERE Lote__c = :lote.Id ]);
        
    }
    
    global void execute(Database.BatchableContext BC, List<Transaccion__c> scope){
        
        Set<String> transaccionesIds = new Set<String>();
        for(Transaccion__c t: scope){
            transaccionesIds.add(t.Id);
        }
        for(List<Case> cs : [SELECT ID FROM Case WHERE DUP__c IN :transaccionesIds]){
            delete cs;
        }
        delete scope;
    }
    
    global void finish(Database.BatchableContext BC){
        BatchApexDupsEliminarRemesas batch = new BatchApexDupsEliminarRemesas(lote);
        ID batchId = Database.executeBatch(batch, 2000);
        Batch_Lote__c batchLote = new Batch_Lote__c();
        batchLote.ID_Batch__c = batchId;
        batchLote.Lote__c = lote.Id;
        insert batchLote;
    }
    
}