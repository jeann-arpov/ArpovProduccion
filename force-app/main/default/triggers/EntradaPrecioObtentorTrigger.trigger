trigger EntradaPrecioObtentorTrigger on Entrada_Precio_Obtentor__c (before insert, after insert, before update, after update, after delete) {
    EntradaPrecioObtentorHandler.run();
}