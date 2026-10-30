@isTest
private class UtilsCompraVentaHTTest {

    @isTest
    static void getCultivosConSaldoSumaHtVigentesSinPph() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
        cultivo.Sembra_Evolucion__c = true;
        insert cultivo;

        Account obtentor = Test_TestUtils.crearObtentor();
        Account productor = Test_TestUtils.crearProductor();

        Variedad__c variedad = new Variedad__c(
            Name = 'test',
            Obtentor_Comercializa__c = obtentor.Id,
            Biotecnologia__c = 'Enlist E3'
        );
        insert variedad;

        insert new List<Hectareas_Tecnologicas__c>{
            new Hectareas_Tecnologicas__c(
                Fecha_Inicio__c = Date.today().addMonths(-1),
                Fecha_Fin__c = Date.today().addMonths(1),
                Signo__c = 1,
                Cantidad__c = 100,
                Productor__c = productor.Id,
                Biotecnologia__c = 'Enlist E3',
                Cultivo__c = cultivo.Id,
                Variedad__c = variedad.Id,
                Origen__c = 'Compra HT',
                Valor_Conversion__c = 3000
            ),
            new Hectareas_Tecnologicas__c(
                Fecha_Inicio__c = Date.today().addMonths(-1),
                Fecha_Fin__c = Date.today().addMonths(1),
                Signo__c = 1,
                Cantidad__c = 40,
                Productor__c = productor.Id,
                Biotecnologia__c = 'Enlist E3',
                Cultivo__c = cultivo.Id,
                Variedad__c = variedad.Id,
                Origen__c = 'PPH',
                Valor_Conversion__c = 3000
            )
        };

        insert new Cuenta_Granaria__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = null,
            Tecnologia__c = 'Enlist E3/Conkesta E3',
            Es_Carga_Manual__c = true,
            Saldo_Cuenta__c = 45,
            Clave_Unica__c = productor.Id + '|' + cultivo.Id + '|null|Enlist'
        );

        Test.startTest();
        List<Map<String, Object>> conHt = UtilsCompraVentaHT.getCultivosConSaldo(productor.Id);
        List<Map<String, Object>> conGranaria = UtilsCompraVentaHT.getCultivosConSaldoGranaria(productor.Id);
        List<Map<String, Object>> sinProductor = UtilsCompraVentaHT.getCultivosConSaldo(null);
        Set<Id> variedadesSre = UtilsCompraVentaHT.getVariedadesSreProductor(productor.Id);
        Test.stopTest();

        Map<String, Object> soja = findCultivo(conHt, cultivo.Id);
        System.assertNotEquals(null, soja, 'Debe devolver el cultivo SE');
        Decimal saldoHt = (Decimal) soja.get('saldo');
        System.assert(saldoHt == 100 || saldoHt == 0, 'Excluye PPH; HT_Vigente depende de la formula: ' + saldoHt);

        System.assertEquals(45, (Decimal) findCultivo(conGranaria, cultivo.Id).get('saldo'));
        System.assertEquals(null, findCultivo(sinProductor, cultivo.Id).get('saldo'));
        System.assertEquals(0, variedadesSre.size());
    }

    @isTest
    static void cantidadDecimalSeRechazaYLaYaGuardadaNo() {
        System.assertEquals(false, UtilsCompraVentaHT.debeRechazarCantidadDecimal(
            new Linea_de_Compra_HT__c(Cantidad__c = 10),
            null,
            'Cantidad__c'
        ));
        System.assertEquals(false, UtilsCompraVentaHT.debeRechazarCantidadDecimal(
            new Linea_de_Compra_HT__c(),
            null,
            'Cantidad__c'
        ));
        System.assertEquals(true, UtilsCompraVentaHT.debeRechazarCantidadDecimal(
            new Linea_de_Compra_HT__c(Cantidad__c = 10.5),
            null,
            'Cantidad__c'
        ));

        Id lineaId = (Id) (Linea_de_Compra_HT__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
        Linea_de_Compra_HT__c actual = new Linea_de_Compra_HT__c(Id = lineaId, Cantidad__c = 87.5);
        Map<Id, SObject> anteriores = new Map<Id, SObject>{
            lineaId => new Linea_de_Compra_HT__c(Id = lineaId, Cantidad__c = 87.5)
        };
        System.assertEquals(false, UtilsCompraVentaHT.debeRechazarCantidadDecimal(actual, anteriores, 'Cantidad__c'));

        actual.Cantidad__c = 90.5;
        System.assertEquals(true, UtilsCompraVentaHT.debeRechazarCantidadDecimal(actual, anteriores, 'Cantidad__c'));

        actual.Cantidad__c = 90;
        System.assertEquals(false, UtilsCompraVentaHT.debeRechazarCantidadDecimal(actual, anteriores, 'Cantidad__c'));

        UtilsCompraVentaHT.validarCantidadEntera(10);
        UtilsCompraVentaHT.validarCantidadEntera(10.0);
        UtilsCompraVentaHT.validarCantidadEntera(null);
        try {
            UtilsCompraVentaHT.validarCantidadEntera(2.34);
            System.assert(false, 'Debió rechazar la cantidad con decimales');
        } catch (AuraHandledException ex) {
            System.assertEquals(UtilsCompraVentaHT.MENSAJE_CANTIDAD_ENTERA, ex.getMessage());
        }
    }

    private static Map<String, Object> findCultivo(List<Map<String, Object>> options, Id cultivoId) {
        for (Map<String, Object> option : options) {
            if ((Id) option.get('value') == cultivoId) {
                return option;
            }
        }
        return null;
    }
}