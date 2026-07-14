global with sharing class BatchApexDupsEliminarRemesas implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global Lote__c lote;
    
    global BatchApexDupsEliminarRemesas(Lote__c lote){
        this.lote = lote;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        return Database.getQueryLocator([SELECT ID FROM Remesa__c WHERE Lote__c = :lote.Id]);
        
    }
    
    global void execute(Database.BatchableContext BC, List<Remesa__c> scope){
        
        delete scope;
    }
    
    global void finish(Database.BatchableContext BC){
        
    }
    
}