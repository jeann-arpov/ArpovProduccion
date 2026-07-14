@IsTest
private class ExpedientesControllerTest {

    @TestSetup
    static void setupData() {
        Test_TestUtils.disableFlows();

        Account productorConExpediente = Test_TestUtils.crearProductor();
        Account productorSinExpediente = new Account(
            Name = 'Productor Sin Expediente',
            RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Productor'),
            Clave_Unica__c = 'prod-sin-exp',
            N_CUIT__c = '30111222335',
            Direccion_de_Correo_electronico_del_CUIT__c = 'prod2@test.com',
            Condicion_Impositiva__c = 'No Aplica',
            Type = 'Productor',
            Localidad_Envio__c = [SELECT Id FROM Localidad__c LIMIT 1].Id
        );
        insert productorSinExpediente;

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Tipo_de_Especie__c = 'SOJA',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c campania = new Campana_Agricola__c(
            Name = 'SOJA 2025 EXP',
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,

            Fecha_de_Inicio__c = Date.today().addMonths(-2),
            Fecha_de_Fin__c = Date.today().addMonths(8)
        );
        insert campania;

        Cuenta_Granaria__c cgConExpediente = new Cuenta_Granaria__c(
            Productor__c = productorConExpediente.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campania.Id,
            Tecnologia__c = 'Enlist E3/Conkesta E3',
            Saldo_Cuenta__c = -12,
            Clave_Unica__c = productorConExpediente.Id + '|' + campania.Id + '|' + cultivo.Id + '|Enlist E3/Conkesta E3'
        );
        Cuenta_Granaria__c cgSinExpediente = new Cuenta_Granaria__c(
            Productor__c = productorSinExpediente.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campania.Id,
            Tecnologia__c = 'Enlist E3/Conkesta E3',
            Saldo_Cuenta__c = 20,
            Clave_Unica__c = productorSinExpediente.Id + '|' + campania.Id + '|' + cultivo.Id + '|Enlist E3/Conkesta E3'
        );
        insert new List<Cuenta_Granaria__c>{ cgConExpediente, cgSinExpediente };

        Expediente_de_Negativos__c expedienteAbierto = new Expediente_de_Negativos__c(
            Campania__c = campania.Id,
            Cuenta__c = productorConExpediente.Id,
            Cuenta_Granaria__c = cgConExpediente.Id,
            Saldo_Previo_al_Expediente__c = -12,
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today()
        );
        Expediente_de_Negativos__c expedienteFinalizado = new Expediente_de_Negativos__c(
            Campania__c = campania.Id,
            Cuenta__c = productorConExpediente.Id,
            Cuenta_Granaria__c = cgConExpediente.Id,
            Saldo_Previo_al_Expediente__c = -8,
            Estado_de_la_Etapa__c = 'Finalizado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today().addDays(-3)
        );
        
        System.debug(LoggingLevel.ERROR, '=== DEBUG ExpedientesControllerTest.setupData ===');
        System.debug(LoggingLevel.ERROR, 'Campania creada -> Id=' + campania.Id + ', Name=' + campania.Name +
            ', Ano__c=' + campania.Ano__c + ', Estado__c=' + campania.Estado__c +
            ', Cultivo__c=' + campania.Cultivo__c);
        System.debug(LoggingLevel.ERROR, 'Cuenta productor -> Id=' + productorConExpediente.Id + ', Name=' + productorConExpediente.Name);
        System.debug(LoggingLevel.ERROR, 'Cuenta granaria -> Id=' + cgConExpediente.Id + ', Campania__c=' + cgConExpediente.Campania__c);
        System.debug(LoggingLevel.ERROR, 'Exp abierto payload -> Campania__c=' + expedienteAbierto.Campania__c +
            ', Cuenta__c=' + expedienteAbierto.Cuenta__c + ', Cuenta_Granaria__c=' + expedienteAbierto.Cuenta_Granaria__c +
            ', Estado=' + expedienteAbierto.Estado_de_la_Etapa__c + ', Etapa=' + expedienteAbierto.Etapa__c);
        System.debug(LoggingLevel.ERROR, 'Exp finalizado payload -> Campania__c=' + expedienteFinalizado.Campania__c +
            ', Cuenta__c=' + expedienteFinalizado.Cuenta__c + ', Cuenta_Granaria__c=' + expedienteFinalizado.Cuenta_Granaria__c +
            ', Estado=' + expedienteFinalizado.Estado_de_la_Etapa__c + ', Etapa=' + expedienteFinalizado.Etapa__c);
        
        try {
            insert new List<Expediente_de_Negativos__c>{ expedienteAbierto, expedienteFinalizado };
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'DML insert Expediente_de_Negativos__c falló: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'NumDml=' + e.getNumDml());
            for (Integer i = 0; i < e.getNumDml(); i++) {
                System.debug(LoggingLevel.ERROR, 'Row ' + i + ' status=' + e.getDmlStatusCode(i) +
                    ', message=' + e.getDmlMessage(i) + ', fields=' + e.getDmlFieldNames(i));
            }
            throw e;
        }

        Compra_HT__c compraConExpediente = new Compra_HT__c(
            Lista_de_Precios__c = Test.getStandardPricebookId(),
            Cuenta_Productor__c = productorConExpediente.Id,
            Estado__c = 'Creada'
        );
        Compra_HT__c compraSinExpediente = new Compra_HT__c(
            Lista_de_Precios__c = Test.getStandardPricebookId(),
            Cuenta_Productor__c = productorSinExpediente.Id,
            Estado__c = 'Creada'
        );
        insert new List<Compra_HT__c>{ compraConExpediente, compraSinExpediente };

        Venta_HT__c ventaConExpediente = new Venta_HT__c(
            Name = 'Venta con expediente',
            Estado__c = 'Creada',
            Cuenta_Productor__c = productorConExpediente.Id
        );
        insert ventaConExpediente;
    }

    @IsTest
    static void testObtenerDetallesExpedienteConCuenta() {
        Cuenta_Granaria__c cg = [
            SELECT Id
            FROM Cuenta_Granaria__c
            WHERE Saldo_Cuenta__c < 0
            LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> result = ExpedientesController.obtenerDetallesExpediente(cg.Id);
        Test.stopTest();

        System.assertEquals(true, (Boolean)result.get('tieneExpediente'));
        List<Object> expedientes = (List<Object>)result.get('expedientes');
        System.assertEquals(1, expedientes.size(), 'Solo debe devolver expedientes no finalizados');
        Map<String, Object> exp = (Map<String, Object>)expedientes[0];
        System.assertNotEquals(null, exp.get('estado'));
        System.assertEquals('No empezado', (String)exp.get('estado'));
    }

    @IsTest
    static void testObtenerDetallesExpedienteSinId() {
        Test.startTest();
        Map<String, Object> result = ExpedientesController.obtenerDetallesExpediente(null);
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('tieneExpediente'));
        System.assertEquals(0, ((List<Object>)result.get('expedientes')).size());
    }
    
    @IsTest
    static void testObtenerDetallesExpedienteSinRegistrosActivos() {
        Cuenta_Granaria__c cgSinExp = [
            SELECT Id
            FROM Cuenta_Granaria__c
            WHERE Saldo_Cuenta__c > 0
            LIMIT 1
        ];
        
        Test.startTest();
        Map<String, Object> result = ExpedientesController.obtenerDetallesExpediente(cgSinExp.Id);
        Test.stopTest();
        
        System.assertEquals(false, (Boolean)result.get('tieneExpediente'));
        System.assertEquals(0, ((List<Object>)result.get('expedientes')).size());
    }

    @IsTest
    static void testVerificarExpedienteCompraConYSinExpediente() {
        Compra_HT__c compraConExpediente = [
            SELECT Id
            FROM Compra_HT__c
            WHERE Cuenta_Productor__r.Name = 'productor'
            LIMIT 1
        ];
        Compra_HT__c compraSinExpediente = [
            SELECT Id
            FROM Compra_HT__c
            WHERE Cuenta_Productor__r.Name = 'Productor Sin Expediente'
            LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> resultCon = ExpedientesController.verificarExpedienteEnHTDisponible(
            compraConExpediente.Id,
            'compra'
        );
        Map<String, Object> resultSin = ExpedientesController.verificarExpedienteEnHTDisponible(
            compraSinExpediente.Id,
            'compra'
        );
        Test.stopTest();

        System.assertEquals(true, (Boolean)resultCon.get('tieneExpediente'));
        System.assertNotEquals(null, resultCon.get('cuentaGranariaId'));
        System.assert(((List<Object>)resultCon.get('expedientes')).size() > 0);

        System.assertEquals(false, (Boolean)resultSin.get('tieneExpediente'));
        System.assertEquals(null, resultSin.get('cuentaGranariaId'));
        System.assertEquals(0, ((List<Object>)resultSin.get('expedientes')).size());
    }

    @IsTest
    static void testVerificarExpedienteVentaYParametrosInvalidos() {
        Venta_HT__c venta = [SELECT Id FROM Venta_HT__c WHERE Name = 'Venta con expediente' LIMIT 1];

        Test.startTest();
        Map<String, Object> resultVenta = ExpedientesController.verificarExpedienteEnHTDisponible(
            venta.Id,
            'venta'
        );
        Map<String, Object> resultInvalido = ExpedientesController.verificarExpedienteEnHTDisponible(
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(true, (Boolean)resultVenta.get('tieneExpediente'));
        System.assertNotEquals(null, resultVenta.get('cuentaGranariaId'));
        System.assert(((List<Object>)resultVenta.get('expedientes')).size() > 0);

        System.assertEquals(false, (Boolean)resultInvalido.get('tieneExpediente'));
        System.assertEquals(null, resultInvalido.get('cuentaGranariaId'));
        System.assertEquals(0, ((List<Object>)resultInvalido.get('expedientes')).size());
    }
    
    
}