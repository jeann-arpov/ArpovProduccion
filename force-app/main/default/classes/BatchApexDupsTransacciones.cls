global with sharing class BatchApexDupsTransacciones implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global Lote__c lote;
    global DupsUtil dupsUtil;
    global String rtProductor;
    global String rtTransaccionDUP;
    global String rtTransaccionAuditoria ;
    
    global BatchApexDupsTransacciones(Lote__c lote){
        this.lote = lote;
        dupsUtil = new DupsUtil();
        //dupsUtil.inicializarDatos(lote);
        rtProductor = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Productor');
        rtTransaccionDUP = RecordTypeTool.getRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        rtTransaccionAuditoria = RecordTypeTool.getRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        
        String qry = 'SELECT Nombre_de_la_cuenta__c, Nombre_de_la_cuenta__r.No_Generar_DUP__c ,Cultivo__c, Campana__c, Obtentor__c, RecordTypeId, (SELECT Producto__c, Obtentor__c FROM Item_de_DUP__r WHERE Estado__c = \'Uso Propio\'), (SELECT Producto__r.Obtentor_Comercializa__c, Producto__r.Variedad__c, Campana__c, Obtentor__c  FROM Items_Auditorias__r WHERE Producto__r.Precio__c > 0 AND Producto__r.Family = \'Regalía Extendida\' AND Resultado__c = '+'\''+'Irregular'+'\''+' '+'AND'+' '+' Campana__c = \'' + lote.Campana__r.Nombre_de_Campana_Anterior__c + '\' ) FROM Transaccion__c WHERE (Campana__c= \'' + lote.Campana__r.Nombre_de_Campana_Anterior__c + '\' AND RecordTypeId = \'' + rtTransaccionDUP + '\') OR (Campana__c= null AND RecordTypeId = \'' + rtTransaccionAuditoria + '\' AND Estado__c != \'Borrador\')';
        if(Test.isRunningTest()){
            qry += ' LIMIT 100';
        }
        System.debug(LoggingLevel.INFO, 'qry: ' + qry); 
        return Database.getQueryLocator(qry);
    }
    
    global void execute(Database.BatchableContext BC, List<Transaccion__c> scope){
        List<Transaccion__c> transacciones = new List<Transaccion__c>();
        for(Transaccion__c t : scope){
            if(t.RecordTypeID == rtTransaccionAuditoria && !t.Items_Auditorias__r.isEmpty()){
                transacciones.add(t);
            } else if(t.RecordTypeID == rtTransaccionDUP && !t.Item_de_DUP__r.isEmpty()){
                transacciones.add(t);
            }
        }
        
        dupsUtil.dupsTransacciones(transacciones, lote);
    }
    
    global void finish(Database.BatchableContext BC){
        BatchApexDupsEliminarEmptyTransacciones batch = new BatchApexDupsEliminarEmptyTransacciones(lote);
        ID batchId = Database.executeBatch(batch, 2000);
        Batch_Lote__c batchLote = new Batch_Lote__c();
        batchLote.ID_Batch__c = batchId;
        batchLote.Lote__c = lote.Id;
        insert batchLote;
     
    }
    
}