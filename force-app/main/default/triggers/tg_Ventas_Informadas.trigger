/**
 * Ventas_Informadas__c (before insert, before update).
 * Normaliza ingreso externo (API), rellena cultivo/campaña, variedad, producto, etc.
 */
trigger tg_Ventas_Informadas on Ventas_Informadas__c (before insert, before update) {
    new VentasInformadasTriggerHandler().run();
    if (Trigger.isInsert) {
        VentasInformadasDuplicateUtil.marcarDuplicados(
            (List<Ventas_Informadas__c>) Trigger.new
        );
    }
}