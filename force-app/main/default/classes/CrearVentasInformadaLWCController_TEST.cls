@isTest
public with sharing class CrearVentasInformadaLWCController_TEST {
    @TestSetup
    static void makeData(){
        Account acc = new Account(
            Name = 'test account',
            N_CUIT__c = '20398301987'
        );    
        insert acc;
    }

     @isTest
    static void getCuitTest(){
        Account acc = [SELECT Id, N_CUIT__c FROM Account LIMIT 1];
        Test.startTest();
        Account response = CrearVentaInformadaLWCController.getCuenta(acc.Id);
        Test.stopTest();

        Assert.areEqual(response.Id, acc.Id, 'cuits no coinciden');
    }

     @IsTest
    static void testGetVariedad() {
        Test_TestUtils.disableFlows();
        Cultivo__c cultivo = new Cultivo__c(
            Name = 'Cultivo Test VI',
            Densidad_de_Siembra__c = 10
        );
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana Test VI',
            Ano__c = '2026',
            Id_Externo__c = 'VI_EXT_001',
            Z9_Clave_Unica__c = 'VI_Z9_001',
            SKEY_CAMPANIA__c = 8800001,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        // Datos de prueba
        List<Variedad__c> variedades = new List<Variedad__c>{
            new Variedad__c(Name = 'Manzana Roja', Cultivo__c = cultivo.Id),
            new Variedad__c(Name = 'Manzana Verde', Cultivo__c = cultivo.Id),
            new Variedad__c(Name = 'Pera Dulce', Cultivo__c = cultivo.Id),
            new Variedad__c(Name = 'Durazno Amarillo', Cultivo__c = cultivo.Id),
            new Variedad__c(Name = 'Manzana Fuji', Cultivo__c = cultivo.Id)
        };
        insert variedades;

        Test.startTest();
        // Llamada al método con searchTerm que coincida con algunos registros
        List<LookupSearchResult> resultados = CrearVentaInformadaLWCController.getVariedad('Manzana', new List<String>(), campana.Id);
        List<LookupSearchResult> todas = CrearVentaInformadaLWCController.getVariedadesParaLookup(campana.Id);
        List<LookupSearchResult> listadoInicial = CrearVentaInformadaLWCController.getVariedad('', new List<String>(), campana.Id);
        List<LookupSearchResult> conSeleccion = CrearVentaInformadaLWCController.getVariedad(
            'Pera',
            new List<String>{ String.valueOf(variedades[0].Id) },
            campana.Id
        );
        Test.stopTest();

        // Validaciones
        System.assertNotEquals(null, resultados, 'La lista de resultados no debe ser null');
        System.assert(resultados.size() > 0, 'Debe haber al menos un resultado');
        System.assertEquals(5, todas.size(), 'Debe listar todas las variedades del cultivo de la campaña.');
        System.assertEquals(5, listadoInicial.size(), 'Sin término de búsqueda debe devolver el listado inicial del cultivo.');
        System.assert(conSeleccion.size() >= 2, 'Debe incluir coincidencias LIKE y la variedad seleccionada.');
        for (LookupSearchResult res : resultados) {
            System.assertEquals('Variedad__c', res.sObjectType, 'El tipo de objeto debe ser Variedad__c');
            System.assertNotEquals(null, res.record, 'El campo record debe estar poblado');
        }
    }

    @isTest
    static void getCuentaOriginanteTest(){
        Set<String> customerUserTypes = new Set<String> {'CSPLiteUser', 'PowerPartner', 'PowerCustomerSuccess',   'CustomerSuccess'};

        Account acc1 = new Account (
            Name = 'newAcc1'
        );  
        insert acc1;
        Contact conCase = new Contact (
            AccountId = acc1.id,
            LastName = 'portalTestUserv1'
        );
        insert conCase;
        //Create user

        Profile prfile = [SELECT Id,name FROM Profile WHERE UserType IN :customerUserTypes LIMIT 1];

        User newUser1 = new User(
            profileId = prfile.id,
            username = 'testUser@testVentasInformadas.com',
            email = 'pb@f.com',
            emailencodingkey = 'UTF-8',
            localesidkey = 'en_US',
            languagelocalekey = 'en_US',
            timezonesidkey = 'America/Los_Angeles',
            alias='nuser',
            lastname='testUserVentas',
            contactId = conCase.id
        );
        system.runAs(newUser1) {
            Test.startTest();
            Account response = CrearVentaInformadaLWCController.getCuentaOriginante();
            Test.stopTest();

            Assert.areEqual(response.Id, acc1.Id, 'cuits no coinciden');
        }
    }

    @isTest
    static void saveVentaTest() {
        Test_TestUtils.disableFlows();
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Destinatario__c = '20398301987',
            CUIT_Originante__c = '20389301977',
            Variedad__c = 'test var',
            // Ticket 1916: Cantidad_de_Bolsas__c representa Kilos Totales (mínimo 20).
            Cantidad_de_Bolsas__c = 40,
            Campana_de_Ventas__c = '2025'
        );

        insert venta;
        venta.Id = null;
        Variedad__c var = new Variedad__c(Cultivar_Inase__c = 'test var');
        insert var;

        Test.startTest();
        String id = CrearVentaInformadaLWCController.saveVentaInformada(venta, var.Id, null);
        Test.stopTest();

        Assert.areNotEqual(null, id, 'Id es null');
    }

    /**
     * Kilos Totales menores a 20 kg se permiten al guardar.
     */
    @isTest
    static void saveVentaKilosMenoresA20PermitidosTest() {
        Test_TestUtils.disableFlows();
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Destinatario__c = '20398301987',
            CUIT_Originante__c = '20389301977',
            Variedad__c = 'test var',
            Cantidad_de_Bolsas__c = 10,
            Campana_de_Ventas__c = '2025'
        );

        Variedad__c var = new Variedad__c(Cultivar_Inase__c = 'test var');
        insert var;

        Test.startTest();
        Id savedId = CrearVentaInformadaLWCController.saveVentaInformada(venta, var.Id, null);
        Test.stopTest();

        Assert.isNotNull(savedId, 'Debe permitir guardar con Kilos Totales < 20.');
    }

    /**
     * Ticket 1874: el valor "Remito" se mapea a "FC" antes de guardar.
     */
    @isTest
    static void saveVentaMapeoTipoComprobanteTest() {
        Test_TestUtils.disableFlows();
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Destinatario__c = '20398301987',
            CUIT_Originante__c = '20389301977',
            Variedad__c = 'test var',
            Cantidad_de_Bolsas__c = 40,
            Campana_de_Ventas__c = '2025',
            Tipo_de_Comprobante__c = 'REMITO'
        );

        Variedad__c var = new Variedad__c(Cultivar_Inase__c = 'test var');
        insert var;

        Test.startTest();
        String id = CrearVentaInformadaLWCController.saveVentaInformada(venta, var.Id, null);
        Test.stopTest();

        Ventas_Informadas__c saved = [
            SELECT Tipo_de_Comprobante__c, Tipo_Comprobante_Externo__c
            FROM Ventas_Informadas__c
            WHERE Id = :id
            LIMIT 1
        ];
        Assert.areEqual('FC', saved.Tipo_de_Comprobante__c, 'Interno: Remito -> FC');
        Assert.areEqual('Remito', saved.Tipo_Comprobante_Externo__c, 'Externo debe conservar Remito');
    }

    /**
     * Búsqueda de Razón Social por CUIT en SF.
     */
    @isTest
    static void saveVentaInformadaCoreOriginanteTest() {
        Test_TestUtils.disableFlows();
        Account acc = [SELECT Id, N_CUIT__c FROM Account LIMIT 1];
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Destinatario__c = acc.N_CUIT__c,
            Variedad__c = 'test var',
            Cantidad_de_Bolsas__c = 40,
            Campana_de_Ventas__c = '2025',
            Tipo_de_Comprobante__c = 'FC'
        );
        Variedad__c var = new Variedad__c(Cultivar_Inase__c = 'test var');
        insert var;

        Test.startTest();
        String id = CrearVentaInformadaLWCController.saveVentaInformada(venta, var.Id, acc.Id);
        Test.stopTest();

        Ventas_Informadas__c saved = [
            SELECT Originante__c, CUIT_Originante__c
            FROM Ventas_Informadas__c
            WHERE Id = :id
            LIMIT 1
        ];
        Assert.areEqual(acc.Id, saved.Originante__c, 'Originante debe ser la cuenta indicada');
        Assert.areEqual(acc.N_CUIT__c, saved.CUIT_Originante__c, 'CUIT originante debe coincidir');
    }

    @isTest
    static void buscarCuentaOriginantePorCuitTest() {
        Account acc = [SELECT N_CUIT__c FROM Account LIMIT 1];
        Test.startTest();
        Account found = CrearVentaInformadaLWCController.buscarCuentaOriginantePorCuit(acc.N_CUIT__c);
        Test.stopTest();
        Assert.isNull(found, 'Cuenta de test sin RT Distribuidor/Obtentor no debe matchear filtro');
    }

    @isTest
    static void getRazonSocialPorCuitTest() {
        Account acc = [SELECT Id, Name, N_CUIT__c FROM Account LIMIT 1];

        Test.startTest();
        String razonSocial = CrearVentaInformadaLWCController.getRazonSocialPorCuit(acc.N_CUIT__c, null);
        Test.stopTest();

        Assert.areEqual(acc.Name, razonSocial, 'Razón Social debe coincidir con el Account.Name');
    }

    @isTest
    static void getCuentaDestinatarioPorCuitTest() {
        Account acc = [SELECT Id, Name, N_CUIT__c, Type FROM Account WHERE N_CUIT__c != NULL LIMIT 1];

        Test.startTest();
        Map<String, String> data = CrearVentaInformadaLWCController.getCuentaDestinatarioPorCuit(acc.N_CUIT__c, null);
        Test.stopTest();

        System.assertEquals(acc.Id, data.get('id'));
        System.assertEquals(acc.Name, data.get('name'));
    }

    /** Defensa server-side: si el CUIT viene con guiones/puntos, se limpia antes de guardar. */
    @isTest
    static void limpiarCuitTest() {
        Assert.areEqual(null, CrearVentaInformadaLWCController.limpiarCuit(null));
        Assert.areEqual('20393429683', CrearVentaInformadaLWCController.limpiarCuit('20-39342968-3'));
        Assert.areEqual('30507119235', CrearVentaInformadaLWCController.limpiarCuit('30.50711923.5'));
        Assert.areEqual('30507119235', CrearVentaInformadaLWCController.limpiarCuit(' 30 50711923 5 '));
    }

    /** Defensa server-side: si Campaña viene como '2025/26' o '2026-2027', tomar primer año. */
    @isTest
    static void primerAnioTest() {
        Assert.areEqual(null, CrearVentaInformadaLWCController.primerAnio(null));
        Assert.areEqual('2025', CrearVentaInformadaLWCController.primerAnio('2025/26'));
        Assert.areEqual('2026', CrearVentaInformadaLWCController.primerAnio('2026-2027'));
        Assert.areEqual('2026', CrearVentaInformadaLWCController.primerAnio('2026'));
        Assert.areEqual('2026', CrearVentaInformadaLWCController.primerAnio('26-27'));
        Assert.areEqual('2026', CrearVentaInformadaLWCController.primerAnio('26/27'));
        Assert.areEqual('sin nada', CrearVentaInformadaLWCController.primerAnio('sin nada'),
            'Sin a\u00f1o de 4 d\u00edgitos queda el original.');
    }

    /** Ticket nueva mejora: el lookup Variedad_INASE__c y el Cultivo deben quedar seteados. */
    @isTest
    static void saveVentaSeteaLookupYCultivoTest() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA TEST', Densidad_de_Siembra__c = 1);
        insert cultivo;
        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'VI SAVE SOJA 2025',
            Ano__c = '2025',
            Id_Externo__c = 'VI_SAVE_CAMP_001',
            Z9_Clave_Unica__c = 'VI_Z9_SAVE_001',
            SKEY_CAMPANIA__c = 8800201,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c v = new Variedad__c(
            Cultivar_Inase__c = 'soja test 1',
            Cultivo__c = cultivo.Id
        );
        insert v;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Destinatario__c = '20398301987',
            CUIT_Originante__c = '20389301977',
            Variedad__c = 'soja test 1',
            Cantidad_de_Bolsas__c = 40,
            Campana_de_Ventas__c = '2025/26',
            Campana_Agricola__c = campana.Id
        );

        Test.startTest();
        String id = CrearVentaInformadaLWCController.saveVentaInformada(venta, v.Id, null);
        Test.stopTest();

        Ventas_Informadas__c saved = [
            SELECT Variedad_INASE__c, Cultivo__c, Campana_de_Ventas__c
            FROM Ventas_Informadas__c WHERE Id = :id LIMIT 1
        ];
        Assert.areEqual(v.Id, saved.Variedad_INASE__c, 'Variedad_INASE__c debe quedar seteado.');
        Assert.areEqual(cultivo.Id, saved.Cultivo__c, 'Cultivo__c se infiere desde la Variedad.');
        Assert.areEqual('2025', saved.Campana_de_Ventas__c, 'Campa\u00f1a se normaliza a primer a\u00f1o.');
    }

    @isTest
    static void getCuentaNoExisteTest() {
        List<Account> accs = [SELECT Id FROM Account LIMIT 1];
        String fakeId = String.valueOf(accs[0].Id).substring(0, 15) + 'AAA';
        Assert.isNull(CrearVentaInformadaLWCController.getCuenta(fakeId));
    }

    /** Cobertura: getRazonSocialPorCuit con CUIT que no existe (rama ARCA stub). */
    @isTest
    static void getRazonSocialPorCuitNoExisteTest() {
        Test.startTest();
        String r1 = CrearVentaInformadaLWCController.getRazonSocialPorCuit(null, null);
        String r2 = CrearVentaInformadaLWCController.getRazonSocialPorCuit('', null);
        String r3 = CrearVentaInformadaLWCController.getRazonSocialPorCuit('99999999999', null);
        Test.stopTest();
        Assert.areEqual(null, r1);
        Assert.areEqual(null, r2);
        Assert.areEqual(null, r3, 'CUIT que no existe en SF y no hay ARCA conectado => null.');
    }

    /** Cobertura: getVariedad con campanaAgricolaId null y con campaña sin cultivo. */
    @isTest
    static void getVariedadCasosBordeTest() {
        Test.startTest();
        List<LookupSearchResult> r1 = CrearVentaInformadaLWCController.getVariedad('x', new List<String>(), null);
        Test.stopTest();
        Assert.areEqual(0, r1.size(), 'Sin campañaId => lista vacía.');
    }

    /** Picklist campañas: orden SOJA → TRIGO → demás; años en rango actual−2 … actual+1. */
    @isTest
    static void getCampanasAgricolasParaPicklistOrdenTest() {
        Test_TestUtils.disableFlows();

        Integer yMin = CrearVentaInformadaLWCController.anoMinimoCampanaPicklist();
        Integer yMid = Date.today().year();
        Integer yMax = CrearVentaInformadaLWCController.anoMaximoCampanaPicklist();
        Integer yFuera = yMin - 5;

        Cultivo__c soja = new Cultivo__c(Name = 'SOJA', Densidad_de_Siembra__c = 1);
        Cultivo__c trigo = new Cultivo__c(Name = 'TRIGO', Densidad_de_Siembra__c = 1);
        Cultivo__c maiz = new Cultivo__c(Name = 'MAIZ', Densidad_de_Siembra__c = 1);
        insert new List<Cultivo__c>{ soja, trigo, maiz };

        insert new List<Campana_Agricola__c>{
            new Campana_Agricola__c(
                Name = 'VI SOJA MIN ' + yMin,
                Ano__c = String.valueOf(yMin),
                Id_Externo__c = 'VI_SOJA_MIN',
                Z9_Clave_Unica__c = 'VI_Z9_SOJA_MIN',
                SKEY_CAMPANIA__c = 8800101,
                Cultivo__c = soja.Id
            ),
            new Campana_Agricola__c(
                Name = 'VI SOJA MID ' + yMid,
                Ano__c = String.valueOf(yMid),
                Id_Externo__c = 'VI_SOJA_MID',
                Z9_Clave_Unica__c = 'VI_Z9_SOJA_MID',
                SKEY_CAMPANIA__c = 8800102,
                Cultivo__c = soja.Id
            ),
            new Campana_Agricola__c(
                Name = 'VI SOJA OUT ' + yFuera,
                Ano__c = String.valueOf(yFuera),
                Id_Externo__c = 'VI_SOJA_OUT',
                Z9_Clave_Unica__c = 'VI_Z9_SOJA_OUT',
                SKEY_CAMPANIA__c = 8800105,
                Cultivo__c = soja.Id
            )
        };

        Assert.areEqual(0, CrearVentaInformadaLWCController.cultivoGrupoOrden('SOJA'));
        Assert.areEqual(1, CrearVentaInformadaLWCController.cultivoGrupoOrden('TRIGO'));
        Assert.areEqual(2, CrearVentaInformadaLWCController.cultivoGrupoOrden('MAIZ'));
        Assert.isTrue(CrearVentaInformadaLWCController.campanaAnoEnRangoPicklist(String.valueOf(yMid)));
        Assert.isFalse(CrearVentaInformadaLWCController.campanaAnoEnRangoPicklist(String.valueOf(yFuera)));

        Test.startTest();
        List<LookupSearchResult> enRango =
            CrearVentaInformadaLWCController.getCampanasAgricolasParaLookup('');
        Test.stopTest();

        Assert.isTrue(enRango.size() >= 1, 'Debe listar campañas en rango tras insertar datos de prueba.');
    }

    @isTest
    static void getNombreCultivoPorCampanaTest() {
        Test_TestUtils.disableFlows();
        Cultivo__c cultivo = new Cultivo__c(Name = 'VI CULTIVO NOMBRE', Densidad_de_Siembra__c = 1);
        insert cultivo;
        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'VI CAMP NOMBRE 2025',
            Ano__c = '2025',
            Id_Externo__c = 'VI_CAMP_NOM_001',
            Z9_Clave_Unica__c = 'VI_Z9_NOM_001',
            SKEY_CAMPANIA__c = 8800301,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Test.startTest();
        String nombre = CrearVentaInformadaLWCController.getNombreCultivoPorCampana(campana.Id);
        String vacio = CrearVentaInformadaLWCController.getNombreCultivoPorCampana(null);
        Test.stopTest();

        Assert.areEqual('VI CULTIVO NOMBRE', nombre);
        Assert.areEqual(null, vacio);
    }

    @isTest
    static void getCampanasAgricolasParaLookupBusquedaTest() {
        Test_TestUtils.disableFlows();
        
        Cultivo__c soja = new Cultivo__c(Name = 'SOJA', Densidad_de_Siembra__c = 1);
        insert soja;
        
        insert new Campana_Agricola__c(
            Name = 'SOJA 2025',
            Ano__c = '2025',
            Id_Externo__c = 'VI_SOJA_SEARCH',
            Z9_Clave_Unica__c = 'VI_Z9_SEARCH',
            SKEY_CAMPANIA__c = 9900001,
            Cultivo__c = soja.Id
        );

        Test.startTest();
        List<LookupSearchResult> todos = CrearVentaInformadaLWCController.getCampanasAgricolasParaLookup('');
        List<LookupSearchResult> filtrado = CrearVentaInformadaLWCController.getCampanasAgricolasParaLookup('SOJA');
        List<LookupSearchResult> sinMatch = CrearVentaInformadaLWCController.getCampanasAgricolasParaLookup('TRIGO');
        Test.stopTest();

        Assert.isTrue(todos.size() >= 1, 'Debe devolver todas las campañas en rango.');
        Assert.isTrue(filtrado.size() >= 1, 'Debe filtrar por SOJA.');
        Boolean contieneLabel = false;
        for (LookupSearchResult r : filtrado) {
            if (r.title.contains('SOJA')) {
                contieneLabel = true;
                break;
            }
        }
        Assert.isTrue(contieneLabel, 'Label debe contener SOJA.');
        Assert.areEqual(0, sinMatch.size(), 'No debe devolver campañas de TRIGO si no existen.');
    }

    @isTest
    static void escapeSoqlLikeTest() {
        Assert.areEqual('VI\\_Z9\\_SOJA', CrearVentaInformadaLWCController.escapeSoqlLike('VI_Z9_SOJA'));
        Assert.areEqual('100\\% test', CrearVentaInformadaLWCController.escapeSoqlLike('100% test'));
    }

    @isTest
    static void campanaAnoEnRangoPicklistTest() {
        Integer min = CrearVentaInformadaLWCController.anoMinimoCampanaPicklist();
        Integer max = CrearVentaInformadaLWCController.anoMaximoCampanaPicklist();
        Assert.areEqual(Date.today().year() - 2, min);
        Assert.areEqual(Date.today().year() + 1, max);
        Assert.isTrue(CrearVentaInformadaLWCController.campanaAnoEnRangoPicklist(String.valueOf(min)));
        Assert.isTrue(CrearVentaInformadaLWCController.campanaAnoEnRangoPicklist(String.valueOf(max)));
        Assert.isFalse(CrearVentaInformadaLWCController.campanaAnoEnRangoPicklist(String.valueOf(min - 1)));
        Assert.isFalse(CrearVentaInformadaLWCController.campanaAnoEnRangoPicklist(String.valueOf(max + 1)));
        Assert.isTrue(CrearVentaInformadaLWCController.campanaAnoEnRangoPicklist('2025/26'));
    }

    /** Cobertura: getDiccionariosPlantilla devuelve las 4 listas con contenido o vacías. */
    @isTest
    static void getDiccionariosPlantillaTest() {
        Test.startTest();
        Map<String, List<String>> dicc = CrearVentaInformadaLWCController.getDiccionariosPlantilla();
        Test.stopTest();

        Assert.isTrue(dicc.containsKey('variedades'));
        Assert.isTrue(dicc.containsKey('categorias'));
        Assert.isTrue(dicc.containsKey('tiposComprobante'));
        Assert.isTrue(dicc.containsKey('campanasAgricolas'));
        Assert.isTrue(dicc.get('categorias').size() >= 4, 'Hay al menos 4 categorías INASE.');
        Assert.isTrue(dicc.get('tiposComprobante').contains('FC'));
        Assert.isTrue(dicc.get('tiposComprobante').contains('Remito'));
    }

    /** Si no se manda variedadId, se rechaza. */
    @isTest
    static void saveVentaSinVariedadIdLanzaExcepcionTest() {
        Test_TestUtils.disableFlows();
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Destinatario__c = '20398301987',
            CUIT_Originante__c = '20389301977',
            Variedad__c = 'algo',
            Cantidad_de_Bolsas__c = 40,
            Campana_de_Ventas__c = '2025'
        );

        Boolean throwException = false;
        Test.startTest();
        try {
            CrearVentaInformadaLWCController.saveVentaInformada(venta, null, null);
        } catch (Exception e) {
            throwException = true;
        }
        Test.stopTest();

        Assert.isTrue(throwException, 'Se esperaba excepci\u00f3n por variedadId nulo.');
    }
}