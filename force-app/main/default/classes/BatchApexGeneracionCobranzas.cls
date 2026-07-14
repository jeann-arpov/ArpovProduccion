/**
* @author Facundo Luna
* @date 02/08/2016
* @description Clase Batcheable que se encarga de generar cobranzas
*/
global class BatchApexGeneracionCobranzas implements Database.Batchable<sObject>, Database.Stateful {
    
    /**
    * @description Variable estatica indica el tamaño del lote
    */  
    public static Integer BATCH_SIZE = 200;

    public Set<Id> idsComprobantesPago = new Set<Id>();

    global BatchApexGeneracionCobranzas() {
        
    }

    global BatchApexGeneracionCobranzas(Set<Id> ids) {
        idsComprobantesPago = ids;
    }    
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        
        String query = 'SELECT Id, Name FROM Comprobante_de_Pago__c WHERE Name != null';
        
        if(idsComprobantesPago != null && !idsComprobantesPago.isEmpty()){

            query += ' AND Id IN :idsComprobantesPago';

        }

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Comprobante_de_Pago__c> scope) {
        
        Set<Id> ids = new Set<Id>();
        
        for(Comprobante_de_Pago__c cp : scope){
        
            ids.add(cp.Id);
          
        }
        
        //Procesamos las Transacciones DUPS (si hubiera)
        if(ids.size() > 0){
            
            UtilsMovimientoFondo.generateMovimientosDeFondeFromCP(ids);
        }
        
        
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }
    
}