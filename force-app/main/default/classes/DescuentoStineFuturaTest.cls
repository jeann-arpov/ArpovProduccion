@isTest
private class DescuentoStineFuturaTest {

    @isTest
    static void porcentajeAplicaSoloConLasTresCondiciones() {
        System.assertEquals(5.00, DescuentoStineFutura.porcentaje('STINE', 'Futura', '24', 'M.S. TECHNOLOGIES ARGENTINA S.R.L.', 'Contado'));
        System.assertEquals(null, DescuentoStineFutura.porcentaje('STINE', 'Futura', '24', 'M.S. TECHNOLOGIES ARGENTINA S.R.L.', 'Financiado'));
        System.assertEquals(null, DescuentoStineFutura.porcentaje('STINE', 'Disponible', '24', 'M.S. TECHNOLOGIES ARGENTINA S.R.L.', 'Contado'));
        System.assertEquals(null, DescuentoStineFutura.porcentaje('CORTEVA', 'Futura', '03', 'M.S. TECHNOLOGIES ARGENTINA S.R.L.', 'Contado'));
        System.assertEquals(null, DescuentoStineFutura.porcentaje('STINE', 'Futura', '24', 'STINE SEED ARGENTINA S.R.L.', 'Contado'));
        System.assertEquals(null, DescuentoStineFutura.porcentaje(null, 'Futura', null, 'M.S. TECHNOLOGIES ARGENTINA S.R.L.', 'Contado'));
        System.assertEquals(5.00, DescuentoStineFutura.porcentaje(null, 'Futura', '24', 'M.S. TECHNOLOGIES ARGENTINA S.R.L.', 'Contado'));
    }

    @isTest
    static void porcentajeDesdeOportunidadYLinea() {
        Opportunity oppStineMs = (Opportunity) JSON.deserialize(
            '{"Capsula__c":"STINE","Obtentor__r":{"Name":"M.S. TECHNOLOGIES ARGENTINA S.R.L.","Nombre_Obtentor__c":"M.S. TECHNOLOGIES ARGENTINA S.R.L."}}',
            Opportunity.class
        );
        OpportunityLineItem lineaFutura = (OpportunityLineItem) JSON.deserialize(
            '{"Tipo_de_Compra__c":"Futura","Linea_de_Compra_HT__r":{"Tipo_de_Pago__c":"Contado"}}',
            OpportunityLineItem.class
        );
        OpportunityLineItem lineaFinanciada = (OpportunityLineItem) JSON.deserialize(
            '{"Tipo_de_Compra__c":"Futura","Linea_de_Compra_HT__r":{"Tipo_de_Pago__c":"Financiado"}}',
            OpportunityLineItem.class
        );
        System.assertEquals(5.00, DescuentoStineFutura.porcentaje(oppStineMs, lineaFutura));
        System.assertEquals(null, DescuentoStineFutura.porcentaje(oppStineMs, lineaFinanciada));
        System.assertEquals(null, DescuentoStineFutura.porcentaje(new Opportunity(Capsula__c = 'STINE'), lineaFutura));
    }

    @isTest
    static void aplicaDescuentoEnLineaDeCompra() {
        Test_TestUtils.disableFlows();
        Account obtentor = Test_TestUtils.crearObtentor();
        obtentor.Name = 'M.S. TECHNOLOGIES ARGENTINA S.R.L.';
        obtentor.Nombre_Obtentor__c = 'M.S. TECHNOLOGIES ARGENTINA S.R.L.';
        obtentor.Id_Obtentor__c = '24';
        update obtentor;

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Soja', 75);
        Variedad__c variedad = new Variedad__c(
            Name = 'STINE 46EA23',
            Obtentor_Comercializa__c = obtentor.Id,
            Sembra_Evolucion__c = true,
            Biotecnologia__c = 'RR1',
            Cultivo__c = cultivo.Id
        );
        insert variedad;

        Product2 prod = Test_TestUtils.crearProducto(
            true, 'STINE 46EA23-Futura', 'USD', 'STINE 46EA23', cultivo, 'Regalía Extendida', 28, obtentor, variedad.Id, true
        );
        prod.Tipo_de_Compra__c = 'Futura';
        update prod;

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 28,
            IsActive = true
        );
        insert entry;

        Compra_HT__c compra = new Compra_HT__c(
            Lista_de_Precios__c = Test.getStandardPricebookId(),
            Cuenta_Productor__c = obtentor.Id,
            Obtentor__c = obtentor.Id,
            Estado__c = 'Creada',
            Capsula__c = 'STINE'
        );
        insert compra;

        Linea_de_Compra_HT__c linea = new Linea_de_Compra_HT__c(
            Name = 'Linea Stine Futura',
            Compra_HT__c = compra.Id,
            Producto__c = prod.Id,
            Id_Producto_de_Lista_de_Precio__c = entry.Id,
            Cantidad__c = 2,
            Precio_de_Lista__c = 100,
            Tipo_de_Compra__c = 'Futura',
            Tipo_de_Pago__c = 'Contado',
            Capsula__c = 'STINE',
            Estado__c = 'Creada'
        );
        DescuentoStineFutura.aplicarEnLineasCompra(new List<Linea_de_Compra_HT__c>{ linea });
        System.assertEquals(5.00, linea.Descuento__c);

        linea.Tipo_de_Pago__c = 'Financiado';
        DescuentoStineFutura.aplicarEnLineasCompra(new List<Linea_de_Compra_HT__c>{ linea });
        System.assertEquals(0, linea.Descuento__c);
    }
}
