/**
* @description Recalcula Opportunity.Importe_Total_Comprobantes_Venta_ARS__c para todas las oportunidades
* con Comprobantes Venta asociados. Pensado para la carga inicial del campo o para resincronizarlo.
* Ejecución: Database.executeBatch(new BatchApexImporteTotalCVOpp(), 200);
*/
//Test_ImporteTotalComprobantesVentaOpp
public without sharing class BatchApexImporteTotalCVOpp implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Opportunity
            WHERE Id IN (SELECT Oportunidad__c FROM ERPvs__Comprobante_Venta__c WHERE Oportunidad__c != null)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        UtilsComprobanteVenta.actualizarImporteTotalComprobantesVenta(new Map<Id, Opportunity>(scope).keySet());
    }

    public void finish(Database.BatchableContext bc) {
    }
}
