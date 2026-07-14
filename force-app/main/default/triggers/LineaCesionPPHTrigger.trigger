trigger LineaCesionPPHTrigger on Linea_Cesion_HT__c (after insert, after delete, after update) {
    if (Trigger.isDelete) CesionPPH.updateVariedadesField(Trigger.old);
    else CesionPPH.updateVariedadesField(Trigger.new);
}