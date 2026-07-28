@IsTest
private class VentasInformadasDestinoGeoServiceTest {

    @TestSetup
    static void setup() {
        Test_TestUtils.disableFlows();
        VentasInformadasDestinoGeoService.resetCachesForTests();
    }

    private static void activarFlagStine() {
        Ventas_Informadas_Settings__c cfg = Ventas_Informadas_Settings__c.getOrgDefaults();
        if (cfg == null) {
            cfg = new Ventas_Informadas_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        }
        cfg.Requiere_Destino_Stine__c = true;
        upsert cfg;
        VentasInformadasDestinoGeoService.forceRequiereDestinoStineForTests = true;
    }

    private static void desactivarFlagStine() {
        Ventas_Informadas_Settings__c cfg = Ventas_Informadas_Settings__c.getOrgDefaults();
        if (cfg == null) {
            cfg = new Ventas_Informadas_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        }
        cfg.Requiere_Destino_Stine__c = false;
        upsert cfg;
        VentasInformadasDestinoGeoService.forceRequiereDestinoStineForTests = false;
    }

    @IsTest
    static void provinciasYLocalidadesLookup() {
        Provincia__c prov = new Provincia__c(Name = 'Santa Fe Lookup');
        insert prov;
        insert new Localidad__c(Name = 'Rosario Lookup', Provincia__c = prov.Id);

        Test.startTest();
        List<LookupSearchResult> provs =
            VentasInformadasDestinoGeoService.getProvinciasDestinoParaLookup('santa');
        List<LookupSearchResult> locs =
            VentasInformadasDestinoGeoService.getLocalidadesDestinoParaLookup(prov.Id, 'ros');
        Test.stopTest();

        System.assert(!provs.isEmpty());
        System.assertEquals(1, locs.size());
        System.assertEquals('Rosario Lookup', locs[0].title);
    }

    @IsTest
    static void provinciasYLocalidadesPorProvincia() {
        Provincia__c prov = new Provincia__c(Name = 'Santa Fe Test');
        insert prov;
        insert new Localidad__c(Name = 'Rosario Test', Provincia__c = prov.Id);

        Test.startTest();
        List<VentasInformadasDestinoGeoService.GeoOption> provs =
            VentasInformadasDestinoGeoService.getProvinciasDestino();
        List<VentasInformadasDestinoGeoService.GeoOption> locs =
            VentasInformadasDestinoGeoService.getLocalidadesDestinoPorProvincia(prov.Id);
        Test.stopTest();

        System.assert(!provs.isEmpty());
        System.assertEquals(1, locs.size());
        System.assertEquals('Rosario Test', locs[0].label);
    }

    @IsTest
    static void destinoOpcionalInclusoParaStineConFlagActivo() {
        activarFlagStine();
        // Sin insert de Account: en PROD el flow "Cuenta. Creación Datos ERP" falla en tests.
        Variedad__c varStine = variedadConObtentorInMemory('24', 'STINE TEST');
        System.assertEquals(true, VentasInformadasDestinoGeoService.esVariedadStine(varStine));
        System.assertEquals(false, VentasInformadasDestinoGeoService.requiereDestinoParaVariedad(varStine));
        System.assertEquals(false, VentasInformadasDestinoGeoService.requiereDestinoParaVariedad((Id) null));

        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, null);

        Provincia__c prov = new Provincia__c(Name = 'Buenos Aires Test');
        insert prov;
        Localidad__c loc = new Localidad__c(Name = 'La Plata Test', Provincia__c = prov.Id);
        insert loc;
        venta.Provincia_Destino__c = prov.Id;
        venta.Localidad_Destino__c = loc.Id;
        VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, null);
    }

    @IsTest
    static void noStineNoRequiereDestino() {
        Variedad__c varOtro = variedadConObtentorInMemory('99', 'OTRO OBTENTOR');

        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, null);
        System.assertEquals(false, VentasInformadasDestinoGeoService.esVariedadStine(varOtro));
        System.assertEquals(false, VentasInformadasDestinoGeoService.esVariedadStine((Id) null));
    }

    @IsTest
    static void flagApagadoNoObligaStine() {
        desactivarFlagStine();

        Variedad__c varStine = variedadConObtentorInMemory('24', 'STINE FLAG OFF');
        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, null);
        System.assertEquals(false, VentasInformadasDestinoGeoService.requiereDestinoStineActivo());
        System.assertEquals(true, VentasInformadasDestinoGeoService.esVariedadStine(varStine));
    }

    @IsTest
    static void resolveDestinoDesdeFilasImport() {
        Provincia__c prov = new Provincia__c(Name = 'Cordoba Test');
        insert prov;
        Localidad__c loc = new Localidad__c(Name = 'Villa Maria Test', Provincia__c = prov.Id);
        insert loc;

        Map<String, Id> provMap = VentasInformadasDestinoGeoService.loadProvinciasByKey();

        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        Map<String, Object> row = new Map<String, Object>{
            'Provincia Destino' => 'Cordoba Test',
            'Localidad Destino' => 'Villa Maria Test'
        };
        VentasInformadasDestinoGeoService.aplicarDestinoDesdeFilas(venta, row, provMap);

        System.assertEquals(prov.Id, venta.Provincia_Destino__c);
        System.assertEquals(loc.Id, venta.Localidad_Destino__c);
    }

    @IsTest
    static void localidadSinProvinciaFalla() {
        Provincia__c prov = new Provincia__c(Name = 'Prov Loc Test');
        insert prov;
        Localidad__c loc = new Localidad__c(Name = 'Loc Test', Provincia__c = prov.Id);
        insert loc;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Localidad_Destino__c = loc.Id
        );
        Boolean ex = false;
        try {
            VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, null);
        } catch (AuraHandledException e) {
            ex = true;
        }
        System.assertEquals(true, ex);
    }

    @IsTest
    static void localidadDeOtraProvinciaFalla() {
        Provincia__c provA = new Provincia__c(Name = 'Prov A Test');
        Provincia__c provB = new Provincia__c(Name = 'Prov B Test');
        insert new List<Provincia__c>{ provA, provB };
        Localidad__c locB = new Localidad__c(Name = 'Loc B Test', Provincia__c = provB.Id);
        insert locB;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Provincia_Destino__c = provA.Id,
            Localidad_Destino__c = locB.Id
        );
        Boolean ex = false;
        try {
            VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, null);
        } catch (AuraHandledException e) {
            ex = true;
        }
        System.assertEquals(true, ex);
    }

    @IsTest
    static void buildLocalidadesCacheBulkUnaSolaQuery() {
        Provincia__c prov = new Provincia__c(Name = 'Cache Prov Test');
        insert prov;
        insert new List<Localidad__c>{
            new Localidad__c(Name = 'Loc Cache A', Provincia__c = prov.Id),
            new Localidad__c(Name = 'Loc Cache B', Provincia__c = prov.Id)
        };
        Map<String, Id> provMap = VentasInformadasDestinoGeoService.loadProvinciasByKey();

        Test.startTest();
        Map<Id, Map<String, Id>> cache =
            VentasInformadasDestinoGeoService.buildLocalidadesCacheForProvinciaIds(
                new Set<Id>{ prov.Id }
            );
        Test.stopTest();

        System.assertEquals(2, cache.get(prov.Id).size());
        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        Map<String, Object> row = new Map<String, Object>{
            'Provincia Destino' => 'Cache Prov Test',
            'Localidad Destino' => 'Loc Cache A'
        };
        VentasInformadasDestinoGeoService.aplicarDestinoDesdeFilas(
            venta,
            row,
            provMap,
            cache
        );
        System.assertNotEquals(null, venta.Localidad_Destino__c);
    }

    @IsTest
    static void requiereDestinoParaVariedadSiempreOpcional() {
        activarFlagStine();
        Variedad__c varStine = variedadConObtentorInMemory('24', 'STINE VAR OBJ');
        System.assertEquals(false, VentasInformadasDestinoGeoService.requiereDestinoParaVariedad(varStine));
        System.assertEquals(true, VentasInformadasDestinoGeoService.esVariedadStine(varStine));

        // Nombre STINE / M.S. TECHNOLOGIES sin Id_Obtentor 24
        Variedad__c porNombre = variedadConObtentorInMemory(null, 'M.S. TECHNOLOGIES SA');
        System.assertEquals(true, VentasInformadasDestinoGeoService.esVariedadStine(porNombre));
    }

    @IsTest
    static void esVariedadStinePorIdSinObtentorEsFalse() {
        // Variedad sin Account: cubre query path sin disparar flow ERP de Cuenta.
        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA GEO', Densidad_de_Siembra__c = 1);
        insert cultivo;
        Variedad__c v = new Variedad__c(
            Name = 'VAR SIN OBT',
            Cultivar_Inase__c = 'VAR SIN OBT',
            Cultivo__c = cultivo.Id
        );
        insert v;
        System.assertEquals(false, VentasInformadasDestinoGeoService.esVariedadStine(v.Id));
        System.assertEquals(false, VentasInformadasDestinoGeoService.esVariedadStine((Variedad__c) null));
    }

    @IsTest
    static void requiereDestinoStineActivoConsulta() {
        desactivarFlagStine();
        System.assertEquals(false, VentasInformadasDestinoGeoService.requiereDestinoStineActivo());
        activarFlagStine();
        System.assertEquals(true, VentasInformadasDestinoGeoService.requiereDestinoStineActivo());
    }

    @IsTest
    static void resolveProvinciaPorIdSalesforce() {
        Provincia__c prov = new Provincia__c(Name = 'Mendoza Test');
        insert prov;
        Map<String, Id> provMap = VentasInformadasDestinoGeoService.loadProvinciasByKey();
        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        Map<String, Object> row = new Map<String, Object>{
            'Provincia Destino' => String.valueOf(prov.Id)
        };
        VentasInformadasDestinoGeoService.aplicarDestinoDesdeFilas(venta, row, provMap);
        System.assertEquals(prov.Id, venta.Provincia_Destino__c);
    }

    @IsTest
    static void resolveProvinciaPorNombreNoConfundeConId() {
        Provincia__c prov = new Provincia__c(Name = 'Santiago del Estero');
        insert prov;
        Map<String, Id> provMap = VentasInformadasDestinoGeoService.loadProvinciasByKey();

        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        Map<String, Object> row = new Map<String, Object>{
            'Provincia Destino' => 'SANTIAGO DEL ESTERO'
        };
        VentasInformadasDestinoGeoService.aplicarDestinoDesdeFilas(venta, row, provMap);
        System.assertEquals(prov.Id, venta.Provincia_Destino__c);

        Set<Id> provinciaIds = VentasInformadasDestinoGeoService.collectProvinciaIdsDesdeFilas(
            new List<Map<String, Object>>{ row },
            provMap
        );
        System.assertEquals(1, provinciaIds.size());
        System.assert(provinciaIds.contains(prov.Id));
    }

    /** Variedad en memoria con relación Obtentor (sin DML Account → evita flow ERP en PROD). */
    private static Variedad__c variedadConObtentorInMemory(String idObtentor, String nombre) {
        Account obt = new Account(Name = nombre);
        if (String.isNotBlank(idObtentor)) {
            obt.Id_Obtentor__c = idObtentor;
        }
        return new Variedad__c(
            Name = nombre,
            Cultivar_Inase__c = nombre,
            Obtentor_Comercializa__r = obt
        );
    }
}
