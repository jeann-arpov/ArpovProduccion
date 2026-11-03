trigger tg_Linea_de_Compra_HT on Linea_de_Compra_HT__c (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        UtilsCompraVentaHT.rechazarCantidadDecimal(
            (List<SObject>) Trigger.new,
            Trigger.old == null ? null : (List<SObject>) Trigger.old,
            'Cantidad__c'
        );
        DescuentoStineFutura.aplicarEnLineasCompra(Trigger.new);
    }
}