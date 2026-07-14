public class GenerarDiferenciasController {
    @AuraEnabled
    public static List<ERPvs__Comprobante_Venta__c> generarDiferencias(List<Id> movimientos) {
        UtilsMovimientoFondo.RecordData data = UtilsMovimientoFondo.generarDiferencias(movimientos);
        
        List<ERPvs__Comprobante_Venta__c> cvs = data.cvs;
        cvs.addAll(data.cvsSinImpuestos);

        return cvs;
    }

    @AuraEnabled
    public static void facturar(Id cvId) {
        Erpvs.FacturacionElectronicaController.generarFECV(cvId);
    }

    @AuraEnabled
    public static void agregarDocumentosAfectados(List<Id> cvIds) {
        BatchApexAgregarDocumentosAfectados batch = new BatchApexAgregarDocumentosAfectados();
        batch.execute(null, [SELECT Id, ERPvs__Total__c, ERPvs__Comprobante_Relacionado__c, ERPvs__Signo__c from ERPvs__Comprobante_Venta__c where id in: cvIds]);
    }

    public String idsString;

    // Constructor
    public GenerarDiferenciasController(ApexPages.StandardSetController cntlr){
        idsString = String.join(new List<Id>(new Map<Id, Sobject>(cntlr.getSelected()).keySet()), ',');
    } 

    public PageReference redirectToLC(){
        return new PageReference('/lightning/cmp/c__auraGenerarDiferencias?c__ids=' + idsString);
    }
}