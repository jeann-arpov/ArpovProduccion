trigger tg_ERPvs_Comprobante_Venta on ERPvs__Comprobante_Venta__c (before insert, after insert, after update, after delete, after undelete) {
    if(Trigger.isBefore && Trigger.isInsert) {
       UtilsComprobanteVenta.beforeInsert(Trigger.new);
    }

    if(Trigger.isAfter && Trigger.isUpdate){
        UtilsComprobanteVenta.afterUpdate(Trigger.new, Trigger.oldMap);
    }

    if(Trigger.isAfter){
        UtilsComprobanteVenta.actualizarImporteTotalOportunidades(Trigger.isDelete ? Trigger.old : Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null);
    }
}
