/**
 * Ventas_Informadas__c (before/after insert y update).
 * Before: normaliza ingreso, cultivo/campaña, variedad, producto, FC origen NC.
 * After: si entra/actualiza una FC, reenlaza NCs huérfanas ("NC sin Origen").
 */
trigger tg_Ventas_Informadas on Ventas_Informadas__c (
    before insert,
    before update,
    after insert,
    after update
) {
    new VentasInformadasTriggerHandler().run();
    // Solo en before insert: marca duplicados sobre Trigger.new antes de persistir.
    if (Trigger.isBefore && Trigger.isInsert) {
        VentasInformadasDuplicateUtil.marcarDuplicados(
            (List<Ventas_Informadas__c>) Trigger.new
        );
    }
}