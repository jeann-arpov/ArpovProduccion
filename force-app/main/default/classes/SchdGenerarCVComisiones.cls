global with sharing class SchdGenerarCVComisiones implements Schedulable{

    public static String CRON_EXP = '0 0 1 ? * MON-FRI';

    public static void start() {
        System.schedule('Generar CV Comisiones', CRON_EXP, new SchdGenerarCVComisiones());
    }

    global void execute(SchedulableContext SC) {
        generarCVs();
    }
    
    public void generarCVs() {
        
        BatchApexGenerarCVComisiones batch = new BatchApexGenerarCVComisiones(null);
        ID batchId = Database.executeBatch(batch, BatchApexGenerarCVComisiones.BATCH_SIZE);
    }
}