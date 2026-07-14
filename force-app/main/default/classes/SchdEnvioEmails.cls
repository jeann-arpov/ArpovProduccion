global class SchdEnvioEmails implements Schedulable{

    public static String CRON_EXP = '0 0 1 ? * MON-FRI';
    
    public static void start() {
        System.schedule('Envío Emails', CRON_EXP, new SchdEnvioEmails());
    }
    
    global void execute(SchedulableContext SC) {
        enviarEmails();
    }
    
    public void enviarEmails() {
        
        BatchApexEnvioEmails batch = new BatchApexEnvioEmails();
        Database.executeBatch(batch,10);
        
    }
    
    
}