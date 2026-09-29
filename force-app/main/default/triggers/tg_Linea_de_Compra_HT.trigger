trigger tg_Linea_de_Compra_HT on Linea_de_Compra_HT__c (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        DescuentoStineFutura.aplicarEnLineasCompra(Trigger.new);
    }
}
