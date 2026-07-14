global with sharing class BatchApexDupsVentas implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global Lote__c lote;
    global DupsUtil dupsUtil;
    
    global BatchApexDupsVentas(Lote__c lote){
        this.lote = lote;
        dupsUtil = new DupsUtil();
        //dupsUtil.inicializarDatos(lote);
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        String rtProductor = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Productor');
        
        // Set de categorias que no deben ser
        Set<String> categoriasToSkip = new Set<String>{'Primera Multiplicación', 'Segunda Multiplicación', 'Tercera Multiplicación', 'Uso Propio', 'No Definida'};


        String qry = 'SELECT Campana_Agricola__c, Cultivo__c, Destinatario__r.No_Generar_DUP__c, Producto__c, Producto__r.Obtentor_Comercializa__c, Producto__r.Variedad__c, Destinatario__c, Originante__c, Tipo_de_Venta__c FROM Venta__c WHERE Tipo_de_Producto__c = \'Semilla Fiscalizada\' AND Campana_Agricola__c = \'' + lote.Campana__r.Nombre_de_Campana_Anterior__c + '\''+' AND '+'Tipo_de_Venta__c ='+'\''+'Venta'+'\''+' AND Categoria__c IN :categoriasToSkip';
        if(Test.isRunningTest()){
            qry += ' LIMIT 100';
        }
        System.debug(LoggingLevel.INFO, 'qry: ' + qry); 
        return Database.getQueryLocator(qry);
    }
    
    global void execute(Database.BatchableContext BC, List<Venta__c> scope){
        
        dupsUtil.dupsVentas(scope, lote);
    }
    
    global void finish(Database.BatchableContext BC){
        BatchApexDupsTransacciones batch = new BatchApexDupsTransacciones (lote);
        //ID batchId =Database.executeBatch(batch, 1000);
        ID batchId =Database.executeBatch(batch, 500);
        Batch_Lote__c batchLote = new Batch_Lote__c();
        batchLote.ID_Batch__c = batchId;
        batchLote.Lote__c = lote.Id;
        insert batchLote;
    }
    
}