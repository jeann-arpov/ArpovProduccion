@isTest
public class CrearCompraControllerTest {

    @testSetup
    static void setup() {
        Test_TestUtils.disableFlows();
        Erpvs.TestUtils.insertDatosGenerales();

        List<ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

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

        Test_TestUtils.crearTipodeCambio(moneda, 2, Date.today());
    }

    public static testmethod void main() {
        Test_TestUtils.disableFlows();
        Account obtentor = Test_TestUtils.crearObtentor();

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id, Nombre_Comercial__c = 'TEST');
        insert var;

        Moneda__c moneda = [SELECT Codigo_Univoco__c FROM Moneda__c WHERE Codigo_Univoco__c = 'USD' LIMIT 1];

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        Product2 prod = Test_TestUtils.crearProducto(true,'ProductoTest 1',moneda.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, false);
        prod.Producto_Vigente__c = true;
        insert prod;

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id,
            UnitPrice = 10000, IsActive = true);
        insert entry;

        CrearCompraController.searchVariedades('TEST', new List<String>(), new List<String>{var.Id});

        Compra_HT__c compra = CrearCompraController.createCompra(obtentor, cultivo.Id);
        
        Opportunity opp = new Opportunity(Name='Opp Test Main', StageName='Prospecting', CloseDate=Date.today(), AccountId=obtentor.Id);
        insert opp;
        compra.Oportunidad__c = opp.Id;
        update compra;
        
        opp.Compra_HT__c = compra.Id;
        update opp;

        String info = JSON.serialize(new Map<String, String>{'Id_Producto_de_Lista_de_Precio__c' => entry.id, 'Cantidad__c' => '1', 'Precio_de_Lista__c' => '10'});
        
        // El test se inicia aquí, limpiando los límites SOQL para probar el flujo principal
        Test.startTest();

        CrearCompraController.saveItem(compra.id, info, cultivo.Id);
        CrearCompraController.saveItem(compra.id, info, cultivo.Id);
        CrearCompraController.getData(compra.id, true);

        CrearCompraController.anular(compra.id);
        CrearCompraController.finalizarCompra(compra.id, true, true);
        CrearCompraController.getProducts(cultivo.Id);
        
        Test.stopTest();
    }
    
    // FIX: Se extrae la prueba de duplicidad a su propio método para no asfixiar el límite de SOQL
    @IsTest
    static void testDuplicateCompra() {
        Test_TestUtils.disableFlows();
        Account obtentor = Test_TestUtils.crearObtentor();
        Variedad__c var = new Variedad__c(Name = 'test_dup', Obtentor_Comercializa__c = obtentor.id, Nombre_Comercial__c = 'TEST DUP');
        insert var;
        
        Moneda__c moneda = [SELECT Codigo_Univoco__c FROM Moneda__c WHERE Codigo_Univoco__c = 'USD' LIMIT 1];
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test Dup', 75);

        Product2 prod = Test_TestUtils.crearProducto(true,'ProductoTest Dup',moneda.Codigo_Univoco__c, 'Variedad Test Dup', cultivo,  'Regalía Extendida', 2, obtentor, var.id, false);
        prod.Producto_Vigente__c = true;
        insert prod;

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id,
            UnitPrice = 10000, IsActive = true);
        insert entry;

        String info = JSON.serialize(new Map<String, String>{'Id_Producto_de_Lista_de_Precio__c' => entry.id, 'Cantidad__c' => '1', 'Precio_de_Lista__c' => '10'});

        Test.startTest();

        Compra_HT__c compra1 = CrearCompraController.createCompra(obtentor, cultivo.Id);
        Opportunity opp1 = new Opportunity(Name='Opp1', StageName='Prospecting', CloseDate=Date.today(), AccountId=obtentor.Id);
        insert opp1;
        compra1.Oportunidad__c = opp1.Id;
        update compra1;

        CrearCompraController.saveItem(compra1.id, info, cultivo.Id);

        Compra_HT__c compra2 = CrearCompraController.createCompra(obtentor, cultivo.Id);
        Opportunity opp2 = new Opportunity(Name='Opp2', StageName='Prospecting', CloseDate=Date.today(), AccountId=obtentor.Id);
        insert opp2;
        compra2.Oportunidad__c = opp2.Id;
        update compra2;

        CrearCompraController.saveItem(compra2.id, info, cultivo.Id);

        CrearCompraController.finalizarCompra(compra1.id, true, true);

        System.assertEquals(true, CrearCompraController.finalizarCompra(compra2.id, true,true).get('duplicate'), 'deberia dar duplicate error');

        Test.stopTest();
    }

    private class TestContext {
        Account obtentor;
        Cultivo__c cultivo;
        Product2 producto;
        PricebookEntry entry;
        Compra_HT__c compra;
        Opportunity opp;
    }

    private static TestContext setupFullContext() {
        Test_TestUtils.disableFlows();
        TestContext ctx = new TestContext();

        ctx.obtentor = Test_TestUtils.crearObtentor();
        
        Account productorDummy = new Account(Name='Productor Test', N_CUIT__c='33693450239');
        insert productorDummy;
        CrearCompraController.acc = productorDummy;

        ctx.cultivo = Test_TestUtils.crearCultivo('Cultivo Test ctx', 75);

        Variedad__c var = new Variedad__c(
            Name = 'test_var_ctx',
            Obtentor_Comercializa__c = ctx.obtentor.id,
            Biotecnologia__c = 'Enlist E3',
            Sembra_Evolucion__c = true
        );
        insert var;

        ctx.producto = new Product2(
            IsActive = true,
            Name = 'Producto Test ctx',
            Producto_Vigente__c = true,
            Variedad__c = var.Name,
            Variedad2__c = var.Id,
            Obtentor_Comercializa__c = ctx.obtentor.Id,
            Cultivo__c = ctx.cultivo.Id,
            Family = 'Regalía Extendida',
            Tipo_de_Compra__c = 'Disponible'
        );
        insert ctx.producto;

        ctx.entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = ctx.producto.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert ctx.entry;

        ctx.opp = new Opportunity(
            Name = 'Opp Test ctx',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            AccountId = productorDummy.Id
        );
        insert ctx.opp;

        ctx.compra = CrearCompraController.createCompra(ctx.obtentor, ctx.cultivo.Id);
        ctx.compra.Oportunidad__c = ctx.opp.Id;
        update ctx.compra;

        ctx.opp.Compra_HT__c = ctx.compra.Id;
        update ctx.opp;

        return ctx;
    }

    @IsTest
    static void testFinalizarCompra_OverloadCompleto() {
        TestContext ctx = setupFullContext();
        String info = JSON.serialize(new Map<String, Object>{
            'Id_Producto_de_Lista_de_Precio__c' => ctx.entry.id,
            'Cantidad__c' => 1,
            'Precio_de_Lista__c' => 10
        });
        CrearCompraController.saveItem(ctx.compra.Id, info, ctx.cultivo.Id);

        Test.startTest();
        Map<String, Object> resultado = CrearCompraController.finalizarCompra(
            ctx.compra.Id,
            false,
            true, 
            true, 
            true, 
            'STINE',
            'Cosecha',
            'USD',
            '0%'
        );
        Test.stopTest();

        Compra_HT__c compraActualizada = [SELECT Revisar_Compra__c, Entidad_Bancaria__c, Moneda__c FROM Compra_HT__c WHERE Id = :ctx.compra.Id];
        System.assertEquals(true, compraActualizada.Revisar_Compra__c);
        System.assertEquals('STINE', compraActualizada.Entidad_Bancaria__c);
        System.assertEquals('USD', compraActualizada.Moneda__c);
        
        Opportunity oppActualizada = [SELECT Blanqueo__c FROM Opportunity WHERE Id = :ctx.opp.Id];
        System.assertEquals(true, oppActualizada.Blanqueo__c);
    }

    @IsTest
    static void testUpdateTipoPago_Financiado() {
        TestContext ctx = setupFullContext();
        String info = JSON.serialize(new Map<String, Object>{
            'Id_Producto_de_Lista_de_Precio__c' => ctx.entry.id,
            'Cantidad__c' => 1,
            'Precio_de_Lista__c' => 10
        });
        CrearCompraController.saveItem(ctx.compra.Id, info, ctx.cultivo.Id);

        Test.startTest();
        Map<String, Object> resultado = CrearCompraController.updateTipoPago(
            ctx.compra.Id, 
            'Financiado', 
            'STINE', 
            'Cosecha', 
            'USD', 
            '0%'
        );
        Test.stopTest();

        Compra_HT__c compraModificada = [SELECT Entidad_Bancaria__c, Plazo_maximo__c FROM Compra_HT__c WHERE Id = :ctx.compra.Id];
        System.assertEquals('STINE', compraModificada.Entidad_Bancaria__c);

        Linea_de_Compra_HT__c lineaActualizada = [SELECT Tipo_de_Pago__c FROM Linea_de_Compra_HT__c WHERE Compra_HT__c = :ctx.compra.Id LIMIT 1];
        System.assertEquals('Financiado', lineaActualizada.Tipo_de_Pago__c);
    }

    @IsTest
    static void testUpdateTipoPago_Invalidos() {
        TestContext ctx = setupFullContext();

        Test.startTest();
        
        try {
            CrearCompraController.updateTipoPago(null, 'Contado');
            System.assert(false, 'Debería haber fallado al pasar ID nulo');
        } catch(AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }

        try {
            CrearCompraController.updateTipoPago(ctx.compra.Id, '');
            System.assert(false, 'Debería haber fallado al pasar Tipo vacío');
        } catch(AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }

        try {
            CrearCompraController.updateTipoPago(ctx.compra.Id, 'Cheque');
            System.assert(false, 'Debería haber fallado al pasar Tipo inválido');
        } catch(AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }

        Test.stopTest();
    }

    @IsTest
    static void testGetUserAccountData() {
        Test.startTest();
        Map<String, Object> userData = CrearCompraController.getUserAccountData();
        Test.stopTest();
        
        System.assertNotEquals(null, userData);
    }
}