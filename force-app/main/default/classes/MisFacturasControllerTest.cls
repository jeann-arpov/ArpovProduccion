@isTest
public class MisFacturasControllerTest {
    public static testmethod void main() {
        Account obtentor = Test_TestUtils.crearObtentor();

        MisFacturasController.vencimientosTest = new List<ERPvs__Vencimientos__c>{new ERPvs__Vencimientos__c()};
        MisFacturasController.tipoCambioTest = new ERPvs__Tipo_de_cambio__c(Erpvs__Vendedor__c = 1);
        MisFacturasController.attachmentsTest = new List<Attachment>{new Attachment(Body = Blob.valueOf('test'))};
        MisFacturasController.oppsTest = new List<Opportunity>{new Opportunity(Id = '0068K000006KW5rQAG', Tipo_de_Comprobante__c = 'FC', N_de_Comprobante__c = 'A-0004-00000017')};
        
        List<MisFacturasController.Vencimiento> vencimientos = MisFacturasController.getVencimientos('Productor');

        System.assertEquals(2, vencimientos.size());
    }
}