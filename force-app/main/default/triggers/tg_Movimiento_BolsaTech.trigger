trigger tg_Movimiento_BolsaTech on Movimiento_BolsaTech__c (after insert) {
    new MovimientoBolsaTechTriggerHandler().run();
}
