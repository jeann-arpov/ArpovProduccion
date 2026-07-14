/**
 * Plan_de_Siembra__c (after insert, after update).
 * Al pasar a Adherido, marca PPH_Adherida__c en Cuenta_Granaria__c del mismo productor y campaña.
 */
trigger tg_Plan_de_Siembra on Plan_de_Siembra__c (after insert, after update) {
    new PlanDeSiembraTriggerHandler().run();
}