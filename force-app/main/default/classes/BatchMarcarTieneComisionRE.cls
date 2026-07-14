/**
 * Backfill: marca Tiene_Comision_RE__c en oportunidades con aplicaciones que ya tienen CV Comisiones.
 * Los registros nuevos quedan cubiertos por tg_Aplicacion.
 */
global with sharing class BatchMarcarTieneComisionRE implements Database.Batchable<sObject> {

    public static final Integer BATCH_SIZE = 200;

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Opportunity
            WHERE Tiene_Comision_RE__c = false
            AND Id IN (
                SELECT Factura__c
                FROM Aplicacion__c
                WHERE CV_Comisiones__c != null
                AND Factura__c != null
            )
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        Set<Id> facturaIds = new Set<Id>();
        for (Opportunity opp : scope) {
            facturaIds.add(opp.Id);
        }
        AplicacionComisionREService.marcarFacturas(facturaIds);
    }

    global void finish(Database.BatchableContext bc) {
    }
}