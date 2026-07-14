public with sharing class BatchApexRevertirVentasCreadas implements Database.Batchable<sObject>, Database.Stateful{
    
    public List<String> errors = new List<String>();
    private Id loteId;

    public BatchApexRevertirVentasCreadas(Id loteId){
        this.loteId = loteId;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT HT_Id__c, Origen__c FROM Venta__c WHERE Lote__c = :loteId');
    }

    public void execute(Database.BatchableContext BC, List<Venta__c> scope) {      
        List<Ventas_Informadas__c> ventasInformadasToUpdate = new List<Ventas_Informadas__c>();

        Integer i = 0;

        List<Database.DeleteResult> results = Database.delete(scope,false);

        errors.addAll(BatchErrorHelper.getErrors(results));

        for(Database.DeleteResult dr : results){

            Venta__c venta = scope[i];

            if(dr.isSuccess()){
                ventasInformadasToUpdate.add(
                    new Ventas_Informadas__c(
                        Estado__c = 'Preprocesado',
                        Id = venta.Origen__c,
                        Venta__c = null,
                        Resultado__c = 'OK'
                    )
                );
            }

            i++;
        }

        errors.addAll(BatchErrorHelper.getErrors(Database.update(ventasInformadasToUpdate,false)));
    }

    public void finish(Database.BatchableContext BC) {
        BatchErrorHelper.sendEmail(BC.getJobId(), errors, 'Arpov: Errores en BatchApexRevertirVentasCreadas');
        delete new Lote__c(Id=this.loteId);
    } 

}