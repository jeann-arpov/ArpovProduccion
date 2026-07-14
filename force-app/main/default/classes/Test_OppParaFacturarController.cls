@isTest
public with sharing class Test_OppParaFacturarController {

    @TestSetup
    static void setup(){
        Test_TestUtils.disableFlows();

        Profile p = [SELECT Id FROM Profile WHERE Name='Administrador' LIMIT 1]; 
        User u = new User(
            Alias = 'testVsc', Email='testVsc@testarPov.com', 
            EmailEncodingKey='UTF-8', LastName='VCS Admin', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='testVsc@testarPov.com');
        insert u;
        
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

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id, Sembra_Evolucion__c = true, Biotecnologia__c = 'Convencional');
        insert var;

        Product2 prod = Test_TestUtils.crearProducto(true,'ProductoTest 1','123', 'Variedad Test 1', new Cultivo__c(),  'Regalía Extendida', 2, obtentor, false);
        prod.Variedad2__c = var.id;
        insert prod;
        
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id,
            UnitPrice = 10000, IsActive = true);

        insert entry;
        System.debug(LoggingLevel.DEBUG, 'account id ===> ' + obtentor.Id);

        Compra_HT__c compra = CrearCompraController.createCompra(obtentor, cultivo.Id);
        compra.Resultado_Validacion_Analista__c = 'Positiva';
        update compra;

        Opportunity opp = new Opportunity();
        opp.AccountId = obtentor.Id;
        opp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Sembra_Evolucion').getRecordTypeId();
        opp.Name = 'test';
        opp.StageName = 'Pendiente de Facturación';
        opp.CloseDate = System.today().addDays(3);
        opp.Pricebook2Id = Test.getStandardPricebookId();
        opp.Tipo_de_Comprobante__c = 'FC';
        opp.compra_ht__c = compra.id;

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
    }

    @isTest
    static void test(){
        OppParaFacturarController controller = new OppParaFacturarController();

        List<OpportunityLineItem> results = controller.lineasOportunidades;

        System.assertEquals(1, results.size());

        List<SelectOption> obtentores = controller.obtentores;

        System.assertNotEquals(0, obtentores.size());

        List<SelectOption> razonesSociales = controller.razonesSociales;

        System.assertNotEquals(0, razonesSociales.size());

        List<OppParaFacturarController.LineaOportunidad> opplis = controller.tRecords;

        controller.selectedObtentor = obtentores[0].getValue();

        controller.selectedRazon = razonesSociales[0].getValue();

        controller.applyFilter();

        results = controller.lineasOportunidades;

        System.assertEquals(1, results.size());

        opplis[0].getHasError();
        opplis[0].getError();
        opplis[0].getObtentor();
        opplis[0].getObtentorName();
        opplis[0].getCliente();
        opplis[0].getClienteName();
        opplis[0].getProducto();
        opplis[0].getProductoName();
        opplis[0].getSubtotal();
        opplis[0].getVariedad();
        opplis[0].getVariedadName();

        opplis[0].isSelected = true;

        controller.facturar();

        controller.doFirstPage();
        controller.doLastPage();
        controller.doNext();
        controller.doPrevious();
        
        controller.getHasNext();
        controller.getHasPrevious();

        controller.getShowBatchJobsStatus();
        controller.cancel();


    }
}