global class SchdPriorizacion implements Schedulable{

    public static String CRON_EXP = '0 0 1 ? * MON-FRI';
    
    public static void start() {
        System.schedule('Priorizacion', CRON_EXP, new SchdPriorizacion());
    }
    
    global void execute(SchedulableContext SC) {
        priorizar();
    }
    
    public void priorizar() {
        
        BatchApexPriorizacionDeleteTemporal batch = new BatchApexPriorizacionDeleteTemporal(true);
        Database.executeBatch(batch, 2000);
            
    }
}