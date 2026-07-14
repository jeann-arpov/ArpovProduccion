@IsTest
private class VentasInformadasExclusionUtilTest {

    @IsTest
    static void esAutoventaCategoriaNoConvertible_mismoCuitYPreBasica() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20-14958890-7',
            CUIT_Destinatario__c = '20149588907',
            Categoria__c = 'Pre Básica'
        );
        System.assertEquals(true, VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(venta));
    }

    @IsTest
    static void esAutoventaCategoriaNoConvertible_mismoCuitYOriginal() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907',
            Categoria_Portal__c = 'Original o Fundadora'
        );
        System.assertEquals(true, VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(venta));
    }

    @IsTest
    static void esAutoventaCategoriaNoConvertible_primeraMultiplicacionNoAplica() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907',
            Categoria__c = 'Primera Multiplicación'
        );
        System.assertEquals(false, VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(venta));
    }

    @IsTest
    static void esAutoventaCategoriaNoConvertible_cuitsDistintosNoAplica() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20333333333',
            Categoria__c = 'Pre Básica'
        );
        System.assertEquals(false, VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(venta));
    }

    @IsTest
    static void esAutoventaCategoriaNoConvertible_nullYConVentaNoAplica() {
        System.assertEquals(false, VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(null));
        Ventas_Informadas__c conVenta = new Ventas_Informadas__c(
            Venta__c = 'a0X000000000001',
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907',
            Categoria__c = 'Pre Básica'
        );
        System.assertEquals(false, VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(conVenta));
    }

    @IsTest
    static void esPendienteValidarAutoventaDetectaMensaje() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Resultado__c = VentasInformadasExclusionUtil.MSG_PENDIENTE_VALIDAR
        );
        System.assertEquals(true, VentasInformadasExclusionUtil.esPendienteValidarAutoventa(venta));
        System.assertEquals(false, VentasInformadasExclusionUtil.esPendienteValidarAutoventa(null));
    }

    @IsTest
    static void marcarPendienteValidarSeteaEstadoYResultado() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907',
            Categoria__c = 'Pre Básica'
        );
        VentasInformadasExclusionUtil.marcarPendienteValidarSiCorresponde(venta);

        System.assertEquals(true, venta.Venta_Interna__c);
        System.assertEquals(VentasInformadasExclusionUtil.ESTADO_PENDIENTE, venta.Estado__c);
        System.assertEquals(VentasInformadasExclusionUtil.MSG_PENDIENTE_VALIDAR, venta.Resultado__c);
        System.assertEquals('Pre Básica', venta.Categoria_Portal__c);
    }

    @IsTest
    static void marcarPendienteValidarNoModificaSiProcesado() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Estado__c = 'Procesado',
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907',
            Categoria__c = 'Pre Básica'
        );
        VentasInformadasExclusionUtil.marcarPendienteValidarSiCorresponde(venta);
        System.assertEquals('Procesado', venta.Estado__c);
        System.assertEquals(null, venta.Resultado__c);
    }

    @IsTest
    static void marcarPendienteValidarSincronizaCategoriaPortal() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907',
            Categoria_Portal__c = 'Original o Fundadora'
        );
        VentasInformadasExclusionUtil.marcarPendienteValidarSiCorresponde(venta);
        System.assertEquals('Original o Fundadora', venta.Categoria__c);
    }

    @IsTest
    static void marcarPendientesValidarBulkConAccountsById() {
        Id rtProd = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Productor')
            .getRecordTypeId();
        Account acc = new Account(
            Name = 'Productor Exclusion Test',
            N_CUIT__c = '20149588907',
            Type = 'Productor',
            RecordTypeId = rtProd
        );
        insert acc;

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907',
            Categoria__c = 'Pre Básica',
            Originante__c = acc.Id
        );
        Map<Id, Account> byId = new Map<Id, Account>{ acc.Id => acc };

        VentasInformadasExclusionUtil.marcarPendientesValidarSiCorresponde(
            new List<Ventas_Informadas__c>{ venta },
            byId
        );

        System.assertEquals(true, venta.Venta_Interna__c);
        System.assertEquals(acc.Id, venta.Destinatario__c);
        System.assertEquals(acc.Name, venta.Razon_Social_Destinatario__c);
    }

    @IsTest
    static void marcarPendientesValidarListaVaciaNoFalla() {
        VentasInformadasExclusionUtil.marcarPendientesValidarSiCorresponde(new List<Ventas_Informadas__c>());
        VentasInformadasExclusionUtil.marcarPendientesValidarSiCorresponde(null);
    }

    @IsTest
    static void aliasesDeprecatedSiguenFuncionando() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907',
            Categoria__c = 'Pre Básica'
        );
        System.assertEquals(true, VentasInformadasExclusionUtil.esAutoventaExcluible(venta));
        VentasInformadasExclusionUtil.marcarExcluidaSiCorresponde(venta);
        VentasInformadasExclusionUtil.marcarExcluidasSiCorresponde(new List<Ventas_Informadas__c>{ venta });
        System.assertEquals(VentasInformadasExclusionUtil.ESTADO_PENDIENTE, venta.Estado__c);
    }

    @IsTest
    static void noEsElegibleParaConvertirCuandoPendienteValidar() {
        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Estado__c = VentasInformadasExclusionUtil.ESTADO_PENDIENTE,
            Resultado__c = VentasInformadasExclusionUtil.MSG_PENDIENTE_VALIDAR,
            Cantidad_Bolsas_40__c = 2
        );
        System.assertEquals(false, ConvertirVentasInformadasResumenUtil.esElegibleParaConvertir(venta));
    }
}