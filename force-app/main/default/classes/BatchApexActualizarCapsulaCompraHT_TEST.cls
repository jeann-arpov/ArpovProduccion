@isTest
public class BatchApexActualizarCapsulaCompraHT_TEST {
    @TestSetup
    static void makeData(){
        Test_TestUtils.disableFlows(); 
         Account acc = new Account(
            Name = 'Test', 
            Id_Obtentor__c = '03', 
            Type = 'Obtentor', 
            Nombre_Obtentor__c = 'test',
            RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor')
        );
        insert acc;
        Licencia__c lic = new Licencia__c(Cuenta_Obtentor__c = acc.Id, Estado__c = 'Aprobada');
        insert lic;
        Compra_HT__c compra = new Compra_HT__c(Lista_de_Precios__c = Test.getStandardPricebookId(), Cuenta_Productor__c = acc.id, Estado__c = 'Creada');
        insert compra;

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = acc.id, Sembra_Evolucion__C = true, Biotecnologia__c = 'RR1');
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
        Product2 prod = Test_TestUtils.crearProducto(true,'ProductoTest 1',moneda.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, acc, var.id, true);

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id,
            UnitPrice = 10000, IsActive = true);

        insert entry;
        Linea_de_Compra_HT__c linea = new Linea_de_Compra_HT__c(
            Cantidad__c = 1,
            Precio_de_Lista__c = 10, 
            Compra_HT__c = compra.id, 
            Estado__c = 'Creada', 
            Licencia__c = lic.Id,
            Tipo_de_cambio__c = 14,
            Id_Producto_de_Lista_de_Precio__c = entry.id
        );
        insert linea;
    }

    @isTest
    static void actualizarCapsulaCompraHT_test(){      
        Test.startTest();
        BatchApexActualizarCapsulaCompraHT b = new BatchApexActualizarCapsulaCompraHT();
        Database.executeBatch(b);
        Test.stopTest();

        Compra_HT__c ens = [SELECT Id, Capsula__c FROM Compra_HT__c LIMIT 1];

        Assert.areEqual('GRUPO DON MARIO', ens.Capsula__c, 'Capsulas no coinciden');
    }
}