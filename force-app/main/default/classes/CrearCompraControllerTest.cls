@isTest()
public class CrearCompraControllerTest {
    public static testmethod void main() {
        Test_TestUtils.disableFlows();
        Account obtentor = Test_TestUtils.crearObtentor();

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id, Nombre_Comercial__c = 'TEST');
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
        
        Product2 prod = Test_TestUtils.crearProducto(true,'ProductoTest 1',moneda.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, false);
        prod.Producto_Vigente__c = true;
        insert prod;

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id,
            UnitPrice = 10000, IsActive = true);

        insert entry;

        CrearCompraController.searchVariedades('TEST', new List<String>(), new List<String>{var.Id});

        Compra_HT__c compra = CrearCompraController.createCompra(obtentor, cultivo.Id);
        String info = JSON.serialize(new Map<String, String>{'Id_Producto_de_Lista_de_Precio__c' => entry.id, 'Cantidad__c' => '1', 'Precio_de_Lista__c' => '10'});
        
        CrearCompraController.saveItem(compra.id, info, cultivo.Id);
        CrearCompraController.saveItem(compra.id, info, cultivo.Id);
        CrearCompraController.getData(compra.id, true);

        CrearCompraController.anular(compra.id);
        CrearCompraController.finalizarCompra(compra.id, true,true);
        CrearCompraController.getProducts(cultivo.Id);
        /*CrearCompraController.crearCVS(compra.id);
        CrearCompraController.generarFE(compra.id, null);
        CrearCompraController.generarPDF(compra.id, null);*/

        for (Linea_de_Compra_HT__c linea: [select id from Linea_de_Compra_HT__c]) {
            CrearCompraController.deleteItem(compra.id, linea.id);
        }

        System.assertEquals(0, [select id from Compra_HT__c].size());

        Test.startTest();

        Compra_HT__c compra1 = CrearCompraController.createCompra(obtentor, cultivo.Id);
        CrearCompraController.saveItem(compra1.id, info, cultivo.Id);

        Compra_HT__c compra2 = CrearCompraController.createCompra(obtentor, cultivo.Id);
        CrearCompraController.saveItem(compra2.id, info, cultivo.Id);

        CrearCompraController.finalizarCompra(compra1.id, true,true);

        System.assertEquals(true, CrearCompraController.finalizarCompra(compra2.id, true,true).get('duplicate'), 'deberia dar duplicate error');
    }
}