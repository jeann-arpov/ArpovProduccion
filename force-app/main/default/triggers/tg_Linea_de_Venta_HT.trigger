trigger tg_Linea_de_Venta_HT on Linea_de_Venta_HT__c (before insert, before update) {
    UtilsCompraVentaHT.rechazarCantidadDecimal(
        (List<SObject>) Trigger.new,
        Trigger.old == null ? null : (List<SObject>) Trigger.old,
        'Cantidad__c'
    );
}
