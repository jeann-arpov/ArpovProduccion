@IsTest
private class VentasInformadasEnrichmentSvcTest {

    @TestSetup
    static void setup() {
        Test_TestUtils.disableFlows();
    }

    @IsTest
    static void enriquecerYActualizarCompletaVariedadInaseYCampana() {
        VentasInformadasApiNormalizer.forceEnabledForTests = false;
        insert new Ventas_Informadas_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Normalizar_Ingreso_Externo__c = false
        );

        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA ENRICH', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana Enrich 2026',
            Ano__c = '2026',
            Id_Externo__c = 'VI_ENR_2026',
            Z9_Clave_Unica__c = 'VI_ENR_Z9_2026',
            SKEY_CAMPANIA__c = 8800201,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(
            Name = 'ENRICH 023',
            Cultivar_INASE__c = 'ENRICH 023',
            Cultivo__c = cultivo.Id
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2026',
            Cantidad_de_Bolsas__c = 10,
            Categoria__c = 'Primera Multiplicación',
            Fecha_de_Facturacion__c = Date.today(),
            Kilos_por_Bolsa__c = 50,
            N_de_Comprobante__c = 'ENRICH-001',
            Variedad__c = 'enrich 023',
            Tipo_de_Comprobante__c = 'FC',
            Linea_Facturacion__c = 1
        );
        insert venta;

        venta = (Ventas_Informadas__c) Database.query(
            'SELECT ' +
                VentasInformadasPortalEnrichmentService.camposEnriquecimientoSoql() +
                ' FROM Ventas_Informadas__c WHERE Id = \'' +
                String.valueOf(venta.Id) +
                '\''
        );
        System.assertEquals(null, venta.Variedad_INASE__c);

        Test.startTest();
        VentasInformadasPortalEnrichmentService.Result resultado =
            VentasInformadasPortalEnrichmentService.enriquecerYActualizar(
                new List<Ventas_Informadas__c>{ venta }
            );
        Test.stopTest();

        System.assertEquals(1, resultado.total);
        System.assertEquals(1, resultado.actualizados, resultado.avisos.toString());

        venta = [
            SELECT Variedad_INASE__c, Campana_Agricola__c, Cultivo__c, Kilos_por_Bolsa__c, Variedad__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(variedad.Id, venta.Variedad_INASE__c);
        System.assertEquals(campana.Id, venta.Campana_Agricola__c);
        System.assertEquals(cultivo.Id, venta.Cultivo__c);
        System.assertEquals(1, venta.Kilos_por_Bolsa__c);
        System.assertEquals('ENRICH 023', venta.Variedad__c);
    }

    @IsTest
    static void enriquecerReportaVariedadInexistente() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2026',
            Cantidad_de_Bolsas__c = 10,
            Categoria__c = 'Primera Multiplicación',
            Fecha_de_Facturacion__c = Date.today(),
            Variedad__c = 'NO EXISTE XYZ',
            Tipo_de_Comprobante__c = 'FC',
            Linea_Facturacion__c = 1
        );
        insert venta;

        venta = [
            SELECT
                Id,
                Variedad__c,
                Variedad_INASE__c,
                Campana_Agricola__c,
                Campana_de_Ventas__c,
                Categoria__c,
                Categoria_Portal__c,
                CUIT_Originante__c,
                CUIT_Destinatario__c,
                Originante__c,
                Destinatario__c,
                Rol_Originante__c,
                Rol_Destinatario__c,
                Producto__c,
                Venta_Interna__c,
                Kilos_por_Bolsa__c,
                Tipo_de_Comprobante__c,
                Tipo_Comprobante_Externo__c,
                Cultivo__c,
                Cultivo_campa_a__c,
                Venta__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];

        VentasInformadasPortalEnrichmentService.Result resultado =
            VentasInformadasPortalEnrichmentService.enriquecerYActualizar(
                new List<Ventas_Informadas__c>{ venta }
            );

        System.assertEquals(1, resultado.errores);
        System.assertEquals(0, resultado.actualizados);
        System.assert(!resultado.avisos.isEmpty());
    }

    @IsTest
    static void enriquecerVentasApiFiltraPorUsuarioYFecha() {
        VentasInformadasApiNormalizer.forceEnabledForTests = false;
        insert new Ventas_Informadas_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Normalizar_Ingreso_Externo__c = false
        );

        Cultivo__c cultivo = new Cultivo__c(Name = 'MAIZ API FILTRO', Densidad_de_Siembra__c = 1);
        insert cultivo;

        insert new Campana_Agricola__c(
            Name = 'Campana API 2026',
            Ano__c = '2026',
            Id_Externo__c = 'VI_API_FILTRO_2026',
            Z9_Clave_Unica__c = 'VI_API_FILTRO_Z9',
            SKEY_CAMPANIA__c = 8800203,
            Cultivo__c = cultivo.Id
        );

        insert new Variedad__c(
            Name = 'API FILTRO 01',
            Cultivar_INASE__c = 'API FILTRO 01',
            Cultivo__c = cultivo.Id
        );

        insert new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2026',
            Cantidad_de_Bolsas__c = 5,
            Categoria__c = 'Primera Multiplicación',
            Fecha_de_Facturacion__c = Date.today(),
            Variedad__c = 'API FILTRO 01',
            Tipo_de_Comprobante__c = 'FC',
            Linea_Facturacion__c = 1
        );

        VentasInformadasPortalEnrichmentService.Result resultado =
            VentasInformadasPortalEnrichmentService.enriquecerVentasApi(
                UserInfo.getUserId(),
                Datetime.newInstanceGmt(2020, 1, 1, 0, 0, 0),
                Datetime.newInstanceGmt(2030, 12, 31, 23, 59, 59),
                50
            );

        System.assert(resultado.total >= 1, 'Debe encontrar ventas del usuario actual.');
        System.assert(resultado.actualizados >= 1, resultado.avisos.toString());
    }

    @IsTest
    static void completarEnriquecimientoPortalSeteaCultivoDesdeCampana() {
        Cultivo__c cultivo = new Cultivo__c(Name = 'TRIGO PORTAL', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana Portal 2026',
            Ano__c = '2026',
            Id_Externo__c = 'VI_PORTAL_2026',
            Z9_Clave_Unica__c = 'VI_PORTAL_Z9',
            SKEY_CAMPANIA__c = 8800205,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(
            Name = 'VAR PORTAL',
            Cultivar_INASE__c = 'VAR PORTAL',
            Cultivo__c = cultivo.Id
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campana.Id,
            Variedad_INASE__c = variedad.Id,
            Variedad__c = 'VAR PORTAL',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 1,
            Fecha_de_Facturacion__c = Date.today(),
            Tipo_de_Comprobante__c = 'FC',
            Linea_Facturacion__c = 1
        );
        insert venta;

        venta = (Ventas_Informadas__c) Database.query(
            'SELECT ' +
                VentasInformadasPortalEnrichmentService.camposEnriquecimientoSoql() +
                ' FROM Ventas_Informadas__c WHERE Id = \'' +
                String.valueOf(venta.Id) +
                '\''
        );

        VentasInformadasTriggerHandler.completarEnriquecimientoPortal(
            new List<Ventas_Informadas__c>{ venta }
        );

        System.assertEquals(cultivo.Id, venta.Cultivo__c);
        System.assertEquals('2026', venta.Campana_de_Ventas__c);
        System.assertEquals('TRIGO PORTAL', venta.Cultivo_campa_a__c);
    }
}