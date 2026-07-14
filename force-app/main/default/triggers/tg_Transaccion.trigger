trigger tg_Transaccion on Transaccion__c (after insert, after update, before insert, before update, before delete) {
    TransaccionTriggerHandler.run();
}