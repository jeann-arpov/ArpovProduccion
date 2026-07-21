@IsTest
private class ValidarLicenciasCuentaPrincipalTest {

    @TestSetup
    static void makeData() {
        Test_TestUtils.disableFlows();

        Account obtentor = Test_TestUtils.crearObtentor();
        Account productor = Test_TestUtils.crearProductor();

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 1000);

        Variedad__c variedad = new Variedad__c(
            Name = 'Variedad Test VLCP',
            Biotecnologia__c = 'Enlist E3',
            Obtentor_Comercializa__c = obtentor.Id,
            Cultivo__c = cultivo.Id,
            Sembra_Evolucion__c = true
        );
        insert variedad;

        Product2 producto = Test_TestUtils.crearProducto(
            true, 'Producto VLCP', 'conversion', 'SOJA', cultivo,
            'Semilla Fiscalizada', 1000, obtentor, variedad.Id, false
        );
        producto.Sembra_Evolucion__c = true;
        insert producto;

        Campana_Agricola__c campania = Test_TestUtils.crearCampanaAgricola(
            '2025', cultivo, Date.today().addDays(-1), Date.today().addDays(10), 'Campania VLCP'
        );

        // Destinatario = productor (path Destinatario)
        Venta__c ventaDest = Test_TestUtils.crearVenta(producto, campania, cultivo, 10, obtentor, productor, 'C');
        ventaDest.Rol_Originante__c = 'Obtentor';
        ventaDest.Rol_Destinatario__c = 'Productor';
        update ventaDest;

        // Segunda venta tipo Venta
        Venta__c ventaTipo = new Venta__c(
            Producto__c = producto.Id,
            Campana_Agricola__c = campania.Id,
            Cultivo__c = cultivo.Id,
            Cantidad__c = 11,
            Originante__c = obtentor.Id,
            Destinatario__c = productor.Id,
            Tipo_de_Venta__c = 'Venta',
            Rol_Originante__c = 'Obtentor',
            Rol_Destinatario__c = 'Productor'
        );
        insert ventaTipo;

        // Originante = productor (path Originante: TDS/DPO)
        Venta__c ventaOrig = new Venta__c(
            Producto__c = producto.Id,
            Campana_Agricola__c = campania.Id,
            Cultivo__c = cultivo.Id,
            Cantidad__c = 12,
            Originante__c = productor.Id,
            Destinatario__c = obtentor.Id,
            Tipo_de_Venta__c = 'TDS',
            Rol_Originante__c = 'Productor',
            Rol_Destinatario__c = 'Obtentor'
        );
        insert ventaOrig;

        insert new Licencia__c(
            Cuenta_Productor__c = productor.Id,
            Cuenta_Obtentor__c = obtentor.Id,
            Tecnologia__c = 'Enlist',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada'
        );
    }

    private static Venta__c ventaEnMemoria(
        String biotecnologia,
        String tipo,
        String rolOrig,
        String rolDest,
        Id originanteId,
        Id destinatarioId,
        Id obtentorId
    ) {
        Map<String, Object> variedadMap = new Map<String, Object>{
            'Biotecnologia__c' => biotecnologia,
            'Obtentor_Comercializa__c' => obtentorId
        };
        Map<String, Object> productoMap = new Map<String, Object>{
            'Variedad2__r' => variedadMap
        };
        Map<String, Object> ventaMap = new Map<String, Object>{
            'Tipo_de_Venta__c' => tipo,
            'Rol_Originante__c' => rolOrig,
            'Rol_Destinatario__c' => rolDest,
            'Originante__c' => originanteId,
            'Destinatario__c' => destinatarioId,
            'Producto__r' => productoMap
        };
        return (Venta__c) JSON.deserialize(JSON.serialize(ventaMap), Venta__c.class);
    }

    @IsTest
    static void testExecuteDestinatario() {
        Account productor = [SELECT Id FROM Account WHERE Type = 'Productor' LIMIT 1];
        ValidarLicenciasCuentaPrincipal.Request request = new ValidarLicenciasCuentaPrincipal.Request();
        request.productores = new List<Id>{ productor.Id };
        request.rol = 'Destinatario';

        Test.startTest();
        List<ValidarLicenciasCuentaPrincipal.Response> responses =
            ValidarLicenciasCuentaPrincipal.execute(new List<ValidarLicenciasCuentaPrincipal.Request>{ request });
        Test.stopTest();

        System.assertNotEquals(null, responses);
        System.assertEquals(1, responses.size());
        System.assertNotEquals(null, responses[0].productoresOk);
    }

    @IsTest
    static void testExecuteOriginante() {
        Account productor = [SELECT Id FROM Account WHERE Type = 'Productor' LIMIT 1];
        ValidarLicenciasCuentaPrincipal.Request request = new ValidarLicenciasCuentaPrincipal.Request();
        request.productores = new List<Id>{ productor.Id };
        request.rol = 'Originante';

        Test.startTest();
        List<ValidarLicenciasCuentaPrincipal.Response> responses =
            ValidarLicenciasCuentaPrincipal.execute(new List<ValidarLicenciasCuentaPrincipal.Request>{ request });
        Test.stopTest();

        System.assertNotEquals(null, responses);
        System.assertEquals(1, responses.size());
        System.assertNotEquals(null, responses[0].productoresOk);
    }

    @IsTest
    static void testGetVentas() {
        Account productor = [SELECT Id FROM Account WHERE Type = 'Productor' LIMIT 1];
        Set<Id> productoresIds = new Set<Id>{ productor.Id };

        Test.startTest();
        List<Venta__c> dest = ValidarLicenciasCuentaPrincipal.getVentas(productoresIds, 'Destinatario');
        List<Venta__c> orig = ValidarLicenciasCuentaPrincipal.getVentas(productoresIds, 'Originante');
        List<Venta__c> empty = ValidarLicenciasCuentaPrincipal.getVentas(new Set<Id>(), 'Destinatario');
        Test.stopTest();

        System.assert(dest.size() > 0, 'Debe haber ventas como Destinatario');
        System.assert(orig.size() > 0, 'Debe haber ventas como Originante');
        System.assertEquals(0, empty.size());
    }

    @IsTest
    static void testFiltrosTipoVenta() {
        List<Venta__c> ventas = [
            SELECT Id, Tipo_de_Venta__c, Rol_Originante__c, Rol_Destinatario__c
            FROM Venta__c
        ];

        Test.startTest();
        System.assertNotEquals(null, ValidarLicenciasCuentaPrincipal.getVentasTipoCoVentas(ventas));
        System.assertNotEquals(null, ValidarLicenciasCuentaPrincipal.getVentasTipoVenta(ventas));
        System.assertNotEquals(null, ValidarLicenciasCuentaPrincipal.getVentasTipoTDSoDPO(ventas));
        System.assertNotEquals(null, ValidarLicenciasCuentaPrincipal.getVentasTipoTDS(ventas));
        Test.stopTest();
    }

    @IsTest
    static void testMapearTecnologiasEnMemoria() {
        Account obtentor = [SELECT Id FROM Account WHERE Type = 'Obtentor' LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Type = 'Productor' LIMIT 1];

        List<Venta__c> enlist = new List<Venta__c>{
            ventaEnMemoria('Enlist E3', 'C', 'Obtentor', 'Productor', obtentor.Id, productor.Id, obtentor.Id),
            ventaEnMemoria('Conkesta E3', 'Venta', 'Obtentor', 'Productor', obtentor.Id, productor.Id, obtentor.Id)
        };
        List<Venta__c> rr = new List<Venta__c>{
            ventaEnMemoria('RR1', 'C', 'Obtentor', 'Productor', obtentor.Id, productor.Id, obtentor.Id),
            ventaEnMemoria('Convencional', 'Venta', 'Obtentor', 'Productor', obtentor.Id, productor.Id, obtentor.Id)
        };
        List<Venta__c> otras = new List<Venta__c>{
            ventaEnMemoria('BGRR', 'C', 'Obtentor', 'Productor', obtentor.Id, productor.Id, obtentor.Id),
            ventaEnMemoria('HB4', 'Venta', 'Obtentor', 'Productor', obtentor.Id, productor.Id, obtentor.Id)
        };

        Test.startTest();
        System.assertEquals(2, ValidarLicenciasCuentaPrincipal.mapearTecnologiaEnlist(enlist).size());
        System.assertEquals(2, ValidarLicenciasCuentaPrincipal.mapearTecnologiaRR(rr).size());
        System.assertEquals(2, ValidarLicenciasCuentaPrincipal.mapearTecnologiaOtra(otras).size());
        Test.stopTest();
    }

    @IsTest
    static void testClavesYLicencias() {
        Account obtentor = [SELECT Id FROM Account WHERE Type = 'Obtentor' LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Type = 'Productor' LIMIT 1];

        List<Venta__c> ventas = new List<Venta__c>{
            ventaEnMemoria('Enlist E3', 'C', 'Obtentor', 'Productor', obtentor.Id, productor.Id, obtentor.Id),
            ventaEnMemoria('Enlist E3', 'TDS', 'Productor', 'Obtentor', productor.Id, obtentor.Id, obtentor.Id)
        };

        Test.startTest();
        Set<String> clavesDest = ValidarLicenciasCuentaPrincipal.getClaveVentasRolDestinatario(ventas);
        Set<String> clavesOrig = ValidarLicenciasCuentaPrincipal.getClaveVentasRolOriginante(ventas);
        List<Licencia__c> licencias = ValidarLicenciasCuentaPrincipal.getLicencias(clavesDest, 'Enlist');
        Set<Id> productoresConLic = ValidarLicenciasCuentaPrincipal.getProductoresConLicencia(licencias);
        Test.stopTest();

        System.assert(clavesDest.size() > 0);
        System.assert(clavesOrig.size() > 0);
        System.assertNotEquals(null, licencias);
        System.assertNotEquals(null, productoresConLic);
    }

    @IsTest
    static void testObtenerProductores() {
        List<Venta__c> ventas = [
            SELECT Id, Rol_Originante__c, Rol_Destinatario__c, Tipo_de_Venta__c,
                   Originante__c, Destinatario__c,
                   Producto__r.Variedad2__r.Biotecnologia__c,
                   Producto__r.Variedad2__r.Obtentor_Comercializa__c
            FROM Venta__c
        ];

        Test.startTest();
        Set<Id> result = ValidarLicenciasCuentaPrincipal.obtenerProductores(ventas);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }
}
