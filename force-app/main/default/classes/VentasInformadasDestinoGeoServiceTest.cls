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
        Account stine = obtenerOStineObtentor('STINE TEST');
        Variedad__c varStine = crearVariedad(stine.Id, 'STINE 99TEST');
        System.assertEquals(true, VentasInformadasDestinoGeoService.esVariedadStine(varStine.Id));
        System.assertEquals(false, VentasInformadasDestinoGeoService.requiereDestinoParaVariedad(varStine.Id));

        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, varStine.Id);

        Provincia__c prov = new Provincia__c(Name = 'Buenos Aires Test');
        insert prov;
        Localidad__c loc = new Localidad__c(Name = 'La Plata Test', Provincia__c = prov.Id);
        insert loc;
        venta.Provincia_Destino__c = prov.Id;
        venta.Localidad_Destino__c = loc.Id;
        VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, varStine.Id);
    }

    @IsTest
    static void noStineNoRequiereDestino() {
        Account otro = crearObtentor('99', 'OTRO OBTENTOR');
        Variedad__c varOtro = crearVariedad(otro.Id, 'VAR NO STINE');

        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, varOtro.Id);
        System.assertEquals(false, VentasInformadasDestinoGeoService.esVariedadStine(varOtro.Id));
    }

    @IsTest
    static void flagApagadoNoObligaStine() {
        desactivarFlagStine();

        Account stine = obtenerOStineObtentor('STINE FLAG OFF');
        Variedad__c varStine = crearVariedad(stine.Id, 'STINE FLAG');

        Ventas_Informadas__c venta = new Ventas_Informadas__c();
        VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, varStine.Id);
        System.assertEquals(false, VentasInformadasDestinoGeoService.requiereDestinoStineActivo());
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
        Account stine = obtenerOStineObtentor('STINE LOC');
        Variedad__c varStine = crearVariedad(stine.Id, 'STINE LOC VAR');

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Provincia_Destino__c = provA.Id,
            Localidad_Destino__c = locB.Id
        );
        Boolean ex = false;
        try {
            VentasInformadasDestinoGeoService.validarDestinoObligatorio(venta, varStine.Id);
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
        Account stine = obtenerOStineObtentor('STINE VAR OBJ');
        Variedad__c varStine = crearVariedad(stine.Id, 'STINE VAR OBJ');
        varStine = [
            SELECT Id, Obtentor_Comercializa__r.Id_Obtentor__c, Obtentor_Comercializa__r.Name
            FROM Variedad__c
            WHERE Id = :varStine.Id
            LIMIT 1
        ];
        System.assertEquals(false, VentasInformadasDestinoGeoService.requiereDestinoParaVariedad(varStine));
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

    private static Integer cuitSeq = 0;

    private static String nextValidCuit() {
        List<String> cuits = new List<String>{
            '33645022659',
            '20144462980',
            '30709538418',
            '30711969523',
            '30500120882'
        };
        String cuit = cuits[Math.mod(cuitSeq, cuits.size())];
        cuitSeq++;
        return cuit;
    }

    private static Account crearObtentor(String idObtentor, String nombre) {
        Id rtObt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Obtentor')
            .getRecordTypeId();
        Account acc = new Account(
            Name = nombre,
            RecordTypeId = rtObt,
            Id_Obtentor__c = idObtentor,
            N_CUIT__c = nextValidCuit()
        );
        insert acc;
        return acc;
    }

    private static Variedad__c crearVariedad(Id obtentorId, String cultivar) {
        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA GEO', Densidad_de_Siembra__c = 1);
        insert cultivo;
        Variedad__c v = new Variedad__c(
            Name = cultivar,
            Cultivar_Inase__c = cultivar,
            Cultivo__c = cultivo.Id,
            Obtentor_Comercializa__c = obtentorId
        );
        insert v;
        return [
            SELECT Id, Obtentor_Comercializa__c
            FROM Variedad__c
            WHERE Id = :v.Id
            LIMIT 1
        ];
    }

    private static Account obtenerOStineObtentor(String nombreFallback) {
        List<Account> existentes = [
            SELECT Id
            FROM Account
            WHERE Id_Obtentor__c = '24'
            LIMIT 1
        ];
        if (!existentes.isEmpty()) {
            return existentes[0];
        }
        return crearObtentor('24', nombreFallback);
    }
}
