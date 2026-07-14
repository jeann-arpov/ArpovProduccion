trigger tg_Venta on Venta__c (after insert, before insert, before delete, before update) {
    
    if(Trigger.isAfter){
        
        if(Trigger.isInsert){
        
            // UtilsCasos.crearCasosFromVentas(Trigger.new);
            UtilsVentas.generarVentasTipoCA(Trigger.new);
            UtilsVentas.generarVentasTipoTRC(Trigger.new);
                
        }


        
        
    }
    
    if(Trigger.isBefore){
        
        if(Trigger.isInsert){
    
            UtilsVentas.agregaOrigen(Trigger.new);

            UtilsVentas.setTipoDeVenta(Trigger.new);
            
        }

        if(Trigger.isUpdate){

            UtilsVentas.setTipoDeVenta(Trigger.new);

        }

        if(Trigger.isDelete){

            UtilsVentas.eliminarVentasCA(Trigger.old);

        }
    
    }
}