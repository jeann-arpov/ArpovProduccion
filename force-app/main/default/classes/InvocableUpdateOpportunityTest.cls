@isTest
private class InvocableUpdateOpportunityTest {

    @testSetup
    static void setupData() {
        Test_TestUtils.disableFlows();
        Account acc = Test_TestUtils.crearObtentor();

        Variedad__c var = new Variedad__c(Name = 'test2', Obtentor_Comercializa__c = acc.id);
        insert var;

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
        
        Product2 prod = Test_TestUtils.crearProducto(
            true,
            'ProductoTest 1',
            moneda.Codigo_Univoco__c,
            'Variedad Test 1',
            cultivo,
            'Regalía Extendida',
            2,
            acc,
            var.id,
            false
        );
        prod.Producto_Vigente__c = true;
        insert prod;

        // Crear una oportunidad de prueba
        Opportunity opp = new Opportunity(
            Name = 'Oportunidad Test',
            StageName = 'Pendiente de Facturación',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        // Crear un OpportunityLineItem de prueba
        Pricebook2 pb = new Pricebook2(Name = 'Test PB', IsActive = true);
        insert pb;
        
        
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = prod.Id,
            UnitPrice    = 10000,
            IsActive     = true
        );
        insert entry;

        Venta_HT__c venta = CrearVentaController.createVenta(acc.id, acc, cultivo.Id);
        String info = JSON.serialize(new Map<String, String>{
            'Id_Producto_de_Lista_de_Precio__c' => entry.id,
            'Cantidad__c'                       => '1',
            'Precio_de_Lista__c'                => '10'
        });
        
        CrearVentaController.saveItem(venta.id, info, acc.id, cultivo.Id);
        CrearVentaController.saveItem(venta.id, info, acc.id, cultivo.Id);

    }

    @isTest
    static void testUpdateOpportunity() {
        // Recuperar la oportunidad creada en testSetup
        Opportunity opp = [SELECT Id, AccountId, CloseDate,StageName FROM Opportunity LIMIT 1];
        system.debug(opp);

        // Crear la request
        InvocableUpdateOpportunity.Request req = new InvocableUpdateOpportunity.Request();
        req.recordId = opp.Id;
        req.fechaEmision = Date.today();
        req.numComprobante = 'A-1234-12345678';

        List<InvocableUpdateOpportunity.Request> requests = new List<InvocableUpdateOpportunity.Request>{req};

        // Ejecutar el método
        Test.startTest();
        List<InvocableUpdateOpportunity.Response> responses = InvocableUpdateOpportunity.updateOpportunity(requests);
        Test.stopTest();

        // Verificar respuesta
        System.assertEquals('Oportunidad actualizada correctamente', responses[0].resultado);

        // Verificar que la oportunidad se actualizó
        Opportunity updatedOpp = [SELECT Id, StageName, N_de_Comprobante__c, Total_Comprobante__c 
                                  FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('A-1234-12345678', updatedOpp.N_de_Comprobante__c);
        System.assertNotEquals(null, updatedOpp.Total_Comprobante__c);

        // Verificar que se insertó un movimiento
        List<Movimientos__c> movs = [SELECT Id, Comprobante__c, Oportunidad__c 
                                     FROM Movimientos__c WHERE Oportunidad__c = :opp.Id];
        System.assertEquals(1, movs.size());
        System.assertEquals('A-1234-12345678', movs[0].Comprobante__c);
    }
}