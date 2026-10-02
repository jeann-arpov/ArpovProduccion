@IsTest
private class CuentaGranariaTriggerHandlerTest {

    private static Cuenta_Granaria__c crearCuentaManualNegativa(String tecnologia, Decimal saldo) {
        Test_TestUtils.disableFlows();

        Account productor = Test_TestUtils.crearProductor();

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Tipo_de_Especie__c = 'SOJA',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c campania = new Campana_Agricola__c(
            Name = 'SOJA 2025 CG TEST',
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-2),
            Fecha_de_Fin__c = Date.today().addMonths(8)
        );
        insert campania;

        Cuenta_Granaria__c cg = new Cuenta_Granaria__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campania.Id,
            Tecnologia__c = tecnologia,
            Es_Carga_Manual__c = true,
            Saldo_Cuenta__c = saldo,
            Clave_Unica__c = productor.Id + '|' + campania.Id + '|' + cultivo.Id + '|' + tecnologia
        );
        return cg;
    }

    @IsTest
    static void testCreaExpedienteParaCargaManualNegativa() {
        CuentaGranariaTriggerHandler.HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = true;
        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);

        Test.startTest();
        insert cg;
        Test.stopTest();

        List<Expediente_de_Negativos__c> expedientes = [
            SELECT Id, Cuenta_Granaria__c, Saldo_Previo_al_Expediente__c, Saldo_Expediente__c, Etapa__c
            FROM Expediente_de_Negativos__c
            WHERE Cuenta_Granaria__c = :cg.Id
        ];

        System.assertEquals(1, expedientes.size(), 'Debe crear un expediente para saldo manual menor a -3.');
        System.assertEquals(-4, expedientes[0].Saldo_Previo_al_Expediente__c);
        System.assertEquals(-4, expedientes[0].Saldo_Expediente__c);
        System.assertEquals('Llamar', expedientes[0].Etapa__c);
    }

    @IsTest
    static void testActualizaExpedienteActivoExistente() {
        CuentaGranariaTriggerHandler.HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = true;
        Cuenta_Granaria__c cg = crearCuentaManualNegativa('RR1/RR2 - BT/Convencional', -4);
        insert cg;

        Expediente_de_Negativos__c expediente = [
            SELECT Id
            FROM Expediente_de_Negativos__c
            WHERE Cuenta_Granaria__c = :cg.Id
            LIMIT 1
        ];

        Test.startTest();
        cg.Saldo_Cuenta__c = -8;
        update cg;
        Test.stopTest();

        List<Expediente_de_Negativos__c> expedientes = [
            SELECT Id, Saldo_Expediente__c, Estado_de_la_Etapa__c
            FROM Expediente_de_Negativos__c
            WHERE Cuenta_Granaria__c = :cg.Id
        ];

        System.assertEquals(1, expedientes.size(), 'No debe crear un segundo expediente activo.');
        System.assertEquals(expediente.Id, expedientes[0].Id);
        System.assertEquals(-8, expedientes[0].Saldo_Expediente__c);
    }

    @IsTest
    static void testCreaExpedienteNoVinculaToneladaNiMbt() {
        Test_TestUtils.disableFlows();
        CuentaGranariaTriggerHandler.HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = true;
        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', 0);
        insert cg;

        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Id = :cg.Productor__c];
        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Estado__c = 'Creado',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'Enlist',
            CTG__c = 'CTG-TRIGGER-001',
            Codigo_de_Muestra__c = 'MUE-TRIGGER-001',
            Peso_Neto__c = 100,
            CUIT_Titular__c = productor.N_CUIT__c,
            Cuit_Destinatario__c = productor.N_CUIT__c
        );
        insert mbt;

        Tonelada__c tn = new Tonelada__c(
            Productor__c = cg.Productor__c,
            Cultivo__c = cg.Cultivo__c,
            Cantidad__c = 10,
            Cuenta_Granaria__c = cg.Id,
            Mov_BolsaTech__c = mbt.Id,
            Origen__c = 'BolsaTech'
        );
        insert tn;

        Test.startTest();
        cg.Saldo_Cuenta__c = -4;
        update cg;
        Test.stopTest();

        Expediente_de_Negativos__c expediente = [
            SELECT Id
            FROM Expediente_de_Negativos__c
            WHERE Cuenta_Granaria__c = :cg.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, expediente.Id, 'Debe crear el EXP de la CG');
        System.assertEquals(
            null,
            [SELECT Expediente_de_Negativos__c FROM Tonelada__c WHERE Id = :tn.Id].Expediente_de_Negativos__c,
            'Crear el EXP de la CG no debe vincular la tonelada'
        );
        System.assertEquals(
            null,
            [SELECT Expediente_de_Negativos__c FROM Movimiento_BolsaTech__c WHERE Id = :mbt.Id].Expediente_de_Negativos__c,
            'Crear el EXP de la CG no debe vincular el movimiento Bolsatech'
        );
    }

    @IsTest
    static void testNoCreaExpedienteParaSucursalConCuentaPrincipal() {
        CuentaGranariaTriggerHandler.HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = true;
        Account principal = Test_TestUtils.crearProductor();

        Account sucursal = new Account(
            Name = 'productor (Suc. Test)',
            RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Productor'),
            Clave_Unica__c = 'prod-suc-01',
            N_CUIT__c = '30641405554',
            Direccion_de_Correo_electronico_del_CUIT__c = 'sucursal@test.com',
            Localidad_Envio__c = principal.Localidad_Envio__c,
            Condicion_Impositiva__c = 'No Aplica',
            Type = 'Productor',
            ParentId = principal.Id
        );
        insert sucursal;

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Tipo_de_Especie__c = 'SOJA',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c campania = new Campana_Agricola__c(
            Name = 'SOJA 2025 CG SUC TEST',
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-2),
            Fecha_de_Fin__c = Date.today().addMonths(8)
        );
        insert campania;

        Cuenta_Granaria__c cg = new Cuenta_Granaria__c(
            Productor__c = sucursal.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campania.Id,
            Tecnologia__c = 'Enlist E3/Conkesta E3',
            Es_Carga_Manual__c = true,
            Saldo_Cuenta__c = -4,
            Clave_Unica__c = sucursal.Id + '|' + campania.Id + '|' + cultivo.Id + '|Enlist E3/Conkesta E3'
        );

        Test.startTest();
        insert cg;
        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Expediente_de_Negativos__c
                WHERE Cuenta_Granaria__c = :cg.Id
            ],
            'No debe crear expediente en cuentas con Cuenta principal (ParentId) distinta de null.'
        );
    }
}