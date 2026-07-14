global class ws_CrearNotaDeCredito{
  
  /*
      Metodo que se Ejecutara desde un Boton en el Layout de Una Oportunidad (Factura)
      con el fin de dar de alta una Nota de Credito "On Demand"
  */    
  WebService static String crearNotaDeCredito(Id idFactura) {
    
    //Variable que contendra la Nota de Credito Creada
    Opportunity notaCredito = null;
    
    if(idFactura != null){
        
        //Obtener los datos de Factura
        Opportunity factura = [SELECT Id, N_de_Comprobante__c,Tipo_de_Comprobante__c FROM Opportunity WHERE Id = :idFactura LIMIT 1];
        
        //Comprobamos que tenga N° de Comprobante y que el Tipo de Comprobante sea FC
        if(factura.N_de_Comprobante__c!= '' && factura.N_de_Comprobante__c != null && factura.Tipo_de_Comprobante__c == 'FC'){
            
            //Creamos la nota de Credito    
            notaCredito = CrearNotaDeCreditoDesdeFactura.crearNotaCredito(idFactura);
        
        }
    }    
    
    //Variable que contendra el Id de la Nota de Credito  
    String idNotaCredito = '';
    if(notaCredito != null){
        idNotaCredito = notaCredito.Id;
    }
    
    //Retornar número Id Nota Credito (si fue creada)
    return idNotaCredito;
  }

}