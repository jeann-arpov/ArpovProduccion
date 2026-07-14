@IsTest
private class ConvertirVentasInformadasResumenUtilTest {

    @IsTest
    static void analizarYFormatearMensajesTest() {
        ConvertirVentasInformadasResumenUtil.Resumen resumenVacio =
            ConvertirVentasInformadasResumenUtil.analizar(new Set<Id>());
        System.assertEquals(0, resumenVacio.totalSeleccionados);

        String advertencia = ConvertirVentasInformadasResumenUtil.formatearMensajeAdvertencia(
            ConvertirVentasInformadasResumenUtil.buildResumenForTest(3, 1, 2, 0)
        );
        System.assert(advertencia.contains('3'));
        System.assert(advertencia.contains('2 tienen Cantidad (Bolsas SF) = 0'));

        String advertenciaAutoventa = ConvertirVentasInformadasResumenUtil.formatearMensajeAdvertencia(
            ConvertirVentasInformadasResumenUtil.buildResumenForTest(2, 1, 0, 0, 1)
        );
        System.assert(
            advertenciaAutoventa.contains('autoventas/siembras propias con categoría Original o Pre Básica'),
            'Debe advertir autoventas no convertibles: ' + advertenciaAutoventa
        );

        String soloConvertidas = ConvertirVentasInformadasResumenUtil.formatearMensajeResultado(4, 0, 0);
        System.assertEquals('Proceso finalizado: 4 ventas convertidas correctamente.', soloConvertidas);

        String sinRegistros = ConvertirVentasInformadasResumenUtil.formatearMensajeResultado(0, 0, 0);
        System.assert(sinRegistros.contains('no se encontraron registros'));
    }

    @IsTest
    static void resolverResultadoFinalTest() {
        Ventas_Informadas__c conBolsas = new Ventas_Informadas__c(Cantidad_Bolsas_40__c = 2);
        Ventas_Informadas__c sinBolsas = new Ventas_Informadas__c(Cantidad_Bolsas_40__c = 0);

        System.assertEquals('OK', ConvertirVentasInformadasResumenUtil.resolverResultadoFinal(conBolsas, ''));
        System.assertEquals(
            ConvertirVentasInformadasResumenUtil.MSG_CANTIDAD_BOLSAS_CERO,
            ConvertirVentasInformadasResumenUtil.resolverResultadoFinal(sinBolsas, '')
        );
        System.assertEquals(
            'No existe la campaña.',
            ConvertirVentasInformadasResumenUtil.resolverResultadoFinal(sinBolsas, 'No existe la campaña.')
        );
    }

    @IsTest
    static void analizarClasificaRegistrosTest() {
        Ventas_Informadas__c convertible = new Ventas_Informadas__c(
            Cantidad_Bolsas_40__c = 2,
            Resultado__c = 'OK',
            Estado__c = 'Preprocesado'
        );
        Ventas_Informadas__c bolsasCero = new Ventas_Informadas__c(
            Cantidad_Bolsas_40__c = 0,
            Resultado__c = 'OK',
            Estado__c = 'Preprocesado'
        );
        Ventas_Informadas__c noElegible = new Ventas_Informadas__c(
            Cantidad_Bolsas_40__c = 2,
            Resultado__c = 'Error',
            Estado__c = 'Preprocesado'
        );
        Ventas_Informadas__c autoventaPendiente = new Ventas_Informadas__c(
            Cantidad_Bolsas_40__c = 2,
            Resultado__c = VentasInformadasExclusionUtil.MSG_PENDIENTE_VALIDAR,
            Estado__c = VentasInformadasExclusionUtil.ESTADO_PENDIENTE,
            CUIT_Originante__c = '20149588907',
            CUIT_Destinatario__c = '20149588907',
            Categoria__c = 'Pre Básica'
        );

        System.assertEquals(true, ConvertirVentasInformadasResumenUtil.esElegibleParaConvertir(convertible));
        System.assertEquals(false, ConvertirVentasInformadasResumenUtil.tieneBolsasCero(convertible));
        System.assertEquals(true, ConvertirVentasInformadasResumenUtil.tieneBolsasCero(bolsasCero));
        System.assertEquals(false, ConvertirVentasInformadasResumenUtil.esElegibleParaConvertir(noElegible));
        System.assertEquals(false, ConvertirVentasInformadasResumenUtil.esElegibleParaConvertir(autoventaPendiente));

        String mensaje = ConvertirVentasInformadasResumenUtil.formatearMensajeResultado(2, 1, 0);
        System.assert(mensaje.contains('2 ventas convertidas correctamente'));
        System.assert(mensaje.contains('1 ventas informadas con Cantidad (Bolsas SF) = 0'));

        Set<Id> parsed = ConvertirVentasInformadasResumenUtil.parseRecordIds('001000000000001, 001000000000002');
        System.assertEquals(2, parsed.size());
    }

    @IsTest
    static void analizarConRegistrosInsertadosTest() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c convertible = new Ventas_Informadas__c(
            Cantidad_Bolsas_40__c = 2,
            Resultado__c = 'OK',
            Estado__c = 'Preprocesado',
            CUIT_Originante__c = '20111111111',
            CUIT_Destinatario__c = '20222222222',
            Categoria__c = 'Primera Multiplicación'
        );
        Ventas_Informadas__c autoventa = new Ventas_Informadas__c(
            Cantidad_Bolsas_40__c = 1,
            Resultado__c = VentasInformadasExclusionUtil.MSG_PENDIENTE_VALIDAR,
            Estado__c = VentasInformadasExclusionUtil.ESTADO_PENDIENTE,
            CUIT_Originante__c = '20333333333',
            CUIT_Destinatario__c = '20333333333',
            Categoria__c = 'Pre Básica',
            Categoria_Portal__c = 'Pre Básica'
        );
        insert new List<Ventas_Informadas__c>{ convertible, autoventa };

        Test.startTest();
        ConvertirVentasInformadasResumenUtil.Resumen resumen =
            ConvertirVentasInformadasResumenUtil.analizar(
                new Set<Id>{ convertible.Id, autoventa.Id }
            );
        Test.stopTest();

        System.assertEquals(2, resumen.totalSeleccionados);
        System.assertEquals(1, resumen.convertibles);
        System.assertEquals(1, resumen.autoventasNoConvertibles);
        System.assert(resumen.tieneAdvertencia);
        System.assert(String.isNotBlank(resumen.mensajeAdvertencia));
    }
}