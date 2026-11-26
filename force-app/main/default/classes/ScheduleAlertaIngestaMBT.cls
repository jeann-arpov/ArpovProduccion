public with sharing class ScheduleAlertaIngestaMBT implements Schedulable {
  public void execute(SchedulableContext ctx) {
    IngestaMBTAlertaService.verificarIngestaDelDia();
  }
}
