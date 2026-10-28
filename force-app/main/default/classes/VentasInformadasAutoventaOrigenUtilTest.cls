@IsTest
private class VentasInformadasAutoventaOrigenUtilTest {

    @IsTest
    static void marcaAutoventaSinCompraPrevia() {
        Ventas_Informadas__c autoventa = autoventa('VAR-SIN-ORIGEN', '20111111112');

        VentasInformadasAutoventaOrigenUtil.aplicar(
            new List<Ventas_Informadas__c>{ autoventa },
            null
        );

        System.assertEquals(
            VentasInformadasAutoventaOrigenUtil.MSG_AUTOVENTA_SIN_ORIGEN,
            autoventa.Resultado__c
        );
    }

    @IsTest
    static void noMarcaSiLaFcVieneEnElMismoLote() {
        Ventas_Informadas__c fc = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            CUIT_Originante__c = '20999999999',
            CUIT_Destinatario__c = '20111111112',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-CON-FC',
            Categoria__c = 'Primera Multiplicación'
        );
        Ventas_Informadas__c autoventa = autoventa('VAR-CON-FC', '20111111112');
        autoventa.Resultado__c = VentasInformadasAutoventaOrigenUtil.MSG_AUTOVENTA_SIN_ORIGEN;

        VentasInformadasAutoventaOrigenUtil.aplicar(
            new List<Ventas_Informadas__c>{ fc, autoventa },
            null
        );

        System.assertEquals('OK', autoventa.Resultado__c, 'La FC del mismo lote alcanza como origen');
    }

    @IsTest
    static void noMarcaSiYaHayFcInformada() {
        insert new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20999999999',
            CUIT_Destinatario__c = '20111111112',
            Campana_de_Ventas__c = '2026',
            Variedad__c = 'VAR-DB',
            Categoria__c = 'Primera Multiplicación',
            Cantidad_de_Bolsas__c = 80
        );

        Ventas_Informadas__c autoventa = autoventa('VAR-DB', '20111111112');
        autoventa.Resultado__c = 'OK';
        VentasInformadasAutoventaOrigenUtil.aplicar(
            new List<Ventas_Informadas__c>{ autoventa },
            null
        );

        System.assertEquals('OK', autoventa.Resultado__c, 'La FC ya cargada es origen');
    }

    @IsTest
    static void noMarcaVentaATerceros() {
        Ventas_Informadas__c venta = autoventa('VAR-TERCERO', '20111111112');
        venta.Venta_Interna__c = false;
        venta.CUIT_Destinatario__c = '20333333333';
        venta.Resultado__c = 'OK';

        VentasInformadasAutoventaOrigenUtil.aplicar(
            new List<Ventas_Informadas__c>{ venta },
            null
        );

        System.assertEquals('OK', venta.Resultado__c);
    }

    @IsTest
    static void tildarValidarDejaOkSinEditarResultado() {
        Ventas_Informadas__c autoventa = autoventa('VAR-OK', '20111111112');
        autoventa.Id = fakeId();
        autoventa.Resultado__c = VentasInformadasAutoventaOrigenUtil.MSG_AUTOVENTA_SIN_ORIGEN;
        autoventa.Validar_Autoventa__c = true;
        Ventas_Informadas__c oldV = autoventa.clone(true, true, true, true);
        oldV.Validar_Autoventa__c = false;

        VentasInformadasAutoventaOrigenUtil.aplicar(
            new List<Ventas_Informadas__c>{ autoventa },
            new Map<Id, Ventas_Informadas__c>{ autoventa.Id => oldV }
        );

        System.assertEquals('OK', autoventa.Resultado__c);
    }

    @IsTest
    static void escribirOkAManoNoValida() {
        Ventas_Informadas__c autoventa = autoventa('VAR-MANO', '20111111112');
        autoventa.Id = fakeId();
        autoventa.Resultado__c = 'OK';
        autoventa.Validar_Autoventa__c = false;
        Ventas_Informadas__c oldV = autoventa.clone(true, true, true, true);
        oldV.Resultado__c = VentasInformadasAutoventaOrigenUtil.MSG_AUTOVENTA_SIN_ORIGEN;

        VentasInformadasAutoventaOrigenUtil.aplicar(
            new List<Ventas_Informadas__c>{ autoventa },
            new Map<Id, Ventas_Informadas__c>{ autoventa.Id => oldV }
        );

        System.assertEquals(
            VentasInformadasAutoventaOrigenUtil.MSG_AUTOVENTA_SIN_ORIGEN,
            autoventa.Resultado__c
        );
    }

    @IsTest
    static void reprocesoConservaOkValidado() {
        Ventas_Informadas__c autoventa = autoventa('VAR-REPRO', '20111111112');
        autoventa.Id = fakeId();
        autoventa.Resultado__c = 'OK';
        Ventas_Informadas__c oldV = autoventa.clone(true, true, true, true);
        oldV.Resultado__c = 'OK';

        VentasInformadasAutoventaOrigenUtil.aplicarEnReproceso(
            new List<Ventas_Informadas__c>{ autoventa },
            new Map<Id, Ventas_Informadas__c>{ autoventa.Id => oldV },
            null
        );

        System.assertEquals('OK', autoventa.Resultado__c);
    }

    @IsTest
    static void reprocesoVuelveAMarcarSiSigueSinValidar() {
        Ventas_Informadas__c autoventa = autoventa('VAR-REMARCA', '20111111112');
        autoventa.Id = fakeId();
        autoventa.Resultado__c = 'OK';
        Ventas_Informadas__c oldV = autoventa.clone(true, true, true, true);
        oldV.Resultado__c = VentasInformadasAutoventaOrigenUtil.MSG_AUTOVENTA_SIN_ORIGEN;

        VentasInformadasAutoventaOrigenUtil.aplicarEnReproceso(
            new List<Ventas_Informadas__c>{ autoventa },
            new Map<Id, Ventas_Informadas__c>{ autoventa.Id => oldV },
            null
        );

        System.assertEquals(
            VentasInformadasAutoventaOrigenUtil.MSG_AUTOVENTA_SIN_ORIGEN,
            autoventa.Resultado__c
        );
    }

    @IsTest
    static void cambioDeVariedadVuelveAAvisar() {
        Ventas_Informadas__c autoventa = autoventa('VAR-NUEVA', '20111111112');
        autoventa.Id = fakeId();
        autoventa.Resultado__c = 'OK';
        Ventas_Informadas__c oldV = autoventa.clone(true, true, true, true);
        oldV.Resultado__c = 'OK';
        oldV.Variedad__c = 'VAR-VIEJA';

        VentasInformadasAutoventaOrigenUtil.aplicar(
            new List<Ventas_Informadas__c>{ autoventa },
            new Map<Id, Ventas_Informadas__c>{ autoventa.Id => oldV }
        );

        System.assertEquals(
            VentasInformadasAutoventaOrigenUtil.MSG_AUTOVENTA_SIN_ORIGEN,
            autoventa.Resultado__c
        );
    }

    @IsTest
    static void preBasicaNoSePisa() {
        Ventas_Informadas__c venta = autoventa('VAR-PB', '20111111112');
        venta.Categoria__c = 'Pre Básica';
        venta.Categoria_Portal__c = 'Pre Básica';
        venta.Resultado__c = VentasInformadasExclusionUtil.MSG_PENDIENTE_VALIDAR;

        VentasInformadasAutoventaOrigenUtil.aplicar(
            new List<Ventas_Informadas__c>{ venta },
            null
        );

        System.assertEquals(VentasInformadasExclusionUtil.MSG_PENDIENTE_VALIDAR, venta.Resultado__c);
    }

    @IsTest
    static void alInsertarAvisaYLuegoPermiteOk() {
        Test_TestUtils.disableFlows();
        Ventas_Informadas__c autoventa = autoventa('VAR-INS', '20111111112');
        autoventa.Estado__c = 'Pendiente';
        autoventa.Cantidad_de_Bolsas__c = 100;

        insert autoventa;

        autoventa = [
            SELECT Resultado__c
            FROM Ventas_Informadas__c
            WHERE Id = :autoventa.Id
        ];
        System.assertEquals(
            VentasInformadasAutoventaOrigenUtil.MSG_AUTOVENTA_SIN_ORIGEN,
            autoventa.Resultado__c
        );

        autoventa.Validar_Autoventa__c = true;
        update autoventa;

        autoventa = [
            SELECT Resultado__c
            FROM Ventas_Informadas__c
            WHERE Id = :autoventa.Id
        ];
        System.assertEquals('OK', autoventa.Resultado__c);
    }

    private static Ventas_Informadas__c autoventa(String variedad, String cuit) {
        return new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Venta_Interna__c = true,
            CUIT_Originante__c = cuit,
            CUIT_Destinatario__c = cuit,
            Campana_de_Ventas__c = '2026',
            Variedad__c = variedad,
            Categoria__c = 'Primera Multiplicación'
        );
    }

    private static Id fakeId() {
        String prefix = Ventas_Informadas__c.SObjectType.getDescribe().getKeyPrefix();
        return (Id) (prefix + '000000000001');
    }
}
