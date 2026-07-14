/**
 * Marca Tiene_Comision_RE__c en oportunidades vinculadas a aplicaciones con CV Comisiones.
 */
public with sharing class AplicacionComisionREService {

    public static void marcarDesdeAplicaciones(
        List<Aplicacion__c> aplicaciones,
        Map<Id, Aplicacion__c> oldMap
    ) {
        if (aplicaciones == null || aplicaciones.isEmpty()) {
            return;
        }

        Set<Id> facturaIds = new Set<Id>();
        for (Aplicacion__c ap : aplicaciones) {
            if (ap.Factura__c == null || ap.CV_Comisiones__c == null) {
                continue;
            }
            if (oldMap != null) {
                Aplicacion__c oldAp = oldMap.get(ap.Id);
                if (oldAp != null && oldAp.CV_Comisiones__c == ap.CV_Comisiones__c) {
                    continue;
                }
            }
            facturaIds.add(ap.Factura__c);
        }

        marcarFacturas(facturaIds);
    }

    public static void marcarFacturas(Set<Id> facturaIds) {
        if (facturaIds == null || facturaIds.isEmpty()) {
            return;
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : [
            SELECT Id
            FROM Opportunity
            WHERE Id IN :facturaIds
            AND Tiene_Comision_RE__c = false
        ]) {
            oppsToUpdate.add(new Opportunity(
                Id = opp.Id,
                Tiene_Comision_RE__c = true
            ));
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}