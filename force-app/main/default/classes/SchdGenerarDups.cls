global class SchdGenerarDups implements Schedulable{

    public static String CRON_EXP = '0 0 1 ? * MON-FRI';
    
    public static void start() {
        System.schedule('Genera DUPS', CRON_EXP, new SchdGenerarDups());
    }
    
    global void execute(SchedulableContext SC) {
        
    }
    
    public void generarDups(String loteId) {
        
        Lote__c lote = [SELECT Id, Campana__c, Campana__r.Nombre_de_Campana_Anterior__c FROM Lote__c WHERE ID = :loteId];
        System.debug(LoggingLevel.INFO, 'lote : ' + lote ); 
        BatchApexDupsVentas batch = new BatchApexDupsVentas(lote);
        //ID batchId =Database.executeBatch(batch, 1000);
        ID batchId =Database.executeBatch(batch, 500);
        Batch_Lote__c batchLote = new Batch_Lote__c();
        batchLote.ID_Batch__c = batchId;
        batchLote.Lote__c = lote.Id;
        insert batchLote;
    }
}