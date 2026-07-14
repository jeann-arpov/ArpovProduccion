global class SchdEliminarDups implements Schedulable{

    public static String CRON_EXP = '0 0 1 ? * MON-FRI';
    
    public static void start() {
        System.schedule('Elimina DUPS', CRON_EXP, new SchdEliminarDups());
    }
    
    global void execute(SchedulableContext SC) {
        
    }
    
    public void eliminarDups(String loteId) {
        
        Lote__c lote = [SELECT ID FROM Lote__c WHERE ID =:loteId];
        
        BatchApexDupsEliminarLogs batch = new BatchApexDupsEliminarLogs(lote);
        ID batchId = Database.executeBatch(batch, 2000);
        Batch_Lote__c batchLote = new Batch_Lote__c();
        batchLote.ID_Batch__c = batchId;
        batchLote.Lote__c = lote.Id;
        insert batchLote;
    }
}