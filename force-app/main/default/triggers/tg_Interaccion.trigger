trigger tg_Interaccion on Interaccion__c (before insert,before update,before delete,after insert,after update,after delete,after undelete) {
    new InteraccionTriggerHandler().run();
}