trigger tg_ERPvs_Comprobante_Venta on ERPvs__Comprobante_Venta__c (before insert, after update) {
    if(Trigger.isBefore && Trigger.isInsert) {
       UtilsComprobanteVenta.beforeInsert(Trigger.new);
    }

    if(Trigger.isAfter && Trigger.isUpdate){
        UtilsComprobanteVenta.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}