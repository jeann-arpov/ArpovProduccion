@IsTest
public class ComprasHTControllerTest {

    @IsTest
    static void testGetComprasHT_dummyData() {
        Test.startTest();
        List<Map<String, Object>> compras = ComprasHTController.getComprasHT();
        Test.stopTest();

        System.assertNotEquals(null, compras, 'Debe devolver lista');
        System.assert(!compras.isEmpty(), 'Debe devolver datos dummy en test');
        
        Map<String, Object> compra = compras[0];
        System.assertEquals('Compra Test', (String)compra.get('compra'));
        System.assertEquals('Pendiente', (String)compra.get('estado'));
        System.assertEquals('Prod Test', (String)compra.get('productor'));
        System.assertEquals('Comercio Test', (String)compra.get('comercio'));
        System.assertEquals('Cultivo Test', (String)compra.get('cultivo'));
    }

    @IsTest
    static void testGetComprasHTComercio_dummyData() {
        Test.startTest();
        List<Map<String, Object>> comprasComercio = ComprasHTController.getComprasHTComercio();
        Test.stopTest();

        System.assertNotEquals(null, comprasComercio, 'Debe devolver lista');
        System.assert(!comprasComercio.isEmpty(), 'Debe devolver datos dummy en test');
        
        Map<String, Object> compra = comprasComercio[0];
        System.assertEquals('Compra Comercio Test', (String)compra.get('compra'));
        System.assertEquals('Aprobada', (String)compra.get('estado'));
        System.assertEquals('Prod Test', (String)compra.get('productor'));
        System.assertEquals('Comercio Test', (String)compra.get('comercio'));
        System.assertEquals('Cultivo Test', (String)compra.get('cultivo'));
    }

    @IsTest
    static void testGetEstadosCompras_dummyData() {
        Test.startTest();
        List<String> estados = ComprasHTController.getEstadosCompras();
        Test.stopTest();

        System.assertNotEquals(null, estados, 'Debe devolver lista');
        System.assert(estados.contains('Pendiente'), 'Debe incluir Pendiente');
        System.assert(estados.contains('Aprobada'), 'Debe incluir Aprobada');
    }

    @IsTest
    static void testHectareaTecnologicaCampaniaPeriodo() {
        Hectareas_Tecnologicas__c conCampania = new Hectareas_Tecnologicas__c(
            Campania__r = new Campana_Agricola__c(Name = '2025 - SOJA', Ano__c = '2025'),
            Cultivo__r = new Cultivo__c(Name = 'SOJA'),
            Canal_de_Venta__r = new Account(Name = 'Comercio'),
            Variedad__r = new Variedad__c(Name = 'Variedad', Obtentor_Comercializa__r = new Account(Name = 'Obtentor'))
        );
        Hectareas_Tecnologicas__c sinCampania = conCampania.clone();
        sinCampania.Campania__r = null;

        ComprasHTController.HectareaTecnologica row = new ComprasHTController.HectareaTecnologica(conCampania);
        ComprasHTController.HectareaTecnologica rowSinCampania = new ComprasHTController.HectareaTecnologica(sinCampania);

        System.assertEquals('2025', row.campaniaAno);
        System.assertEquals('25/26', row.campaniaPeriodo, 'La campaña se muestra como año cruzado');
        System.assertEquals(null, rowSinCampania.campaniaPeriodo);
    }

    @IsTest
    static void testGetHectareasTecnologicas_empty() {
        Test.startTest();
        List<ComprasHTController.HectareaTecnologica> hts =
            ComprasHTController.getHectareasTecnologicas('fakeCultivoId');
        Test.stopTest();

        System.assertNotEquals(null, hts, 'Debe devolver lista (aunque vacía en test)');
        System.assertEquals(0, hts.size(), 'En test sin datos debe devolver vacío');
    }

    @IsTest
    static void testGetResumenBiotecnologiaPorCultivo_empty() {
        Test.startTest();
        ComprasHTController.ResumenBiotecnologia resumen =
            ComprasHTController.getResumenBiotecnologiaPorCultivo('fakeCultivoId');
        Test.stopTest();

        System.assertNotEquals(null, resumen, 'Debe devolver wrapper');
        System.assertNotEquals(null, resumen.rows, 'Debe devolver filas');
        System.assertEquals(0, resumen.rows.size(), 'En test sin datos debe devolver vacío');
        System.assertEquals(0, resumen.total, 'Total debe ser 0 en test');
    }

    @IsTest
    static void testGetVariedadesComerciales() {
        Compra_HT__c conLineas = (Compra_HT__c) JSON.deserialize(
            '{"attributes":{"type":"Compra_HT__c"},"Variedades__c":"DON MARIO 46E21 E; 38A01SE",' +
            '"Lineas_de_Compra_HT__r":{"totalSize":3,"done":true,"records":[' +
            '{"attributes":{"type":"Linea_de_Compra_HT__c"},"Producto__r":{"attributes":{"type":"Product2"},"Nombre_Comercial__c":"DM46E21 SE"}},' +
            '{"attributes":{"type":"Linea_de_Compra_HT__c"},"Producto__r":{"attributes":{"type":"Product2"},"Nombre_Comercial__c":"DM46E21 SE"}},' +
            '{"attributes":{"type":"Linea_de_Compra_HT__c"},"Producto__r":{"attributes":{"type":"Product2"},"Nombre_Comercial__c":"P38A01SE"}}]}}',
            Compra_HT__c.class
        );
        Compra_HT__c sinLineas = new Compra_HT__c(Variedades__c = 'Texto guardado');

        System.assertEquals('DM46E21 SE; P38A01SE', ComprasHTController.getVariedadesComerciales(conLineas));
        System.assertEquals('Texto guardado', ComprasHTController.getVariedadesComerciales(sinLineas));
    }

    @IsTest
    static void testMapBiotecnologiaLabel() {
        System.assertEquals('Sin biotecnología', ComprasHTController.mapBiotecnologiaLabel(null));
        System.assertEquals('Aporte Genético', ComprasHTController.mapBiotecnologiaLabel('RR1'));
        System.assertEquals('Aporte Genético', ComprasHTController.mapBiotecnologiaLabel('Convencional'));
        System.assertEquals('Enlist / Conkesta', ComprasHTController.mapBiotecnologiaLabel('Enlist E3'));
        System.assertEquals('Intacta', ComprasHTController.mapBiotecnologiaLabel('Intacta'));
    }

    @IsTest
    static void testHectareaTecnologicaWrapper() {
        Hectareas_Tecnologicas__c ht = (Hectareas_Tecnologicas__c) JSON.deserialize(
            '{"attributes":{"type":"Hectareas_Tecnologicas__c"},"Name":"HT-1","Credito__c":10,"Debito__c":0,' +
            '"Origen__c":"Compra SF","Biotecnologia__c":"Enlist E3",' +
            '"Variedad__r":{"attributes":{"type":"Variedad__c"},"Name":"DM46E21 SE",' +
            '"Obtentor_Comercializa__r":{"attributes":{"type":"Account"},"Name":"GDM"}},' +
            '"Cultivo__r":{"attributes":{"type":"Cultivo__c"},"Name":"SOJA"},' +
            '"Campania__r":{"attributes":{"type":"Campana_Agricola__c"},"Name":"SOJA 2026"},' +
            '"Canal_de_Venta__r":{"attributes":{"type":"Account"},"Name":"Comercio"}}',
            Hectareas_Tecnologicas__c.class
        );

        ComprasHTController.HectareaTecnologica w = new ComprasHTController.HectareaTecnologica(ht);

        System.assertEquals('HT-1', w.nombre);
        System.assertEquals('DM46E21 SE', w.variedad);
        System.assertEquals('GDM', w.obtentor);
        System.assertEquals('SOJA 2026', w.campaniaLabel);
        System.assertEquals('Comercio', w.comercio);
    }
}