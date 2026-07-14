public without sharing class EnsayosRedPropiaVentasCRMAction {

    @InvocableMethod(label = 'Validar las ventas CRM Productores Red Propia por rol' description = 'Se pasa la lista de productores de Red Propia con licencias de red aprobadas y un rol, devuelve la lista de productores con ventas CRM, en el rol definido, con todas las licencias aprobadas.')
    public static List<List<Id>> obtenerListaProductoresLicenciasAprobadas(List<ValidacionVentasCRMRolRequest> request){

        Set<Id> productores = new Set<Id>(request[0].productoresConVentasCRM);
        String lookupRol = request[0].rol == 'Destinatario' ? 'Destinatario__c' : 'Originante__c';

        String qry = 'SELECT Id, ' + lookupRol + ' FROM Venta__c WHERE Semba_Evolucion__c = true AND Estado_Licencia__c != \'Aprobada\'  AND ' + lookupRol + ' = :productores';

        List<Venta__c> ventasCrmSinLicenciaAprobada = Database.query(qry);

        if(ventasCrmSinLicenciaAprobada.isEmpty()){
            return new List<List<Id>>{new List<Id>(productores)};
        }

        Set<Id> productoresRedPOk = new Set<Id>();
        for(Venta__c venta : ventasCrmSinLicenciaAprobada){
            productoresRedPOk.add((Id)venta.get(lookupRol));
        }

        productores.removeAll(productoresRedPOk);

        return new List<List<Id>>{new List<Id>(productores)};
    }

    public class ValidacionVentasCRMRolRequest {
        @InvocableVariable(label = 'Productores con ventas CRM')
        public List<Id> productoresConVentasCRM;

        @InvocableVariable(label = 'Rol')
        public String rol;
    }
}