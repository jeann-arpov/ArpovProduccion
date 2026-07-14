global class SchdCVsEnviarMails implements Schedulable{

    global void execute(SchedulableContext ctx){
        enviarMails();
    }
  
    private void enviarMails(){
        Date fecha = Date.today().addDays(-1);
        Database.executeBatch(new BatchApexCVsEnviarEmails(fecha), 1);
    }
  
}