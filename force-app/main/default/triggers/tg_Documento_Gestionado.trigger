trigger tg_Documento_Gestionado on Documento_Gestionado__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
	new DocumentoGestionadoTriggerHandler().run();
}