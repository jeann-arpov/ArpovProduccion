@IsTest
public class VentasInformadasControllerTest {

    private static Account crearCuentaOriginante() {
        Test_TestUtils.disableFlows();
        Account acc = new Account(Name = 'Originante VI Test');
        insert acc;
        VentasInformadasController.testCuentaId = acc.Id;
        return acc;
    }

    private static Ventas_Informadas__c crearVentaBase() {
        return new Ventas_Informadas__c(
            Categoria_Portal__c = 'Pre Básica',
            CUIT_Originante__c = '20123456789',
            CUIT_Destinatario__c = '20987654321',
            Cantidad_de_Bolsas__c = 10
        );
    }

    @IsTest
    static void testGetVentasSinProcesar_dummyData() {
        Test.startTest();
        List<Map<String, Object>> sinProcesar = VentasInformadasController.getVentasInformadasSinProcesar();
        Test.stopTest();

        System.assertNotEquals(null, sinProcesar, 'Debe devolver lista');
        System.assert(!sinProcesar.isEmpty(), 'Debe devolver datos dummy en test');
        System.assertEquals('En Curso', (String) sinProcesar[0].get('estado'));
        System.assertNotEquals(null, sinProcesar[0].get('campanaAgri'), 'Debe tener campanaAgri');
        System.assertNotEquals(null, sinProcesar[0].get('cuitDest'), 'Debe tener cuitDest');
        System.assertNotEquals(null, sinProcesar[0].get('variedad'), 'Debe tener variedad');
        System.assertNotEquals(null, sinProcesar[0].get('categoria'), 'Debe tener categoria');
        System.assertNotEquals(null, sinProcesar[0].get('bolsas40'), 'Debe tener bolsas40');
        System.assertEquals('Remito', (String) sinProcesar[0].get('tipoCompExterno'));
        System.assertNotEquals(null, sinProcesar[0].get('numero'), 'Debe tener numero');
    }

    @IsTest
    static void testGetVentasProcesadas_dummyData() {
        Test.startTest();
        List<Map<String, Object>> procesadas = VentasInformadasController.getVentasInformadasProcesadas();
        Test.stopTest();

        System.assertNotEquals(null, procesadas, 'Debe devolver lista');
        System.assert(!procesadas.isEmpty(), 'Debe devolver datos dummy en test');
        System.assertEquals('Procesado', (String) procesadas[0].get('estado'));
    }

    @IsTest
    static void testGetVentasSinProcesar_datosReales() {
        Account acc = crearCuentaOriginante();

        Ventas_Informadas__c venta = crearVentaBase();
        venta.Originante__c = acc.Id;
        venta.Estado__c = 'Pendiente';
        venta.N_de_Comprobante__c = '999';
        venta.Tipo_de_Comprobante__c = 'REMITO';
        venta.Cantidad_Bolsas_40__c = null;
        venta.Cantidad_de_Bolsas__c = 800;
        venta.Linea_Facturacion__c = 2;
        insert venta;

        Test.startTest();
        List<Map<String, Object>> sinProcesar = VentasInformadasController.getVentasInformadasSinProcesar();
        Test.stopTest();

        System.assertEquals(1, sinProcesar.size());
        System.assertEquals('Remito', (String) sinProcesar[0].get('tipoCompExterno'));
        System.assertEquals(20, sinProcesar[0].get('bolsas40'));
        System.assertEquals('2', sinProcesar[0].get('lineaComprobante'));
    }

    @IsTest
    static void testGetVentasProcesadas_datosReales() {
        Account acc = crearCuentaOriginante();

        Ventas_Informadas__c venta = crearVentaBase();
        venta.Originante__c = acc.Id;
        venta.Estado__c = 'Procesado';
        venta.Tipo_Comprobante_Externo__c = 'Remito de Devolución';
        venta.Tipo_de_Comprobante__c = 'FC';
        venta.N_de_Comprobante__c = 'PROC-001';
        insert venta;

        Test.startTest();
        List<Map<String, Object>> procesadas = VentasInformadasController.getVentasInformadasProcesadas();
        Test.stopTest();

        System.assertEquals(1, procesadas.size());
        System.assertEquals('Remito de Devolución', (String) procesadas[0].get('tipoCompExterno'));
        System.assertEquals('PROC-001', procesadas[0].get('numero'));
    }

    @IsTest
    static void testGetVentas_tipoComprobanteLegacy() {
        Account acc = crearCuentaOriginante();

        Ventas_Informadas__c venta = crearVentaBase();
        venta.Originante__c = acc.Id;
        venta.Estado__c = 'Pendiente';
        venta.Tipo_de_Comprobante__c = 'Remito de Devolución';
        insert venta;

        List<Map<String, Object>> result = VentasInformadasController.getVentasInformadasSinProcesar();
        System.assertEquals('Remito de Devolución', (String) result[0].get('tipoCompExterno'));
    }

    @IsTest
    static void testGetVentas_tipoComprobanteFallback() {
        Account acc = crearCuentaOriginante();

        Ventas_Informadas__c venta = crearVentaBase();
        venta.Originante__c = acc.Id;
        venta.Estado__c = 'Pendiente';
        venta.Tipo_de_Comprobante__c = 'FC';
        insert venta;

        List<Map<String, Object>> result = VentasInformadasController.getVentasInformadasSinProcesar();
        System.assertEquals('FC', (String) result[0].get('tipoCompExterno'));
    }

    @IsTest
    static void testGetVentaInformadaById_conVariedad() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = crearVentaBase();
        venta.N_de_Comprobante__c = 'COMP-001';
        venta.Variedad__c = 'INASE-123';
        venta.Fecha_de_Facturacion__c = Date.today();
        venta.Linea_Facturacion__c = 1;
        insert venta;

        Test.startTest();
        Map<String, Object> result = VentasInformadasController.getVentaInformadaById(venta.Id);
        Test.stopTest();

        System.assertEquals('COMP-001', (String) result.get('N_de_Comprobante__c'));
        System.assertEquals(null, result.get('VariedadId'));
        System.assertEquals(null, result.get('VariedadName'));
        System.assertNotEquals(null, result.get('Fecha_de_Facturacion__c'));
    }

    @IsTest
    static void testGetVentaInformadaById_sinVariedad() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = crearVentaBase();
        venta.N_de_Comprobante__c = 'COMP-002';
        venta.Cantidad_de_Bolsas__c = 20;
        insert venta;

        Test.startTest();
        Map<String, Object> result = VentasInformadasController.getVentaInformadaById(venta.Id);
        Test.stopTest();

        System.assertEquals('COMP-002', (String) result.get('N_de_Comprobante__c'));
        System.assertEquals(null, result.get('VariedadId'));
        System.assertEquals(null, result.get('VariedadName'));
    }

    @IsTest
    static void testGetVentaInformadaById_enriqueceRolesOriginante() {
        Test_TestUtils.disableFlows();

        Account originante = new Account(
            Name = 'Originante Dup Test',
            N_CUIT__c = '20144462980',
            Type = 'Distribuidor'
        );
        insert originante;

        Ventas_Informadas__c venta = crearVentaBase();
        venta.CUIT_Originante__c = '20144462980';
        venta.N_de_Comprobante__c = 'COMP-DUP';
        venta.Originante__c = null;
        venta.Rol_Originante__c = null;
        insert venta;

        Test.startTest();
        Map<String, Object> result = VentasInformadasController.getVentaInformadaById(venta.Id);
        Test.stopTest();

        System.assertEquals('COMP-DUP', (String) result.get('N_de_Comprobante__c'));
        System.assertEquals(originante.Id, result.get('Originante__c'));
        System.assertEquals('Distribuidor', result.get('Rol_Originante__c'));
    }

    @IsTest
    static void testGetVentaInformadaById_conVariedadInase() {
        Test_TestUtils.disableFlows();
        crearCuentaOriginante();

        Cultivo__c cultivo = new Cultivo__c(Name = 'Cult VI Ctrl', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Camp VI Ctrl',
            Ano__c = '2026',
            Id_Externo__c = 'VI_CTRL_01',
            Z9_Clave_Unica__c = 'VI_CTRL_Z9',
            SKEY_CAMPANIA__c = 8800999,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(Name = 'Var Ctrl', Cultivo__c = cultivo.Id);
        insert variedad;

        Ventas_Informadas__c venta = crearVentaBase();
        venta.Campana_Agricola__c = campana.Id;
        venta.Variedad_INASE__c = variedad.Id;
        venta.N_de_Comprobante__c = 'COMP-INASE';
        venta.Linea_Facturacion__c = 1;
        venta.Fecha_de_Facturacion__c = Date.today();
        insert venta;

        Test.startTest();
        Map<String, Object> result = VentasInformadasController.getVentaInformadaById(venta.Id);
        Test.stopTest();

        System.assertEquals(variedad.Id, result.get('VariedadId'));
        System.assertEquals('Var Ctrl', result.get('VariedadName'));
    }

    @IsTest
    static void testGetVentaInformadaById_conVariedadLookup() {
        Test_TestUtils.disableFlows();
        crearCuentaOriginante();

        Cultivo__c cultivo = new Cultivo__c(Name = 'Cult VI Lookup', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Camp VI Lookup',
            Ano__c = '2026',
            Id_Externo__c = 'VI_CTRL_02',
            Z9_Clave_Unica__c = 'VI_CTRL_Z9_2',
            SKEY_CAMPANIA__c = 8800998,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(
            Name = 'Var Lookup',
            Cultivo__c = cultivo.Id,
            Cultivar_INASE__c = 'INASE-123'
        );
        insert variedad;

        Ventas_Informadas__c venta = crearVentaBase();
        venta.Campana_Agricola__c = campana.Id;
        venta.Variedad__c = 'INASE-123';
        venta.N_de_Comprobante__c = 'COMP-LOOKUP';
        insert venta;

        Test.startTest();
        Map<String, Object> result = VentasInformadasController.getVentaInformadaById(venta.Id);
        Test.stopTest();

        System.assertEquals(variedad.Id, result.get('VariedadId'));
        System.assertEquals('Var Lookup', result.get('VariedadName'));
    }

    @IsTest
    static void testGetVentaInformadaById_error() {
        Boolean errorLanzado = false;

        Test.startTest();
        try {
            VentasInformadasController.getVentaInformadaById(UserInfo.getUserId());
        } catch (AuraHandledException e) {
            errorLanzado = true;
        }
        Test.stopTest();

        System.assertEquals(true, errorLanzado, 'Debe lanzar AuraHandledException');
    }

    @IsTest
    static void testDeleteVentaInformada_ok() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = crearVentaBase();
        venta.N_de_Comprobante__c = 'COMP-003';
        venta.Cantidad_de_Bolsas__c = 5;
        insert venta;

        Test.startTest();
        VentasInformadasController.deleteVentaInformada(venta.Id);
        Test.stopTest();

        Integer cantidad = [SELECT count() FROM Ventas_Informadas__c WHERE Id = :venta.Id];
        System.assertEquals(0, cantidad, 'La venta debe eliminarse');
    }

    @IsTest
    static void testDeleteVentaInformada_error() {
        Boolean errorLanzado = false;

        Test.startTest();
        try {
            VentasInformadasController.deleteVentaInformada(UserInfo.getUserId());
        } catch (AuraHandledException e) {
            errorLanzado = true;
        }
        Test.stopTest();

        System.assertEquals(true, errorLanzado, 'Debe lanzar AuraHandledException');
    }
}