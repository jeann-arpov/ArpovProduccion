global class ScheduledBatchApexGeneracionFacturas implements Schedulable {
   
   global void execute(SchedulableContext sc) {
      generar();
   }
   
   public void generar() {
        
      BatchApexGeneracionFacturas b = new BatchApexGeneracionFacturas(); 
      database.executebatch(b);
        
    }
}