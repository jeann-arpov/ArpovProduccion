trigger tg_Aplicacion on Aplicacion__c (after insert, after update) {
    AplicacionComisionREService.marcarDesdeAplicaciones(
        Trigger.new,
        Trigger.isUpdate ? Trigger.oldMap : null
    );
}