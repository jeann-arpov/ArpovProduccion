@RestResource(urlMapping='/RESTExecuteBatchGenerarPDFsDups/*')
global with sharing class RESTExecuteBatchGenerarPDFsDups{

    @HttpPost
    global static String execute(String Id) {
        System.debug(LoggingLevel.INFO, 'RESTExecuteBatchGenerarPDFsDups');
        System.debug(LoggingLevel.INFO, 'Id' + Id);
        
        Lote__c lote = [SELECT ID FROM Lote__c WHERE ID = :id];
        BatchApexDupsPDFs batch = new BatchApexDupsPDFs(lote);
        ID batchId = Database.executeBatch(batch, 50);
        Batch_Lote__c batchLote = new Batch_Lote__c();
        batchLote.ID_Batch__c = batchId;
        batchLote.Lote__c = lote.Id;
        insert batchLote;
        
        return 'Done';
    }

}