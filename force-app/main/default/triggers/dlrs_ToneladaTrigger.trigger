/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
trigger dlrs_ToneladaTrigger on Tonelada__c
    (before delete, before insert, before update, after delete, after insert, after undelete, after update)
{
    dlrs.RollupService.triggerHandler(Tonelada__c.SObjectType);
    
    // Desasignar cuenta granaria cuando cambia campaña
    if (Trigger.isBefore && Trigger.isUpdate) {
        ToneladaTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    
    // Asignar cuenta granaria y actualizar saldo
    if (Trigger.isAfter && Trigger.isInsert) {
        ToneladaTriggerHandler.afterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        ToneladaTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isDelete) {
        ToneladaTriggerHandler.afterDelete(Trigger.old);
    }
}