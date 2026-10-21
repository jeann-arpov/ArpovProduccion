public with sharing class MovimientoBolsaTechTriggerHandler extends TriggerHandler {
    public override void afterInsert() {
        Set<Id> movimientoIds = new Set<Id>();
        for (Movimiento_BolsaTech__c movimiento : (List<Movimiento_BolsaTech__c>) Trigger.new) {
            if (movimiento.Titular__c == null || String.isBlank(movimiento.Cosecha__c)) {
                continue;
            }
            if (movimiento.Tecnologia__c == null || !movimiento.Tecnologia__c.equalsIgnoreCase(EnvioCorreoMbtInicialService.TECNOLOGIA)) {
                continue;
            }
            movimientoIds.add(movimiento.Id);
        }
        if (movimientoIds.isEmpty()) {
            return;
        }
        System.enqueueJob(new EnvioCorreoMbtInicialQueueable(movimientoIds));
    }
}
