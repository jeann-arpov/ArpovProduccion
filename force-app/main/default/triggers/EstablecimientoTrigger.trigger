trigger EstablecimientoTrigger on Establecimiento__c (before insert, before update) {
    EstablecimientoTriggerHandler.run();
}