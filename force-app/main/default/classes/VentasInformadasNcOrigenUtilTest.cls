@IsTest
private class VentasInformadasNcOrigenUtilTest {

    @IsTest
    static void aplicaFcOrigenCuandoHayMatchYKilosOk() {
        Ventas_Informadas__c fc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20111111112',
            CUIT_Destinatario__c = '20222222223',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-TEST-NC',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 100
        );
        insert fc;

        Ventas_Informadas__c nc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20-11111111-2',
            CUIT_Destinatario__c = '20222222223',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-TEST-NC',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 40
        );

        Test.startTest();
        VentasInformadasNcOrigenUtil.aplicar(new List<Ventas_Informadas__c>{ nc, fc });
        Test.stopTest();

        System.assertEquals(fc.Id, nc.FC_Origen__c, 'Debe vincular la FC de origen');
        System.assertEquals(
            false,
            VentasInformadasNcOrigenUtil.esNcSinOrigen(nc),
            'No debe marcar NC sin Origen'
        );
        System.assertEquals('OK', nc.Resultado__c, 'Con FC Origen el trigger debe dejar Resultado OK');
    }

    @IsTest
    static void marcaNcSinOrigenSiNoHayFc() {
        Ventas_Informadas__c nc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20111111112',
            CUIT_Destinatario__c = '20222222223',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-SIN-FC',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 40
        );

        VentasInformadasNcOrigenUtil.aplicar(new List<Ventas_Informadas__c>{ nc });

        System.assertEquals(null, nc.FC_Origen__c);
        System.assertEquals(VentasInformadasNcOrigenUtil.MSG_NC_SIN_ORIGEN, nc.Resultado__c);
        System.assertEquals(true, VentasInformadasNcOrigenUtil.esNcSinOrigen(nc));
    }

    @IsTest
    static void marcaNcSinOrigenSiKilosNcMayoresQueFc() {
        Ventas_Informadas__c fc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Preprocesado',
            CUIT_Originante__c = '20111111112',
            CUIT_Destinatario__c = '20222222223',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-TEST-KG',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 30
        );
        insert fc;

        Ventas_Informadas__c nc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            CUIT_Originante__c = '20111111112',
            CUIT_Destinatario__c = '20222222223',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-TEST-KG',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = -50
        );

        VentasInformadasNcOrigenUtil.aplicar(new List<Ventas_Informadas__c>{ nc });

        System.assertEquals(null, nc.FC_Origen__c);
        System.assertEquals(true, VentasInformadasNcOrigenUtil.esNcSinOrigen(nc));
    }

    @IsTest
    static void esElegibleParaConvertirExigeFcOrigenEnNc() {
        Ventas_Informadas__c fcOrigen = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Procesado',
            CUIT_Originante__c = '20555555556',
            CUIT_Destinatario__c = '20666666667',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-ELEGIBLE',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 100
        );
        insert fcOrigen;

        Ventas_Informadas__c ncOk = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Preprocesado',
            Resultado__c = 'OK',
            FC_Origen__c = fcOrigen.Id
        );
        Ventas_Informadas__c ncSin = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Preprocesado',
            Resultado__c = 'OK',
            FC_Origen__c = null
        );
        Ventas_Informadas__c fc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Preprocesado',
            Resultado__c = 'OK'
        );

        System.assertEquals(true, ConvertirVentasInformadasResumenUtil.esElegibleParaConvertir(ncOk));
        System.assertEquals(false, ConvertirVentasInformadasResumenUtil.esElegibleParaConvertir(ncSin));
        System.assertEquals(true, ConvertirVentasInformadasResumenUtil.esElegibleParaConvertir(fc));
    }

    @IsTest
    static void mismaCantidadNcYFcVincula() {
        Ventas_Informadas__c fc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Preprocesado',
            CUIT_Originante__c = '20777777778',
            CUIT_Destinatario__c = '20888888889',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-IGUAL-KG',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 100
        );
        insert fc;

        Ventas_Informadas__c nc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Preprocesado',
            Resultado__c = VentasInformadasNcOrigenUtil.MSG_NC_SIN_ORIGEN,
            CUIT_Originante__c = '20777777778',
            CUIT_Destinatario__c = '20888888889',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-IGUAL-KG',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 100
        );

        VentasInformadasNcOrigenUtil.aplicar(new List<Ventas_Informadas__c>{ nc });

        System.assertEquals(fc.Id, nc.FC_Origen__c, 'NC con mismos kilos que FC debe vincular');
        System.assertEquals(false, VentasInformadasNcOrigenUtil.esNcSinOrigen(nc));
        System.assertEquals('OK', nc.Resultado__c, 'Tras vincular debe limpiar NC sin Origen y dejar OK');
    }

    @IsTest
    static void fcPosteriorReenlazaNcHuerfana() {
        Ventas_Informadas__c nc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Preprocesado',
            Resultado__c = VentasInformadasNcOrigenUtil.MSG_NC_SIN_ORIGEN,
            CUIT_Originante__c = '20999999990',
            CUIT_Destinatario__c = '20101010101',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-FC-DESPUES',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 50,
            Cantidad_Bolsas_40__c = 2
        );
        insert nc;

        System.assertEquals(null, [
            SELECT FC_Origen__c FROM Ventas_Informadas__c WHERE Id = :nc.Id
        ].FC_Origen__c);

        // Bypass: probar reenlace del util sin after-insert del trigger.
        TriggerHandler.bypass('VentasInformadasTriggerHandler');
        Ventas_Informadas__c fc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20999999990',
            CUIT_Destinatario__c = '20101010101',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-FC-DESPUES',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 50
        );
        insert fc;
        TriggerHandler.clearBypass('VentasInformadasTriggerHandler');

        List<Ventas_Informadas__c> reenlazadas =
            VentasInformadasNcOrigenUtil.reenlazarNcsHuerfanas(
                new List<Ventas_Informadas__c>{ fc },
                null
            );
        System.assertEquals(1, reenlazadas.size(), 'Debe reenlazar la NC previa');
        System.assertEquals(fc.Id, reenlazadas[0].FC_Origen__c);
        update reenlazadas;

        nc = [
            SELECT FC_Origen__c, Resultado__c
            FROM Ventas_Informadas__c
            WHERE Id = :nc.Id
        ];
        System.assertEquals(fc.Id, nc.FC_Origen__c);
        System.assertEquals('OK', nc.Resultado__c);
    }

    @IsTest
    static void sumaVariasFcProcesadasCubreNc() {
        // Escenario: NC 1600 sin FC; luego 2 FC de 800 ya convertidas (Procesado).
        Ventas_Informadas__c nc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Preprocesado',
            Resultado__c = VentasInformadasNcOrigenUtil.MSG_NC_SIN_ORIGEN,
            CUIT_Originante__c = '20303030303',
            CUIT_Destinatario__c = '20404040404',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-SUMA-FC',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = -1600,
            Cantidad_Bolsas_40__c = 40
        );
        insert nc;

        Ventas_Informadas__c fc1 = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Procesado',
            CUIT_Originante__c = '20303030303',
            CUIT_Destinatario__c = '20404040404',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-SUMA-FC',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 800
        );
        Ventas_Informadas__c fc2 = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Procesado',
            CUIT_Originante__c = '20303030303',
            CUIT_Destinatario__c = '20404040404',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-SUMA-FC',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 800
        );
        insert new List<Ventas_Informadas__c>{ fc1, fc2 };

        Test.startTest();
        Ventas_Informadas__c ncMem = [
            SELECT
                Id,
                Tipo_de_Comprobante__c,
                Estado__c,
                Resultado__c,
                FC_Origen__c,
                CUIT_Originante__c,
                CUIT_Destinatario__c,
                Campana_de_Ventas__c,
                Campana_Agricola__c,
                Variedad__c,
                Categoria__c,
                Categoria_Portal__c,
                Cantidad_de_Bolsas__c,
                Cantidad_Bolsas_40__c
            FROM Ventas_Informadas__c
            WHERE Id = :nc.Id
        ];
        VentasInformadasNcOrigenUtil.aplicar(new List<Ventas_Informadas__c>{ ncMem });
        Test.stopTest();

        System.assertEquals(
            false,
            VentasInformadasNcOrigenUtil.esNcSinOrigen(ncMem),
            'Suma de 2 FC Procesado de 800 debe cubrir NC 1600'
        );
        System.assertNotEquals(null, ncMem.FC_Origen__c, 'Debe setear FC_Origen principal');
        System.assert(
            ncMem.FC_Origen__c == fc1.Id || ncMem.FC_Origen__c == fc2.Id,
            'FC_Origen debe ser una de las FC que aportan'
        );
    }

    @IsTest
    static void reenlaceConVariasFcProcesadasCubreNc() {
        Ventas_Informadas__c nc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Pendiente',
            Resultado__c = VentasInformadasNcOrigenUtil.MSG_NC_SIN_ORIGEN,
            CUIT_Originante__c = '20505050505',
            CUIT_Destinatario__c = '20606060606',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-REENLACE-SUMA',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 1600,
            Cantidad_Bolsas_40__c = 40
        );
        insert nc;

        TriggerHandler.bypass('VentasInformadasTriggerHandler');
        Ventas_Informadas__c fc1 = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Procesado',
            CUIT_Originante__c = '20505050505',
            CUIT_Destinatario__c = '20606060606',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-REENLACE-SUMA',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 800
        );
        Ventas_Informadas__c fc2 = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Procesado',
            CUIT_Originante__c = '20505050505',
            CUIT_Destinatario__c = '20606060606',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-REENLACE-SUMA',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 800
        );
        insert new List<Ventas_Informadas__c>{ fc1, fc2 };
        TriggerHandler.clearBypass('VentasInformadasTriggerHandler');

        List<Ventas_Informadas__c> reenlazadas =
            VentasInformadasNcOrigenUtil.reenlazarNcsHuerfanas(
                new List<Ventas_Informadas__c>{ fc1, fc2 },
                null
            );
        System.assertEquals(1, reenlazadas.size());
        System.assertNotEquals(null, reenlazadas[0].FC_Origen__c);
        System.assertEquals(false, VentasInformadasNcOrigenUtil.esNcSinOrigen(reenlazadas[0]));
    }

    /**
     * Caso real: NC 1600 primero (sin origen), luego 2 FC de 800.
     * El after insert del trigger debe reenlazar y quitar "NC sin Origen".
     */
    @IsTest
    static void triggerAfterInsertFcReenlazaNcConSumaDeKilos() {
        Ventas_Informadas__c nc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20707070707',
            CUIT_Destinatario__c = '20808080808',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-TRIGGER-SUMA',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 1600,
            Cantidad_Bolsas_40__c = 40
        );
        insert nc;

        nc = [
            SELECT FC_Origen__c, Resultado__c
            FROM Ventas_Informadas__c
            WHERE Id = :nc.Id
        ];
        System.assertEquals(null, nc.FC_Origen__c);
        System.assertEquals(true, VentasInformadasNcOrigenUtil.esNcSinOrigen(nc));

        Test.startTest();
        insert new List<Ventas_Informadas__c>{
            new Ventas_Informadas__c(
                Tipo_de_Comprobante__c = 'FC',
                Estado__c = 'Pendiente',
                CUIT_Originante__c = '20707070707',
                CUIT_Destinatario__c = '20808080808',
                Campana_de_Ventas__c = '2026',
                Variedad__c = 'VAR-TRIGGER-SUMA',
                Categoria__c = 'Primera Multiplicación',
                Cantidad_de_Bolsas__c = 800
            ),
            new Ventas_Informadas__c(
                Tipo_de_Comprobante__c = 'FC',
                Estado__c = 'Pendiente',
                CUIT_Originante__c = '20707070707',
                CUIT_Destinatario__c = '20808080808',
                Campana_de_Ventas__c = '2026',
                Variedad__c = 'VAR-TRIGGER-SUMA',
                Categoria__c = 'Primera Multiplicación',
                Cantidad_de_Bolsas__c = 800
            )
        };
        Test.stopTest();

        nc = [
            SELECT FC_Origen__c, Resultado__c
            FROM Ventas_Informadas__c
            WHERE Id = :nc.Id
        ];
        System.assertNotEquals(
            null,
            nc.FC_Origen__c,
            'After insert de las FC debe setear FC_Origen vía trigger'
        );
        System.assertEquals(
            false,
            VentasInformadasNcOrigenUtil.esNcSinOrigen(nc),
            'Con 1600 kg en FC no debe quedar NC sin Origen'
        );
    }

    @IsTest
    static void variantesCuitIncluyeFormatoConGuiones() {
        Set<String> variants = VentasInformadasNcOrigenUtil.variantesCuit(
            new Set<String>{ '30708500921' }
        );
        System.assert(variants.contains('30708500921'));
        System.assert(variants.contains('30-70850092-1'));
    }

    @IsTest
    static void mismaEjecucionRechazaLaNcQueSuperaElSaldo() {
        Ventas_Informadas__c fc = venta('FC', 'VAR-MISMA-EJEC', 100);
        insert fc;

        Ventas_Informadas__c nc50 = venta('NC', 'VAR-MISMA-EJEC', 50);
        Ventas_Informadas__c nc30 = venta('NC', 'VAR-MISMA-EJEC', 30);
        Ventas_Informadas__c nc40 = venta('NC', 'VAR-MISMA-EJEC', 40);

        VentasInformadasNcOrigenUtil.aplicar(
            new List<Ventas_Informadas__c>{ nc50, nc30, nc40 }
        );

        System.assertEquals(fc.Id, nc50.FC_Origen__c);
        System.assertEquals(fc.Id, nc30.FC_Origen__c);
        System.assertEquals(null, nc40.FC_Origen__c, 'La tercera NC supera el saldo que dejaron las dos primeras');
        System.assertEquals(true, VentasInformadasNcOrigenUtil.esNcSinOrigen(nc40));
    }

    @IsTest
    static void cargasSeparadasNoReutilizanKilosYaTomados() {
        Ventas_Informadas__c fc = venta('FC', 'VAR-CARGAS-SEP', 100);
        insert fc;

        Ventas_Informadas__c nc60 = venta('NC', 'VAR-CARGAS-SEP', 60);
        insert nc60;
        Ventas_Informadas__c nc40 = venta('NC', 'VAR-CARGAS-SEP', 40);
        insert nc40;
        Ventas_Informadas__c nc25 = venta('NC', 'VAR-CARGAS-SEP', 25);
        insert nc25;

        Map<Id, Ventas_Informadas__c> guardadas = new Map<Id, Ventas_Informadas__c>([
            SELECT FC_Origen__c, Resultado__c
            FROM Ventas_Informadas__c
            WHERE Id IN :new Set<Id>{ nc60.Id, nc40.Id, nc25.Id }
        ]);
        System.assertEquals(fc.Id, guardadas.get(nc60.Id).FC_Origen__c);
        System.assertEquals(fc.Id, guardadas.get(nc40.Id).FC_Origen__c, '40 entra en el saldo que queda');
        System.assertEquals(
            null,
            guardadas.get(nc25.Id).FC_Origen__c,
            'Una carga posterior no puede volver a usar los kilos de la FC'
        );
        System.assertEquals(
            true,
            VentasInformadasNcOrigenUtil.esNcSinOrigen(guardadas.get(nc25.Id))
        );

        List<Ventas_Informadas__c> reenlazadas =
            VentasInformadasNcOrigenUtil.reenlazarNcsHuerfanas(
                new List<Ventas_Informadas__c>{ fc },
                null
            );
        System.assertEquals(0, reenlazadas.size(), 'El reenlace tampoco debe cubrir la NC con saldo ya tomado');
    }

    @IsTest
    static void ncNegativaTambienConsumeElSaldo() {
        Ventas_Informadas__c fc = venta('FC', 'VAR-NC-NEG', 100);
        insert fc;

        insert venta('NC', 'VAR-NC-NEG', -70);
        Ventas_Informadas__c nc40 = venta('NC', 'VAR-NC-NEG', 40);
        insert nc40;

        nc40 = [
            SELECT FC_Origen__c, Resultado__c
            FROM Ventas_Informadas__c
            WHERE Id = :nc40.Id
        ];
        System.assertEquals(null, nc40.FC_Origen__c);
        System.assertEquals(true, VentasInformadasNcOrigenUtil.esNcSinOrigen(nc40));
    }

    @IsTest
    static void saldoRestaNcCubiertaPorVariasFc() {
        Ventas_Informadas__c fc1 = venta('FC', 'VAR-VARIAS-FC', 800);
        insert fc1;
        Ventas_Informadas__c fc2 = venta('FC', 'VAR-VARIAS-FC', 800);
        insert fc2;

        Ventas_Informadas__c nc1600 = venta('NC', 'VAR-VARIAS-FC', 1600);
        insert nc1600;
        nc1600 = [
            SELECT FC_Origen__c
            FROM Ventas_Informadas__c
            WHERE Id = :nc1600.Id
        ];
        System.assertNotEquals(null, nc1600.FC_Origen__c, '1600 se cubre con las dos FC de 800');

        Ventas_Informadas__c nc100 = venta('NC', 'VAR-VARIAS-FC', 100);
        insert nc100;
        nc100 = [
            SELECT FC_Origen__c, Resultado__c
            FROM Ventas_Informadas__c
            WHERE Id = :nc100.Id
        ];
        System.assertEquals(
            null,
            nc100.FC_Origen__c,
            'La segunda NC no puede usar de nuevo los kilos ya repartidos entre las FC'
        );
        System.assertEquals(true, VentasInformadasNcOrigenUtil.esNcSinOrigen(nc100));
    }

    /**
     * Incidente 3665: la FC legacy guarda bolsas en Kilos Totales (30 y 30)
     * y la NC nueva guarda kilos (400 kg = 10 bolsas de 40 kg).
     */
    @IsTest
    static void fcLegacyEnBolsasCubreNcEnKilos() {
        Product2 producto = productoUnidad40();
        Ventas_Informadas__c fc = insertFcConProducto(producto.Id, 30, 30);

        Ventas_Informadas__c nc = ncContra(producto.Id, 400, 10);

        VentasInformadasNcOrigenUtil.aplicar(new List<Ventas_Informadas__c>{ nc });

        System.assertEquals(
            fc.Id,
            nc.FC_Origen__c,
            '30 bolsas legacy equivalen a 1200 kg y cubren la NC de 400 kg'
        );
        System.assertEquals('OK', nc.Resultado__c);
    }

    @IsTest
    static void fcEnKilosRealesNoSeInflaPorLaUnidad() {
        Product2 producto = productoUnidad40();
        insertFcConProducto(producto.Id, 30, 1);

        Ventas_Informadas__c nc = ncContra(producto.Id, 400, 10);

        VentasInformadasNcOrigenUtil.aplicar(new List<Ventas_Informadas__c>{ nc });

        System.assertEquals(
            null,
            nc.FC_Origen__c,
            '30 kg reales (1 bolsa) no alcanzan para una NC de 400 kg'
        );
        System.assertEquals(true, VentasInformadasNcOrigenUtil.esNcSinOrigen(nc));
    }

    private static Product2 productoUnidad40() {
        Test_TestUtils.disableFlows();
        Account obtentor = Test_TestUtils.crearObtentor();
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 1);
        Product2 producto = Test_TestUtils.crearProducto(
            true,
            'Prod NC Origen 3665',
            '3665',
            'VAR-3665',
            cultivo,
            'Semilla Fiscalizada',
            1,
            obtentor
        );
        producto.Unidad_de_Medida__c = '40';
        update producto;
        return producto;
    }

    private static Ventas_Informadas__c insertFcConProducto(Id productoId, Decimal kilos, Decimal bolsas) {
        Ventas_Informadas__c fc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Procesado',
            CUIT_Originante__c = '30613985995',
            CUIT_Destinatario__c = '20129235005',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-3665',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = kilos,
            Cantidad_Bolsas_40__c = bolsas,
            Kilos_por_Bolsa__c = 1
        );
        insert fc;
        fc.Producto__c = productoId;
        update fc;
        return fc;
    }

    private static Ventas_Informadas__c ncContra(Id productoId, Decimal kilos, Decimal bolsas) {
        return new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'NC',
            Estado__c = 'Preprocesado',
            Resultado__c = VentasInformadasNcOrigenUtil.MSG_NC_SIN_ORIGEN,
            CUIT_Originante__c = '30613985995',
            CUIT_Destinatario__c = '20129235005',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-3665',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = kilos,
            Cantidad_Bolsas_40__c = bolsas,
            Kilos_por_Bolsa__c = 1,
            Producto__c = productoId
        );
    }

    private static Ventas_Informadas__c venta(String tipo, String variedad, Decimal kilos) {
        return new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = tipo,
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20333333334',
            CUIT_Destinatario__c = '20444444445',
            Campana_de_Ventas__c = '2026',
            Variedad__c = variedad,
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = kilos,
            Cantidad_Bolsas_40__c = 1
        );
    }
}
