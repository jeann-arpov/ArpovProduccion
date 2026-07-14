@IsTest
private class VentasInformadasTriggerHandlerTest {

    @IsTest
    static void rellenaNombreCultivoDesdeCampanaOnInsert() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'TRIGO',
            Densidad_de_Siembra__c = 1
        );
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana Trigger VI',
            Ano__c = '2026',
            Id_Externo__c = 'VI_TRIG_001',
            Z9_Clave_Unica__c = 'VI_TRIG_Z9',
            SKEY_CAMPANIA__c = 8800099,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campana.Id,
            CUIT_Originante__c = '20123456789',
            CUIT_Destinatario__c = '20987654321'
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Cultivo_campa_a__c, Cultivo__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('TRIGO', venta.Cultivo_campa_a__c);
        System.assertEquals(cultivo.Id, venta.Cultivo__c);
    }

    @IsTest
    static void limpiaNombreCultivoSiQuitaCampana() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana Trigger VI 2',
            Ano__c = '2026',
            Id_Externo__c = 'VI_TRIG_002',
            Z9_Clave_Unica__c = 'VI_TRIG_Z9_2',
            SKEY_CAMPANIA__c = 8800100,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campana.Id,
            CUIT_Originante__c = '20123456780',
            CUIT_Destinatario__c = '20987654320'
        );
        insert venta;

        venta.Campana_Agricola__c = null;
        Test.startTest();
        update venta;
        Test.stopTest();

        venta = [
            SELECT Cultivo_campa_a__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(null, venta.Cultivo_campa_a__c);
    }

    @IsTest
    static void persisteVariedadInaseOnInsert() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = new Cultivo__c(Name = 'MAIZ TEST SYNC', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana MAIZ SYNC',
            Ano__c = '2026',
            Id_Externo__c = 'VI_MAI_SYNC',
            Z9_Clave_Unica__c = 'VI_MAI_Z9_SYNC',
            SKEY_CAMPANIA__c = 8800098,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(Name = 'Variedad Sync', Cultivo__c = cultivo.Id);
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campana.Id,
            Variedad_INASE__c = variedad.Id,
            CUIT_Originante__c = '20111111111',
            CUIT_Destinatario__c = '20222222222'
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Variedad_INASE__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(variedad.Id, venta.Variedad_INASE__c);
    }

    @IsTest
    static void sincronizaCategoriaPortalConTexto() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Categoria_Portal__c = 'Pre Básica',
            CUIT_Originante__c = '20333333333',
            CUIT_Destinatario__c = '20444444444'
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [SELECT Categoria_Portal__c, Categoria__c FROM Ventas_Informadas__c WHERE Id = :venta.Id];
        System.assertEquals('Pre Básica', venta.Categoria_Portal__c);
        System.assertEquals('Pre Básica', venta.Categoria__c);
    }

    @IsTest
    static void rechazaVariedadDeOtroCultivoAlInsertar() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivoCampana = new Cultivo__c(Name = 'TRIGO VI', Densidad_de_Siembra__c = 1);
        Cultivo__c cultivoVariedad = new Cultivo__c(Name = 'SOJA VI', Densidad_de_Siembra__c = 1);
        insert new List<Cultivo__c>{ cultivoCampana, cultivoVariedad };

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana TRIGO VI',
            Ano__c = '2026',
            Id_Externo__c = 'VI_TRIG_003',
            Z9_Clave_Unica__c = 'VI_TRIG_Z9_3',
            SKEY_CAMPANIA__c = 8800101,
            Cultivo__c = cultivoCampana.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(
            Name = 'Variedad SOJA',
            Cultivo__c = cultivoVariedad.Id,
            Cultivar_INASE__c = 'SOJA-VI-1'
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campana.Id,
            Variedad_INASE__c = variedad.Id,
            CUIT_Originante__c = '20123456781',
            CUIT_Destinatario__c = '20987654322'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(venta, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Debe fallar por cultivo incompatible');
        System.assert(
            sr.getErrors()[0].getMessage().contains('no corresponde al cultivo'),
            'Mensaje de cultivo: ' + sr.getErrors()[0].getMessage()
        );
    }

    @IsTest
    static void rechazaCambioCampanaIncompatibleEnUpdate() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivoTrig = new Cultivo__c(Name = 'TRIGO VI2', Densidad_de_Siembra__c = 1);
        Cultivo__c cultivoSoj = new Cultivo__c(Name = 'SOJA VI2', Densidad_de_Siembra__c = 1);
        insert new List<Cultivo__c>{ cultivoTrig, cultivoSoj };

        Campana_Agricola__c campanaSoja = new Campana_Agricola__c(
            Name = 'Campana SOJA VI2',
            Ano__c = '2026',
            Id_Externo__c = 'VI_SOJ_001',
            Z9_Clave_Unica__c = 'VI_SOJ_Z9',
            SKEY_CAMPANIA__c = 8800102,
            Cultivo__c = cultivoSoj.Id
        );
        Campana_Agricola__c campanaTrigo = new Campana_Agricola__c(
            Name = 'Campana TRIGO VI2',
            Ano__c = '2026',
            Id_Externo__c = 'VI_TRI_001',
            Z9_Clave_Unica__c = 'VI_TRI_Z9',
            SKEY_CAMPANIA__c = 8800103,
            Cultivo__c = cultivoTrig.Id
        );
        insert new List<Campana_Agricola__c>{ campanaSoja, campanaTrigo };

        Variedad__c variedad = new Variedad__c(
            Name = 'Var SOJA ok',
            Cultivo__c = cultivoSoj.Id,
            Cultivar_INASE__c = 'SOJA-VI-2'
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campanaSoja.Id,
            Variedad_INASE__c = variedad.Id,
            CUIT_Originante__c = '20123456782',
            CUIT_Destinatario__c = '20987654323'
        );
        insert venta;

        venta.Campana_Agricola__c = campanaTrigo.Id;

        Test.startTest();
        Database.SaveResult sr = Database.update(venta, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess());
        System.assert(sr.getErrors()[0].getMessage().contains('no corresponde al cultivo'));
    }

    @IsTest
    static void limpiaProductoSiQuitaCategoria() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'MAIZ PROD VI',
            Densidad_de_Siembra__c = 1,
            Unidad_de_Medida_Por_Defecto__c = '40'
        );
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana MAIZ VI',
            Ano__c = '2026',
            Id_Externo__c = 'VI_MAI_001',
            Z9_Clave_Unica__c = 'VI_MAI_Z9',
            SKEY_CAMPANIA__c = 8800104,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(
            Name = 'Var MAIZ',
            Cultivo__c = cultivo.Id,
            Cultivar_INASE__c = 'MAIZ-VI-PROD'
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campana.Id,
            Variedad_INASE__c = variedad.Id,
            Categoria_Portal__c = 'Pre Básica',
            CUIT_Originante__c = '20123456783',
            CUIT_Destinatario__c = '20987654324'
        );
        insert venta;
        venta = [
            SELECT Producto__c, Variedad__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('MAIZ-VI-PROD', venta.Variedad__c);

        venta.Categoria_Portal__c = null;

        Test.startTest();
        update venta;
        Test.stopTest();

        venta = [
            SELECT Producto__c, Categoria__c, Categoria_Portal__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(null, venta.Producto__c);
        System.assertEquals(null, venta.Categoria__c);
    }

    @IsTest
    static void sincronizaCategoriaPortalYRecalculaProductoAlCambiarCampana() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = new Cultivo__c(Name = 'TRIGO CAT VI', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'Campana TRIGO CAT',
            Ano__c = '2026',
            Id_Externo__c = 'VI_CAT_001',
            Z9_Clave_Unica__c = 'VI_CAT_Z9',
            SKEY_CAMPANIA__c = 8800105,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(
            Name = 'Var TRIGO CAT',
            Cultivo__c = cultivo.Id,
            Cultivar_INASE__c = 'TRIGO-CAT-VI'
        );
        insert variedad;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_Agricola__c = campana.Id,
            Variedad_INASE__c = variedad.Id,
            Categoria_Portal__c = 'Pre Básica',
            CUIT_Originante__c = '20123456784',
            CUIT_Destinatario__c = '20987654325'
        );
        insert venta;

        venta = [
            SELECT Categoria__c, Categoria_Portal__c, Cultivo__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('Pre Básica', venta.Categoria__c);
        System.assertEquals('Pre Básica', venta.Categoria_Portal__c);
        System.assertEquals(cultivo.Id, venta.Cultivo__c);

        venta.Categoria_Portal__c = 'Primera Multiplicación';

        Test.startTest();
        update venta;
        Test.stopTest();

        venta = [
            SELECT Categoria__c, Categoria_Portal__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('Primera Multiplicación', venta.Categoria__c);
        System.assertEquals('Primera Multiplicación', venta.Categoria_Portal__c);
    }

    @IsTest
    static void normalizaOriginalYFundadoraACanonica() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c ventaOriginal = new Ventas_Informadas__c(
            Categoria__c = 'Original',
            CUIT_Originante__c = '20111111111',
            CUIT_Destinatario__c = '20222222222'
        );
        Ventas_Informadas__c ventaFundadora = new Ventas_Informadas__c(
            Categoria__c = 'Fundadora',
            CUIT_Originante__c = '20333333333',
            CUIT_Destinatario__c = '20444444444'
        );
        Ventas_Informadas__c ventaOrigina = new Ventas_Informadas__c(
            Categoria__c = 'Origina',
            CUIT_Originante__c = '20555555555',
            CUIT_Destinatario__c = '20666666666'
        );

        Test.startTest();
        insert new List<Ventas_Informadas__c>{ ventaOriginal, ventaFundadora, ventaOrigina };
        Test.stopTest();

        Map<Id, Ventas_Informadas__c> ventas = new Map<Id, Ventas_Informadas__c>([
            SELECT Categoria__c, Categoria_Portal__c
            FROM Ventas_Informadas__c
            WHERE Id IN :new Set<Id>{ ventaOriginal.Id, ventaFundadora.Id, ventaOrigina.Id }
        ]);

        for (Ventas_Informadas__c v : ventas.values()) {
            System.assertEquals('Original o Fundadora', v.Categoria__c);
            System.assertEquals('Original o Fundadora', v.Categoria_Portal__c);
        }
    }

    @IsTest
    static void seteaRolDestinatarioDesdeLookupAlInsertar() {
        Test_TestUtils.disableFlows();

        Id rtProd = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Productor')
            .getRecordTypeId();
        Account destinatario = new Account(
            Name = 'ALBORNOZ NESTOR EMILIO',
            N_CUIT__c = '23202099319',
            Type = 'Productor',
            RecordTypeId = rtProd
        );
        insert destinatario;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '33674838609',
            CUIT_Destinatario__c = '23202099319',
            Destinatario__c = destinatario.Id,
            Categoria_Portal__c = 'Primera Multiplicación',
            Variedad__c = 'PEHUEN',
            Cantidad_de_Bolsas__c = 100
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Rol_Destinatario__c, Destinatario__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(destinatario.Id, venta.Destinatario__c);
        System.assertEquals('Productor', venta.Rol_Destinatario__c);
    }

    @IsTest
    static void insertConSoloCuitDestinatarioResuelveLookupYRol() {
        Test_TestUtils.disableFlows();

        Id rtProd = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Productor')
            .getRecordTypeId();
        Account destinatario = new Account(
            Name = 'DEST TRIGGER CUIT',
            N_CUIT__c = '23202099319',
            Type = 'Productor',
            RecordTypeId = rtProd
        );
        insert destinatario;

        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA VI CUIT', Densidad_de_Siembra__c = 1);
        insert cultivo;
        insert new Variedad__c(Cultivar_Inase__c = 'VI CUIT VAR', Cultivo__c = cultivo.Id);

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Destinatario__c = destinatario.N_CUIT__c,
            Variedad__c = 'VI CUIT VAR',
            Cantidad_de_Bolsas__c = 100,
            Categoria__c = 'Primera Multiplicación'
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Destinatario__c, Rol_Destinatario__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(destinatario.Id, venta.Destinatario__c);
        System.assertNotEquals(null, venta.Rol_Destinatario__c);
    }

    @IsTest
    static void autoventaPreBasicaMismoCuitQuedaPendienteValidarAlInsertar() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Categoria__c = 'Pre Básica',
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907'
        );

        Test.startTest();
        insert venta;
        Test.stopTest();

        venta = [
            SELECT Estado__c, Resultado__c, Venta_Interna__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals(true, venta.Venta_Interna__c);
        System.assertEquals(VentasInformadasExclusionUtil.ESTADO_PENDIENTE, venta.Estado__c);
        System.assertEquals(VentasInformadasExclusionUtil.MSG_PENDIENTE_VALIDAR, venta.Resultado__c);
    }

    @IsTest
    static void sincronizaExternoFcCuandoInternoPasaAnc() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20123456789',
            CUIT_Destinatario__c = '20987654321',
            Tipo_Comprobante_Externo__c = 'FC',
            Tipo_de_Comprobante__c = 'FC'
        );
        insert venta;

        venta.Tipo_de_Comprobante__c = 'NC';
        Test.startTest();
        update venta;
        Test.stopTest();

        venta = [
            SELECT Tipo_Comprobante_Externo__c, Tipo_de_Comprobante__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('NC', venta.Tipo_Comprobante_Externo__c);
        System.assertEquals('NC', venta.Tipo_de_Comprobante__c);
    }

    @IsTest
    static void sincronizaExternoRemitoCuandoInternoPasaAnc() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20123456780',
            CUIT_Destinatario__c = '20987654320',
            Tipo_Comprobante_Externo__c = 'Remito',
            Tipo_de_Comprobante__c = 'FC'
        );
        insert venta;

        venta.Tipo_de_Comprobante__c = 'NC';
        Test.startTest();
        update venta;
        Test.stopTest();

        venta = [
            SELECT Tipo_Comprobante_Externo__c, Tipo_de_Comprobante__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('Remito de Devolución', venta.Tipo_Comprobante_Externo__c);
        System.assertEquals('NC', venta.Tipo_de_Comprobante__c);
    }

    @IsTest
    static void sincronizaExternoNcCuandoInternoPasaAfc() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20123456781',
            CUIT_Destinatario__c = '20987654319',
            Tipo_Comprobante_Externo__c = 'NC',
            Tipo_de_Comprobante__c = 'NC'
        );
        insert venta;

        venta.Tipo_de_Comprobante__c = 'FC';
        Test.startTest();
        update venta;
        Test.stopTest();

        venta = [
            SELECT Tipo_Comprobante_Externo__c, Tipo_de_Comprobante__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('FC', venta.Tipo_Comprobante_Externo__c);
        System.assertEquals('FC', venta.Tipo_de_Comprobante__c);
    }

    @IsTest
    static void sincronizaExternoRemitoDevolucionCuandoInternoPasaAfc() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20123456782',
            CUIT_Destinatario__c = '20987654318',
            Tipo_Comprobante_Externo__c = 'Remito de Devolución',
            Tipo_de_Comprobante__c = 'NC'
        );
        insert venta;

        venta.Tipo_de_Comprobante__c = 'FC';
        Test.startTest();
        update venta;
        Test.stopTest();

        venta = [
            SELECT Tipo_Comprobante_Externo__c, Tipo_de_Comprobante__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('Remito', venta.Tipo_Comprobante_Externo__c);
        System.assertEquals('FC', venta.Tipo_de_Comprobante__c);
    }

    @IsTest
    static void sincronizaInternoCuandoCambiaSoloExterno() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20123456783',
            CUIT_Destinatario__c = '20987654317',
            Tipo_Comprobante_Externo__c = 'Remito',
            Tipo_de_Comprobante__c = 'FC'
        );
        insert venta;

        venta.Tipo_Comprobante_Externo__c = 'Remito de Devolución';
        Test.startTest();
        update venta;
        Test.stopTest();

        venta = [
            SELECT Tipo_Comprobante_Externo__c, Tipo_de_Comprobante__c
            FROM Ventas_Informadas__c
            WHERE Id = :venta.Id
        ];
        System.assertEquals('Remito de Devolución', venta.Tipo_Comprobante_Externo__c);
        System.assertEquals('NC', venta.Tipo_de_Comprobante__c);
    }
}