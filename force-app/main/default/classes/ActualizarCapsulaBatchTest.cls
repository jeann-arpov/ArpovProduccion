@isTest(SeeAllData=false)
private class ActualizarCapsulaBatchTest {

    // Mapa de equivalencias para tests (igual que en el batch)
    private static Map<String, String> testIdMap = new Map<String, String>{
        '03' => '99', // GRUPO DON MARIO
        '13' => '91', // CORTEVA
        '04' => '88', // SYNGENTA
        '23' => '89', // SYNGENTA
        '24' => '92', // STINE
        '26' => '93', // A.C.A.
        '19' => '94', // BIOCERES
        '05' => '95', // BUCK
        '12' => '84', // LG
        '15' => '96', // LDC
        '16' => '97', // LDC
        '06' => '98', // KLEIN
        '51' => '83', // QUILMES
        '77' => '82'  // BASF
    };

    // Helper para crear un obtentor con Id_Obtentor configurable
    private static Account crearObtentor(String nombre, String idObtentor, Localidad__c localidad) {
        // Si estamos en test, usar el valor ficticio
        String obtentorId = Test.isRunningTest() && testIdMap.containsKey(idObtentor)
            ? testIdMap.get(idObtentor)
            : idObtentor;

        Account obtentor = new Account(
            Name = nombre,
            RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor'),
            Clave_Unica__c = 'TEST_' + obtentorId,
            N_CUIT__c = '20128018639',
            Condicion_Impositiva__c = 'No Aplica',
            Localidad_Envio__c = localidad.Id,
            Type = 'Obtentor',
            Id_Obtentor__c = obtentorId,
            Nombre_Obtentor__c = nombre
        );
        insert obtentor;
        return obtentor;
    }

    // Helper para crear una venta completa con producto, variedad y campaña
    private static Venta__c crearVenta(String variedadName, String idObtentor, String capsulaEsperada) {
        Localidad__c localidad = new Localidad__c(Zona_Bolsa_Cereales__c = 'Test');
        insert localidad;

        Account obtentor = crearObtentor('Obtentor ' + capsulaEsperada, idObtentor, localidad);

        Variedad__c variedad = new Variedad__c(
            Name = variedadName,
            Sembra_Evolucion__c = false,
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert variedad;

        ERPvs.TestUtils.insertDatosGenerales();
        ERPvs__Datos_Generales__c dg = [SELECT Id FROM ERPvs__Datos_Generales__c LIMIT 1];

        ERPvs__Moneda__c monERP = new ERPvs__Moneda__c(
            Name = '1',
            ERPvs__Denominacion__c = 'moneda',
            ERPvs__Pertenece_A__c = dg.Id,
            ERPvs__Moneda_Nacional__c = false,
            ERPvs__Moneda_Traducida__c = true
        );
        insert monERP;

        Moneda__c moneda = Test_TestUtils.crearMoneda('USD','USD',true,false);
        moneda.Moneda_ERP__c = monERP.Id;
        insert moneda;

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo ' + capsulaEsperada,75);

        Product2 prod = Test_TestUtils.crearProducto(
            true, variedadName, moneda.Codigo_Univoco__c, variedadName,
            cultivo, 'Semilla Fiscalizada', 2, obtentor, variedad.id, true
        );

        Campana_Agricola__c campana = Test_TestUtils.crearCampanaAgricola(
            '2025', cultivo, Date.today(), Date.today(), 'campaña ' + capsulaEsperada, true
        );

        Venta__c venta = new Venta__c(
            Fecha__c = Date.today(),
            Estado__c = 'Aprobada',
            Cultivo__c = cultivo.Id,
            Producto__c = prod.Id,
            Cantidad__c = 10,
            Campana_Agricola__c = campana.Id,
            Canal__c = 'Directo'
        );
        insert venta;

        return venta;
    }

    // Método genérico para validar cápsula
    private static void validarCapsula(String variedad, String idObtentor, String esperado) {
        Test_TestUtils.disableFlows();
        Venta__c venta = crearVenta(variedad, idObtentor, esperado);

        Test.startTest();
        Database.executeBatch(new ActualizarCapsulaBatch(), 1);
        Test.stopTest();

        System.assertEquals(esperado,
            [SELECT Capsula__c FROM Venta__c WHERE Id = :venta.Id].Capsula__c,
            'Debe asignar la cápsula ' + esperado);
    }

    // Tests por cada condición
    @isTest static void testCapsulaGrupoDonMario() { validarCapsula('03-XYZ','03','GRUPO DON MARIO'); }
    @isTest static void testCapsulaCorteva()       { validarCapsula('90-ABC','13','CORTEVA'); }
    @isTest static void testCapsulaSyngenta04()    { validarCapsula('04-AAA','04','SYNGENTA'); }
    @isTest static void testCapsulaSyngenta23()    { validarCapsula('23-AAA','23','SYNGENTA'); }
    @isTest static void testCapsulaStine()         { validarCapsula('24-AAA','24','STINE'); }
    @isTest static void testCapsulaACA()           { validarCapsula('26-AAA','26','A.C.A.'); }
    @isTest static void testCapsulaBioceres()      { validarCapsula('19-AAA','19','BIOCERES'); }
    @isTest static void testCapsulaBuck()          { validarCapsula('05-AAA','05','BUCK'); }
    @isTest static void testCapsulaLG()            { validarCapsula('12-AAA','12','LG'); }
    @isTest static void testCapsulaLDC15()         { validarCapsula('15-AAA','15','LDC'); }
    @isTest static void testCapsulaLDC16()         { validarCapsula('16-AAA','16','LDC'); }
    @isTest static void testCapsulaKlein()         { validarCapsula('06-AAA','06','KLEIN'); }
    @isTest static void testCapsulaQuilmes()       { validarCapsula('51-AAA','51','QUILMES'); }
    @isTest static void testCapsulaBasf()          { validarCapsula('77-AAA','77','BASF'); }
 
    // Test no sobrescribir cápsula
    @isTest
    static void testNoUpdateWhenCapsulaAlreadySet() {
        Test_TestUtils.disableFlows();
        Venta__c venta = crearVenta('04-AAA', '04', 'SYNGENTA');
        venta.Capsula__c = 'SYNGENTA';
        update venta;

        Test.startTest();
        Database.executeBatch(new ActualizarCapsulaBatch(), 1);
        Test.stopTest();

        System.assertEquals('SYNGENTA',
            [SELECT Capsula__c FROM Venta__c WHERE Id = :venta.Id].Capsula__c,
            'No debe sobrescribir cápsula existente');
    }
}