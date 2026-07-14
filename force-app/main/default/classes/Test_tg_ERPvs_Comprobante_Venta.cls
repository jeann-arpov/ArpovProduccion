@isTest
private class Test_tg_ERPvs_Comprobante_Venta {
    
    /**
    * @author Maximo Martinez
    * @date 07/01/2015
    * @description Metodo que da de Alta los Datos que necesita el Test
    */
    @TestSetup static void setup(){
        Account obtentor = Test_TestUtils.crearObtentor();
        obtentor.Factura_por_Cuenta_y_Orden_SE__c = true;
        obtentor.ERPvs__Activa__c = true;
        update obtentor;

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id, Sembra_Evolucion__C = true);
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
        Product2 prod = Test_TestUtils.crearProducto(true,'ProductoTest 1',moneda.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id,
            UnitPrice = 10000, IsActive = true);

        insert entry;

        Compra_HT__c compra = new Compra_HT__c(Lista_de_Precios__c = Test.getStandardPricebookId(), Cuenta_Productor__c = obtentor.id, Estado__c = 'Creada');
        insert compra;

        compra.Estado__c = 'Pendiente de Facturación';
        update compra;

        Linea_de_Compra_HT__c linea = new Linea_de_Compra_HT__c(Id_Producto_de_Lista_de_Precio__c = entry.id, Cantidad__c = 1, Precio_de_Lista__c = 10, Compra_HT__c = compra.id, Estado__c = 'Creada');
        insert linea;

        linea.Estado__C = 'Facturable';
        update linea;

        insert new Parametros_ERP_y_CRM__c();

        insert new Erpvs__Deshabilitacion_triggers__c(Erpvs__Comprobante_de_Venta__c = true);

        UtilsComprobanteVenta.createComprobantesVentaFromOpps(new Set<Id>{[select id from opportunity limit 1].id}, System.today());
    }

    @isTest static void testSetTieneCAE(){

        
        System.assertEquals(0, [SELECT COUNT() FROM Transaccion__c WHERE Tiene_CAE__c = true]);

        for(List<ERPvs__Comprobante_Venta__c> cvs : [SELECT Id FROM ERPvs__Comprobante_Venta__c]){
            
            for(ERPvs__Comprobante_Venta__c cv : cvs){
            
                cv.ERPvs__CAE__c = 1;
            
            }

            update cvs;

        }

       //System.assertEquals(2, [SELECT COUNT() FROM Transaccion__c WHERE Tiene_CAE__c = true]);

       UtilsComprobanteVenta.cvToMovimiento(new ERPvs__Comprobante_Venta__c(), null);
       Map<Id, ERPvs__Comprobante_Venta__c> records = new Map<Id, ERPvs__Comprobante_Venta__c>([SELECT Id FROM ERPvs__Comprobante_Venta__c]);
       UtilsComprobanteVenta.checkSiembra(records.keySet(), records);
    }


}