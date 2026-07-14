/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
trigger dlrs_Hectareas_TecnologicasTrigger on Hectareas_Tecnologicas__c
    (before delete, before insert, before update, after delete, after insert, after undelete, after update)
{
    dlrs.RollupService.triggerHandler(Hectareas_Tecnologicas__c.SObjectType);
}