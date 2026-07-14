trigger tg_InteraccionNueva on Interaccion_Nueva__c (before insert,before update,before delete,after insert,after update,after delete,after undelete) {
	new InteraccionNuevaTriggerHandler().run();
}