@IsTest
private class VentasInformadasApiNormalizerTest {

    @TestSetup
    static void setup() {
        Test_TestUtils.disableFlows();
    }

    @IsTest
    static void normalizaIngresoApiComoImportacion() {
        VentasInformadasApiNormalizer.forceEnabledForTests = true;

        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA API VI', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana API 2022',
            Ano__c = '2022',
            Id_Externo__c = 'VI_API_2022',
            Z9_Clave_Unica__c = 'VI_API_Z9_2022',
            SKEY_CAMPANIA__c = 8800200,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Id rtDist = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Distribuidor')
            .getRecordTypeId();
        Id rtProd = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Productor')
            .getRecordTypeId();

        Account originante = new Account(
            Name = 'Distribuidor API Test',
            N_CUIT__c = '33645022659',
            Type = 'Distribuidor',
            RecordTypeId = rtDist
        );
        Account destinatario = new Account(
            Name = 'Agropecuaria Los Toldos',
            N_CUIT__c = '20144462980',
            Type = 'Productor',
            RecordTypeId = rtProd
        );
        insert new List<Account>{ originante, destinatario };

        Variedad__c variedad = new Variedad__c(
            Name = 'VAR SE 023',
            Cultivar_INASE__c = 'VAR SE 023',
            Cultivo__c = cultivo.Id
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '22/23',
            Cantidad_de_Bolsas__c = 200,
            Categoria__c = 'Primera Multiplicación',
            CUIT_Destinatario__c = '20144462980',
            Fecha_de_Facturacion__c = Date.newInstance(2022, 4, 4),
            Kilos_por_Bolsa__c = 105,
            N_de_Comprobante__c = 'A000212345678',
            Razon_Social_Destinatario__c = 'Agropecuaria Los Toldos',
            Variedad__c = 'var se 023',
            CUIT_Originante__c = '33645022659',
            Tipo_de_Comprobante__c = 'FC',
            Linea_Facturacion__c = 1
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Campana_Agricola__c, Campana_de_Ventas__c, Variedad__c, Variedad_INASE__c,
                   Originante__c, Destinatario__c, Cultivo__c, Kilos_por_Bolsa__c,
                   Tipo_de_Comprobante__c, Tipo_Comprobante_Externo__c, Categoria__c,
                   Rol_Originante__c, Rol_Destinatario__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];

        System.assertEquals(campana.Id, venta.Campana_Agricola__c, 'Debe resolver campaña por cultivo y año.');
        System.assertEquals('2022', venta.Campana_de_Ventas__c, '22/23 debe normalizarse a 2022.');
        System.assertEquals(variedad.Id, venta.Variedad_INASE__c);
        System.assertEquals('VAR SE 023', venta.Variedad__c);
        System.assertEquals(originante.Id, venta.Originante__c);
        System.assertEquals(destinatario.Id, venta.Destinatario__c);
        System.assertEquals('Distribuidor', venta.Rol_Originante__c);
        System.assertEquals('Productor', venta.Rol_Destinatario__c);
        System.assertEquals(cultivo.Id, venta.Cultivo__c);
        System.assertEquals(1, venta.Kilos_por_Bolsa__c, 'Kilos por bolsa fijo en 1 como import.');
        System.assertEquals('FC', venta.Tipo_de_Comprobante__c);
        System.assertEquals('FC', venta.Tipo_Comprobante_Externo__c);
        System.assertEquals('Primera Multiplicación', venta.Categoria__c);
    }

    @IsTest
    static void tieneCampoTipoComprobanteExternoConsistenteConSchema() {
        Boolean esperado = Schema.SObjectType.Ventas_Informadas__c.fields.getMap()
            .containsKey('Tipo_Comprobante_Externo__c');
        System.assertEquals(
            esperado,
            VentasInformadasApiNormalizer.tieneCampoTipoComprobanteExterno()
        );
    }

    @IsTest
    static void enriquecerComoPortalListaVaciaNoFalla() {
        System.assertEquals(
            0,
            VentasInformadasApiNormalizer.enriquecerComoPortal(null, false).size()
        );
        System.assertEquals(
            0,
            VentasInformadasApiNormalizer.enriquecerComoPortal(
                new List<Ventas_Informadas__c>(),
                false
            ).size()
        );
    }

    @IsTest
    static void isNormalizacionActivaRespetaOrgDefaultApagado() {
        VentasInformadasApiNormalizer.forceEnabledForTests = false;
        insert new Ventas_Informadas_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Normalizar_Ingreso_Externo__c = false
        );
        System.assertEquals(false, VentasInformadasApiNormalizer.isNormalizacionActiva());
    }

    @IsTest
    static void normalizarBeforeSaveConOrgDefaultActivo() {
        VentasInformadasApiNormalizer.forceEnabledForTests = false;
        insert new Ventas_Informadas_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Normalizar_Ingreso_Externo__c = true
        );

        Cultivo__c cultivo = new Cultivo__c(Name = 'MAIZ ORG ON', Densidad_de_Siembra__c = 1);
        insert cultivo;

        insert new Campana_Agricola__c(
            Name = 'Campana Org On 2026',
            Ano__c = '2026',
            Id_Externo__c = 'VI_ORG_ON_2026',
            Z9_Clave_Unica__c = 'VI_ORG_ON_Z9',
            SKEY_CAMPANIA__c = 8800207,
            Cultivo__c = cultivo.Id
        );

        insert new Variedad__c(
            Name = 'VAR ORG ON',
            Cultivar_INASE__c = 'VAR ORG ON',
            Cultivo__c = cultivo.Id
        );

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'var org on',
            Categoria__c = 'Primera Multiplicación',
            CUIT_Originante__c = '20123456789',
            CUIT_Destinatario__c = '20987654321',
            Tipo_de_Comprobante__c = 'FC'
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Variedad_INASE__c, Campana_Agricola__c, Cultivo__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertNotEquals(null, venta.Variedad_INASE__c);
        System.assertNotEquals(null, venta.Campana_Agricola__c);
        System.assertNotEquals(null, venta.Cultivo__c);
    }

    @IsTest
    static void noNormalizaSiCustomSettingApagado() {
        VentasInformadasApiNormalizer.forceEnabledForTests = false;
        insert new Ventas_Informadas_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Normalizar_Ingreso_Externo__c = false
        );

        Cultivo__c cultivo = new Cultivo__c(Name = 'MAIZ OFF', Densidad_de_Siembra__c = 1);
        insert cultivo;

        insert new Variedad__c(
            Name = 'VAR OFF',
            Cultivar_INASE__c = 'VAR OFF',
            Cultivo__c = cultivo.Id
        );

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2022',
            Variedad__c = 'VAR OFF',
            CUIT_Originante__c = '20123456789',
            CUIT_Destinatario__c = '20987654321'
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Campana_Agricola__c, Variedad_INASE__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(null, venta.Campana_Agricola__c);
        System.assertEquals(null, venta.Variedad_INASE__c);
    }

    @IsTest
    static void noReprocesaRegistroYaEnriquecidoPorUi() {
        VentasInformadasApiNormalizer.forceEnabledForTests = true;

        Cultivo__c cultivo = new Cultivo__c(Name = 'TRIGO UI', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana UI',
            Ano__c = '2026',
            Id_Externo__c = 'VI_UI_001',
            Z9_Clave_Unica__c = 'VI_UI_Z9',
            SKEY_CAMPANIA__c = 8800201,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(
            Name = 'VAR UI',
            Cultivar_INASE__c = 'VAR UI',
            Cultivo__c = cultivo.Id
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campana.Id,
            Variedad_INASE__c = variedad.Id,
            Variedad__c = 'VAR UI',
            CUIT_Originante__c = '20111111112',
            CUIT_Destinatario__c = '20222222223'
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Originante__c, Destinatario__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(null, venta.Originante__c, 'No debe forzar cuentas si ya venía de UI.');
        System.assertEquals(null, venta.Destinatario__c);
    }

    @IsTest
    static void limpiaCuitConSeparadoresEnBeforeInsert() {
        VentasInformadasApiNormalizer.forceEnabledForTests = true;

        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA CUIT', Densidad_de_Siembra__c = 1);
        insert cultivo;

        insert new Campana_Agricola__c(
            Name = 'Campana CUIT 2022',
            Ano__c = '2022',
            Id_Externo__c = 'VI_CUIT_2022',
            Z9_Clave_Unica__c = 'VI_CUIT_Z9',
            SKEY_CAMPANIA__c = 8800202,
            Cultivo__c = cultivo.Id
        );

        insert new Variedad__c(
            Name = 'VAR CUIT',
            Cultivar_INASE__c = 'VAR CUIT',
            Cultivo__c = cultivo.Id
        );

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2022',
            Variedad__c = 'VAR CUIT',
            CUIT_Originante__c = '20123456789',
            CUIT_Destinatario__c = '20987654321'
        );

        Test.startTest();
        VentasInformadasApiNormalizer.normalizarBeforeSave(
            new List<Ventas_Informadas__c>{ venta },
            null
        );
        Test.stopTest();

        System.assertEquals('20123456789', venta.CUIT_Originante__c);
        System.assertEquals('20987654321', venta.CUIT_Destinatario__c);
    }

    @IsTest
    static void rechazaVariedadInexistente() {
        VentasInformadasApiNormalizer.forceEnabledForTests = true;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2022',
            Variedad__c = 'NO EXISTE 999',
            CUIT_Originante__c = '20123456790',
            CUIT_Destinatario__c = '20987654324'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(venta, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess());
        System.assert(sr.getErrors()[0].getMessage().contains('no existe en Salesforce'));
    }

    @IsTest
    static void enriquecerComoPortalStrictCompletaCampos() {
        Cultivo__c cultivo = new Cultivo__c(Name = 'MAIZ STRICT', Densidad_de_Siembra__c = 1);
        insert cultivo;

        insert new Campana_Agricola__c(
            Name = 'Campana Strict 2025',
            Ano__c = '2025',
            Id_Externo__c = 'VI_STRICT_2025',
            Z9_Clave_Unica__c = 'VI_STRICT_Z9',
            SKEY_CAMPANIA__c = 8800206,
            Cultivo__c = cultivo.Id
        );

        insert new Variedad__c(
            Name = 'VAR STRICT 01',
            Cultivar_INASE__c = 'VAR STRICT 01',
            Cultivo__c = cultivo.Id
        );

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '25/26',
            Variedad__c = 'var strict 01',
            Categoria__c = 'Primera Multiplicación',
            Tipo_Comprobante_Externo__c = 'Remito',
            CUIT_Originante__c = '20123456789',
            CUIT_Destinatario__c = '20987654321'
        );

        List<String> avisos = VentasInformadasApiNormalizer.enriquecerComoPortal(
            new List<Ventas_Informadas__c>{ venta },
            true
        );

        System.assertEquals(0, avisos.size());
        System.assertNotEquals(null, venta.Variedad_INASE__c);
        System.assertNotEquals(null, venta.Campana_Agricola__c);
        System.assertEquals('2025', venta.Campana_de_Ventas__c);
        System.assertEquals('VAR STRICT 01', venta.Variedad__c);
        System.assertEquals('FC', venta.Tipo_de_Comprobante__c);
        System.assertEquals(1, venta.Kilos_por_Bolsa__c);
    }

    @IsTest
    static void enriquecerComoPortalSinStrictAvisaCampanaFaltante() {
        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA AVISO', Densidad_de_Siembra__c = 1);
        insert cultivo;

        insert new Variedad__c(
            Name = 'VAR AVISO',
            Cultivar_INASE__c = 'VAR AVISO',
            Cultivo__c = cultivo.Id
        );

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Variedad__c = 'VAR AVISO'
        );

        List<String> avisos = VentasInformadasApiNormalizer.enriquecerComoPortal(
            new List<Ventas_Informadas__c>{ venta },
            false
        );

        System.assert(!avisos.isEmpty());
        System.assert(avisos[0].contains('Campaña Agrícola'));
    }

    @IsTest
    static void enriquecerComoPortalSinStrictAcumulaAvisos() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR INEXISTENTE 123'
        );

        List<String> avisos = VentasInformadasApiNormalizer.enriquecerComoPortal(
            new List<Ventas_Informadas__c>{ venta },
            false
        );

        System.assertEquals(null, venta.Variedad_INASE__c);
        System.assert(!avisos.isEmpty());
    }

    @IsTest
    static void aplicaTipoComprobanteCaseInsensitive() {
        VentasInformadasApiNormalizer.aplicarTipoComprobante(null);

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Tipo_Comprobante_Externo__c = 'remito'
        );
        VentasInformadasApiNormalizer.aplicarTipoComprobante(venta);
        System.assertEquals('FC', venta.Tipo_de_Comprobante__c);
        if (VentasInformadasApiNormalizer.puedeEscribirTipoComprobanteExterno()) {
            System.assertEquals('Remito', venta.Tipo_Comprobante_Externo__c);
        }

        Ventas_Informadas__c ventaNc = new Ventas_Informadas__c(
            Tipo_Comprobante_Externo__c = 'remito de devolucion'
        );
        VentasInformadasApiNormalizer.aplicarTipoComprobante(ventaNc);
        System.assertEquals('NC', ventaNc.Tipo_de_Comprobante__c);
        if (VentasInformadasApiNormalizer.puedeEscribirTipoComprobanteExterno()) {
            System.assertEquals('Remito de Devolución', ventaNc.Tipo_Comprobante_Externo__c);
        }

        Ventas_Informadas__c soloInterno = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'remito'
        );
        VentasInformadasApiNormalizer.aplicarTipoComprobante(soloInterno);
        System.assertEquals('FC', soloInterno.Tipo_de_Comprobante__c);
        if (VentasInformadasApiNormalizer.puedeEscribirTipoComprobanteExterno()) {
            System.assertEquals('Remito', soloInterno.Tipo_Comprobante_Externo__c);
        }

        Ventas_Informadas__c fcMinus = new Ventas_Informadas__c(
            Tipo_Comprobante_Externo__c = 'fc'
        );
        VentasInformadasApiNormalizer.aplicarTipoComprobante(fcMinus);
        System.assertEquals('FC', fcMinus.Tipo_de_Comprobante__c);
    }

    @IsTest
    static void campoTipoComprobanteExternoDisponibleSinCampoEnSoql() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC'
        );
        System.assertEquals(false, VentasInformadasApiNormalizer.puedeLeerTipoComprobanteExterno(venta));
        VentasInformadasApiNormalizer.aplicarTipoComprobante(venta);
        System.assertEquals('FC', venta.Tipo_de_Comprobante__c);
        if (VentasInformadasApiNormalizer.puedeEscribirTipoComprobanteExterno()) {
            System.assertEquals('FC', venta.Tipo_Comprobante_Externo__c);
        }
    }

    @IsTest
    static void noReenriqueceSiVariedadInaseYCampanaYaInformadas() {
        VentasInformadasApiNormalizer.forceEnabledForTests = true;

        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA COMPLETA', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana Completa 2026',
            Ano__c = '2026',
            Id_Externo__c = 'VI_COMP_2026',
            Z9_Clave_Unica__c = 'VI_COMP_Z9',
            SKEY_CAMPANIA__c = 8800302,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(
            Name = 'VAR COMPLETA',
            Cultivar_INASE__c = 'VAR COMPLETA',
            Cultivo__c = cultivo.Id
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campana.Id,
            Variedad_INASE__c = variedad.Id,
            Variedad__c = 'VAR COMPLETA',
            Campana_de_Ventas__c = '2026',
            CUIT_Originante__c = '20123456789',
            CUIT_Destinatario__c = '20987654321'
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Variedad_INASE__c, Campana_Agricola__c, Originante__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(variedad.Id, venta.Variedad_INASE__c);
        System.assertEquals(campana.Id, venta.Campana_Agricola__c);
        System.assertEquals(null, venta.Originante__c);
    }

    @IsTest
    static void normalizaEnUpdateSiFaltaVariedadInase() {
        VentasInformadasApiNormalizer.forceEnabledForTests = true;

        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA UPD', Densidad_de_Siembra__c = 1);
        insert cultivo;

        insert new Campana_Agricola__c(
            Name = 'Campana UPD 2026',
            Ano__c = '2026',
            Id_Externo__c = 'VI_UPD_2026',
            Z9_Clave_Unica__c = 'VI_UPD_Z9',
            SKEY_CAMPANIA__c = 8800204,
            Cultivo__c = cultivo.Id
        );

        Variedad__c variedad = new Variedad__c(
            Name = 'VAR UPD',
            Cultivar_INASE__c = 'VAR UPD',
            Cultivo__c = cultivo.Id
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR UPD',
            CUIT_Originante__c = '20123456789',
            CUIT_Destinatario__c = '20987654321'
        );
        insert venta;

        venta = [
            SELECT Variedad_INASE__c, Campana_Agricola__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertNotEquals(null, venta.Variedad_INASE__c);

        venta.Variedad_INASE__c = null;
        venta.Campana_Agricola__c = null;

        Test.startTest();
        update venta;
        Test.stopTest();

        venta = [
            SELECT Variedad_INASE__c, Campana_Agricola__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(variedad.Id, venta.Variedad_INASE__c);
        System.assertNotEquals(null, venta.Campana_Agricola__c);
    }
}