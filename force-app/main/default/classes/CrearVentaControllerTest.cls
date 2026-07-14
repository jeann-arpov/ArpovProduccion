@isTest
public class CrearVentaControllerTest {
    public static testmethod void main() {
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
        CrearVentaController.saveItem(venta.id, info, obtentor.id, cultivo.Id);
        CrearVentaController.anular(venta.id);
        CrearVentaController.finalizarVenta(venta.id, true, true);
        //CrearVentaController.getProducts(cultivo.Id, obtentor.Id);
        CrearVentaController.searchProductores('', new List<String>());

        Test.startTest();
        Venta_HT__c venta1 = CrearVentaController.createVenta(obtentor.id, obtentor, cultivo.Id);
        CrearVentaController.saveItem(venta1.id, info, obtentor.id, cultivo.Id);

        Venta_HT__c venta2 = CrearVentaController.createVenta(obtentor.id, obtentor, cultivo.Id);
        CrearVentaController.saveItem(venta2.id, info, obtentor.id, cultivo.Id);

        CrearVentaController.finalizarVenta(venta1.id, true, true);
        System.assertEquals(
            true,
            CrearVentaController.finalizarVenta(venta2.id, true, true).get('duplicate'),
            'deberia dar duplicate error'
        );
        CrearVentaController.deleteItem(venta1.Id, null);
        Test.stopTest();
    }

    @isTest
    static void saveObservationsSuccess() {
        Account obtentor = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.id, obtentor, cultivo.Id);
        String observaciones = 'Esta es una observación de prueba';

        Test.startTest();
        Boolean result = CrearVentaController.saveObvservations(venta.Id, observaciones);
        Test.stopTest();

        System.assertEquals(true, result);
        Venta_HT__c ventaActualizada = [
            SELECT Observaciones__c
            FROM Venta_HT__c
            WHERE Id = :venta.Id
            LIMIT 1
        ];
        System.assertEquals(observaciones, ventaActualizada.Observaciones__c);
    }
    
    @isTest
    static void saveObservationsWithBlank() {
        Account obtentor = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.id, obtentor, cultivo.Id);

        Test.startTest();
        Boolean result = CrearVentaController.saveObvservations(venta.Id, '');
        Test.stopTest();
        
        System.assertEquals(false, result);
    }
    
    @isTest
    static void saveObservationsNull() {
        Account obtentor = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.id, obtentor, cultivo.Id);

        Test.startTest();
        Boolean result = CrearVentaController.saveObvservations(venta.Id, null);
        Test.stopTest();
        
        System.assertEquals(false, result);
    }
    
    @isTest
    static void testSaveObservationsWithNullRecordId() {
        Test.startTest();
        Boolean result = CrearVentaController.saveObvservations(null, 'Observación test');
        Test.stopTest();
        
        System.assertEquals(false, result);
    }
    
    @isTest
    static void saveObservationsInvalidRecordId() {
        String observaciones = 'Observación test';
        Id invalidId = '001000000000000AAA'; 
        
        Test.startTest();
        try {
            CrearVentaController.saveObvservations(invalidId, observaciones);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void saveObservationsUpdate() {
        Account obtentor = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.id, obtentor, cultivo.Id);
        
        CrearVentaController.saveObvservations(venta.Id, 'Observación inicial');
        String nuevaObservacion = 'Observación actualizada';
        
        Test.startTest();
        Boolean result = CrearVentaController.saveObvservations(venta.Id, nuevaObservacion);
        Test.stopTest();
        
        System.assertEquals(true, result);
        
        Venta_HT__c ventaActualizada = [
            SELECT Observaciones__c
            FROM Venta_HT__c
            WHERE Id = :venta.Id
            LIMIT 1
        ];
        System.assertEquals(nuevaObservacion, ventaActualizada.Observaciones__c);
    }
    
    @IsTest
    static void testGetObservacionesSuccess() {
        Account obtentor = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.id, obtentor, cultivo.Id);
        venta.Observaciones__c = 'Observación de prueba';
        update venta;

        Test.startTest();
        String resultado = CrearVentaController.getObservaciones(venta.Id);
        Test.stopTest();

        System.assertEquals('Observación de prueba', resultado);
    }

    @IsTest
    static void testGetObservacionesWithInvalidId() {
        Id idFalso = '001000000000000AAA';

        Test.startTest();
        try {
            CrearVentaController.getObservaciones(idFalso);
            System.assert(false, 'Se esperaba una excepción');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains(''));
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testUpdateOpportunitySuccess() {
        Account cuenta = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(cuenta.id, cuenta, cultivo.Id);

        Opportunity opp = new Opportunity(
            Name      = 'OportunidadTest',
            AccountId = cuenta.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today()
        );
        insert opp;

        Test.startTest();
        CrearVentaController.updateOpportunity(venta.Id, Date.today(), 'C-0001-34567654');
        Test.stopTest();
    }

    @IsTest
    static void testUpdateOpportunityBloqueaVentaPagada() {
        Account cuenta = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(cuenta.id, cuenta, cultivo.Id);
        venta.Estado__c = 'Pagada';
        update venta;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            CrearVentaController.updateOpportunity(venta.Id, Date.today(), 'C-0001-34567654');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Se esperaba una excepción para venta Pagada');
        Test.stopTest();
    }

    // ------- COBERTURA ADICIONAL ---------

    @isTest
    static void testCanFinishTrue() {
        Account obtentor = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.Id, obtentor, cultivo.Id);

        Map<String, Object> semillero = new Map<String, Object>{
            'ParentId'        => null,
            'Id'              => obtentor.Id,
            'Id_Obtentor__c'  => '123'
        };
        List<Id> variedades = new List<Id>();

        Test.startTest();
        Map<String, Object> result = CrearVentaController.canFinish(semillero, obtentor.Id, true, variedades);
        Test.stopTest();

        System.assert(result.containsKey('origenLegal'));
    }

    @isTest
    static void testGetSemilleroData() {
        Account obtentor = Test_TestUtils.crearObtentor();
        obtentor.ParentId = null;
        update obtentor;

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.Id, obtentor, cultivo.Id);

        Test.startTest();
        Map<String, Object> data = CrearVentaController.getSemilleroData(obtentor.Id_Obtentor__c, venta.Cuenta_Productor__c);
        Test.stopTest();

        System.assertNotEquals(null, data);
    }

    // En test mode no se lanza la excepción de anular(), se verifica el comportamiento en test
    @isTest
    static void testAnularInTestMode() {
        Account obtentor = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.Id, obtentor, cultivo.Id);

        venta.Estado__c = 'Facturada';
        update venta;

        Test.startTest();
        CrearVentaController.anular(venta.Id);
        Test.stopTest();

        Venta_HT__c result = [
            SELECT Estado__c
            FROM Venta_HT__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('Cancelada', result.Estado__c, 'Debe marcar la venta como Cancelada en modo test');
    }

    @isTest
    static void testFinalizarVentaConLicencia() {
        Account obtentor = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Venta_HT__c venta = CrearVentaController.createVenta(obtentor.Id, obtentor, cultivo.Id);

        venta.Estado__c = 'Creada';
        update venta;

        Test.startTest();
        CrearVentaController.finalizarVenta(venta.Id, false, true);
        Test.stopTest();

        Venta_HT__c updated = [
            SELECT Estado__c
            FROM Venta_HT__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('Pendiente de Facturación', updated.Estado__c);
    }
}