global class ws_EnviarLiquidacionAuditoria{
  
  /*
      Metodo que se Ejecutara desde un Boton en el Layout de Una Oportunidad (Factura)
      con el fin de dar de alta una Nota de Credito "On Demand"
  */    
  WebService static List<String> enviar(Id idFactura) {
    
    //Variable que contendra el resultado de la operacion
    List<String> resultado = new List<String>{'true',''};
    
    if(idFactura != null){
        
        try{
        
            //Obtener los datos de Factura
            Opportunity factura = [SELECT Id, Enviar_Liquidacion__c FROM Opportunity WHERE Id = :idFactura LIMIT 1];
            
            //Seteamos el atributo Enviar_Liquidacion__c a true para que se ejecute el WF Factura. Envío de Liquidacion
            factura.Enviar_Liquidacion__c = true;
            
            update factura;
        }catch(Exception e){
                
            //Ocurrio un error
            resultado[0] = 'false';
            resultado[1] = e.getMessage();    
        }  
              
    }else{
        
        //No se paso el Id de la Factura
        resultado[0] = 'false';
        resultado[1] = 'No ha sido posible obtener el id de la factura';
    
    }    
    
    return resultado;
   
  }

}