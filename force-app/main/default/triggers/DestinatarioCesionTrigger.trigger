trigger DestinatarioCesionTrigger on Destinatario_Cesion_HT__c (after delete) {
    CesionPPH.updateVariedadesField(Trigger.old);
}