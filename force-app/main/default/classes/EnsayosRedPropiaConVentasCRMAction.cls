public without sharing class EnsayosRedPropiaConVentasCRMAction {
    
    @InvocableMethod(label = 'Validar Red Propia si tienen ventas CRM' description = 'Devuelve las listas de productores con licencias aprobadas sin ventas CRM o con ventas CRM como originante o destinatario')
    public static List<ValidacionRedPropiaResult> obtenerListasProductores(List<List<Id>> productoresRedPropia){

        Set<Id> productoresConVentasOriginante = new Set<Id>();
        // GROUP BY: cada productor cuenta 1 fila hacia el límite de query rows (no todas las ventas)
        for (AggregateResult ar : [
            SELECT COUNT(Id) cnt, Originante__c
            FROM Venta__c
            WHERE Semba_Evolucion__c = true AND Originante__c IN :productoresRedPropia[0]
            GROUP BY Originante__c
        ]) {
            Id originanteId = (Id) ar.get('Originante__c');
            if (originanteId != null) {
                productoresConVentasOriginante.add(originanteId);
            }
        }

        Set<Id> productoresConVentasDestinatario = new Set<Id>();
        for (AggregateResult ar : [
            SELECT COUNT(Id) cnt, Destinatario__c
            FROM Venta__c
            WHERE Semba_Evolucion__c = true AND Destinatario__c IN :productoresRedPropia[0]
            GROUP BY Destinatario__c
        ]) {
            Id destinatarioId = (Id) ar.get('Destinatario__c');
            if (destinatarioId != null) {
                productoresConVentasDestinatario.add(destinatarioId);
            }
        }

        Set<Id> productoresIds = new Set<Id>(productoresRedPropia[0]);
        productoresIds.removeAll(productoresConVentasDestinatario);
        productoresIds.removeAll(productoresConVentasOriginante);

        ValidacionRedPropiaResult result = new ValidacionRedPropiaResult();
        result.productoresConVentasCrmOriginante = new List<Id>(productoresConVentasOriginante);
        result.productoresConVentasCrmDestinatario = new List<Id>(productoresConVentasDestinatario);
        result.productoresSinVentasCrm = new List<Id>(productoresIds);

        return new List<ValidacionRedPropiaResult>{result};
    }

    public class ValidacionRedPropiaResult {
        @InvocableVariable(label = 'Productores sin ventas CRM' )
        public List<Id> productoresSinVentasCrm;
        
        @InvocableVariable(label = 'Productores con ventas CRM como originante')
        public List<Id> productoresConVentasCrmOriginante;

        @InvocableVariable(label = 'Productores con ventas CRM como destinatario')
        public List<Id> productoresConVentasCrmDestinatario;
    }
}
