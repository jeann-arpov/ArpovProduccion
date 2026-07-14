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
    static void testGetHectareasTecnologicas_empty() {
        // En test no se devuelve dummy aquí, así que será lista vacía
        Test.startTest();
        List<ComprasHTController.HectareaTecnologica> hts =
            ComprasHTController.getHectareasTecnologicas('fakeCultivoId');
        Test.stopTest();

        System.assertNotEquals(null, hts, 'Debe devolver lista (aunque vacía en test)');
        System.assertEquals(0, hts.size(), 'En test sin datos debe devolver vacío');
    }
}