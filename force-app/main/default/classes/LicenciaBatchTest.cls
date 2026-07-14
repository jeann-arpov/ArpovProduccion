@isTest
private class LicenciaBatchTest {

    @testSetup
    static void setupData() {
       Test_TestUtils.disableFlows();
        Account obtentor = Test_TestUtils.crearObtentor();

        Variedad__c var = new Variedad__c(Name = 'test2', Obtentor_Comercializa__c = obtentor.id);
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
            obtentor,
            var.id,
            false
        );
        prod.Producto_Vigente__c = true;
        insert prod;

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = prod.Id,
            UnitPrice    = 10000,
            IsActive     = true
        );
        insert entry;

        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.id, obtentor, cultivo.Id);
        String info = JSON.serialize(new Map<String, String>{
            'Id_Producto_de_Lista_de_Precio__c' => entry.id,
            'Cantidad__c'                       => '1',
            'Precio_de_Lista__c'                => '10'
        });
        
        CrearVentaController.saveItem(venta.id, info, obtentor.id, cultivo.Id);
        CrearVentaController.finalizarVenta(venta.id, true, true);

    }

    @isTest
    static void testBatchOpportunityLicenceFalse() {
        // Ejecutar el batch
        Test.startTest();
        LicenciaBatch batch = new LicenciaBatch();
        Database.executeBatch(batch, 1); // scope pequeño para forzar ejecución inmediata
        Test.stopTest();

        // Verificar que la oportunidad fue actualizada
        Opportunity oppUpdated = [
            SELECT Id, hasLicence__c
            FROM Opportunity
            LIMIT 1
        ];

        System.assertEquals(false, oppUpdated.hasLicence__c,
            'La oportunidad debería tener hasLicence__c = false después del batch');
    }

    @isTest
    static void testBatchOppLicenceTrue() {
        Test_TestUtils.disableFlows();
        // Crear una licencia vencida para que no entre en la query
        Licencia__c licencia = new Licencia__c(
            Name = 'Licencia',
            Estado__c = 'Aprobada',
            Fecha_de_Vencimiento__c = Date.today().addDays(10)
        );
        insert licencia;


        Linea_de_Compra_HT__c linea = [Select Id from Linea_de_Compra_HT__c limit 1];
        linea.Licencia__c = licencia.Id;
        update linea;

        Test.startTest();
        LicenciaBatch batch = new LicenciaBatch();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        // Verificar que la oportunidad cambio
        Opportunity opp = [
            SELECT Id, hasLicence__c
            FROM Opportunity
            LIMIT 1
        ];
        System.assertEquals(true, opp.hasLicence__c,
            'La oportunidad tiene licencia');
    }
}