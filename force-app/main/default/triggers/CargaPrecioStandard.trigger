trigger CargaPrecioStandard on Product2 (after insert) {

    //Coleccionamos los ids de los productos
    Set<Id> idsProductos = new Set<Id>();

    //Recorremos los productos y coleccionamos los ids
    for(Product2 producto : Trigger.new){

    	idsProductos.add(producto.Id);

    }

    //Ejecutamos el Batch
    BatchApexCargaPrecioStandard b = new BatchApexCargaPrecioStandard(idsProductos);
    Database.executeBatch(b);

}