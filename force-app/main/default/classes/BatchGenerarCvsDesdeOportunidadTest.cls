@isTest
public class BatchGenerarCvsDesdeOportunidadTest {
    public static testmethod void main() {
        Test_TestUtils.disableFlows();
        Account obtentor = Test_TestUtils.crearObtentor();
        obtentor.Factura_por_Cuenta_y_Orden_SE__c = true;
        update obtentor;

        Erpvs.TestUtils.insertDatosGenerales();

        List <ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

        ERPvs__Moneda__c mon = new ERPvs__Moneda__c();
        mon.Name = '1';
        mon.ERPvs__Denominacion__c = 'moneda';
        mon.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        mon.ERPvs__Moneda_Nacional__c = false;
        mon.ERPvs__Moneda_Traducida__c = true;
        insert mon;

        Moneda__c moneda = Test_TestUtils.crearMoneda('USD','USD',true, false);
        moneda.Moneda_ERP__c = mon.id;
        insert moneda;

        Test_TestUtils.crearTipodeCambio(moneda,2,Date.today());

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id, Sembra_Evolucion__c = true, Biotecnologia__c = 'Enlist E3');
        insert var;

        Product2 prod = Test_TestUtils.crearProducto(true,'ProductoTest 1','123', 'Variedad Test 1', new Cultivo__c(),  'Regalía Extendida', 2, obtentor, var.id, true);
        
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id,
            UnitPrice = 10000, IsActive = true);

        insert entry;

        Opportunity opp = new Opportunity();
        opp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Sembra_Evolucion').getRecordTypeId();
        opp.Name = 'test';
        opp.StageName = 'Pendiente de Facturación';
        opp.CloseDate = System.today().addDays(3);
        opp.Pricebook2Id = Test.getStandardPricebookId();
        opp.Tipo_de_Comprobante__c = 'FC';

        insert opp;

        OpportunityLineItem item = new OpportunityLineItem();
        item.Estado__c = 'Facturable';
        item.Product2Id = prod.id;
        item.opportunityId = opp.id;
        item.Quantity = 3;
        item.UnitPrice = 100;
        
        insert item;

        Parametros_ERP_y_CRM__c param = new Parametros_ERP_y_CRM__c();
        insert param;

        Test.startTest();
        new SchdBatchGenerarCvsDesdeOportunidad().execute(null);
        SchdBatchGenerarCvsDesdeOportunidad.start(1, 1, 1);
        Test.stopTest();
    }
}