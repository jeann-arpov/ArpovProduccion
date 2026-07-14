global class SchdEliminarBatchsLotes implements Schedulable{

    public static String CRON_EXP = '0 0 1 ? * MON-FRI';
    
    public static void start() {
        System.schedule('Elimina Batchs Lote', CRON_EXP, new SchdEliminarBatchsLotes());
    }
    
    global void execute(SchedulableContext SC) {
        eliminarBatchsLotes();
    }
    
    public void eliminarBatchsLotes() {
        Date semana = Date.today().addDays(-7);
        for(List<Batch_Lote__c> batchLotes : [SELECT ID FROM Batch_Lote__c WHERE CreatedDate < :semana]){
            delete batchLotes;
        }
        
    }
}