public without sharing class CrearNotaDeCreditoDesdeFactura{
    
    public static Opportunity crearNotaCredito(Id idFactura){
        
        //Variable que contendra la nota de credito a devolver
        Opportunity notaCredito = null;
        
        //Armamos un SET para coleccionar todos los productos intervinientes en el trigger
        Set<Id> productos =new Set<Id>(); 
        
        //Almacenamos los item de oportunidad en una Lista
        List<OpportunityLineItem> opportunityLineItemsToInsert = new List<OpportunityLineItem>();  
        
        //Consulta la Factura obteniendo en una subquery los Item de la misma
        Opportunity factura = [Select Id, Pricebook2Id,StageName,AccountId,Obtentor__c,Name,Transaccion__c, Type,(Select PricebookEntryId, Quantity, UnitPrice, Tipo_de_Cambio__c  From OpportunityLineItems) From Opportunity WHERE Id = :idFactura];
        
        //Clonamos la factura
        notaCredito = factura.clone();
        
        //Cambiamos el Tipo de Comprobante a NC (Nota de Credito)
        notaCredito.Tipo_de_Comprobante__c = 'NC';
        
        //Insertamos la Fecha de Cierre
        notaCredito.CloseDate = Date.today();
        
        //Insertamos la nota de credito
        insert notaCredito;
            
        //Recorremos los Line Item de la Oportunidad
        //asignano el Id
        for(OpportunityLineItem item : factura.OpportunityLineItems){
           
           //Clonamos el Item de la Oportunidad
           OpportunityLineItem opportunityLineItem = item.clone();
           
           //Cambiamos el importe a negativo
           opportunityLineItem.UnitPrice =(-1)*Math.abs(opportunityLineItem.UnitPrice);
           
           //Asignamos el Id de la Nota de credito a la linea de oportunidad
           opportunityLineItem.OpportunityId = notaCredito.Id;
            
           //Almacenamos la nota de credito en la lista de notas de credito a insertar
           opportunityLineItemsToInsert.add(opportunityLineItem); 
        }
        
        insertList(opportunityLineItemsToInsert);
        
        return notaCredito;
    }
    
    public static void insertList(List<OpportunityLineItem> lista){
        
        List<OpportunityLineItem> toInsert = new List<OpportunityLineItem>();
        
        for(OpportunityLineItem o : lista){
            toInsert.add(o);
                
            if(toInsert.size() == 200){
                insert toInsert;
                toInsert.clear();
            }
        }

        if(toInsert.size() > 0){
            insert toInsert;
            toInsert.clear();
        }
        
    }
     
}