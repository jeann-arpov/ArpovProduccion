@IsTest
private class CuentaGranariaExpedienteServiceTest {

    private static Cuenta_Granaria__c crearCuentaManualNegativa(String tecnologia, Decimal saldo) {
        Test_TestUtils.disableFlows();
        CuentaGranariaTriggerHandler.HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = false;

        Account productor = Test_TestUtils.crearProductor();

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Tipo_de_Especie__c = 'SOJA',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c campania = new Campana_Agricola__c(
            Name = 'SOJA 2025 CG EXP TEST',
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
        insert cg;
        return [SELECT Id, Name, Productor__c, Campania__c, Cultivo__c, Es_Carga_Manual__c, Saldo_Cuenta__c FROM Cuenta_Granaria__c WHERE Id = :cg.Id];
    }

    @IsTest
    static void testGeneraExpedientePorNombre() {
        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);

        Test.startTest();
        Id expedienteId = CuentaGranariaExpedienteService.generarExpedientePorNombre(cg.Name);
        Test.stopTest();

        Expediente_de_Negativos__c expediente = [
            SELECT Id, Cuenta_Granaria__c, Saldo_Previo_al_Expediente__c, Saldo_Expediente__c, Etapa__c
            FROM Expediente_de_Negativos__c
            WHERE Id = :expedienteId
        ];

        System.assertEquals(cg.Id, expediente.Cuenta_Granaria__c);
        System.assertEquals(-4, expediente.Saldo_Previo_al_Expediente__c);
        System.assertEquals(-4, expediente.Saldo_Expediente__c);
        System.assertEquals('Llamar', expediente.Etapa__c);
    }

    @IsTest
    static void testActualizaExpedienteActivoExistente() {
        Cuenta_Granaria__c cg = crearCuentaManualNegativa('RR1/RR2 - BT/Convencional', -4);
        Id expedienteInicialId = CuentaGranariaExpedienteService.generarExpedientePorNombre(cg.Name);

        cg.Saldo_Cuenta__c = -8;
        update cg;

        Test.startTest();
        Id expedienteId = CuentaGranariaExpedienteService.generarExpedientePorNombre(cg.Name);
        Test.stopTest();

        System.assertEquals(expedienteInicialId, expedienteId);

        Expediente_de_Negativos__c expediente = [
            SELECT Id, Saldo_Expediente__c
            FROM Expediente_de_Negativos__c
            WHERE Id = :expedienteId
        ];
        System.assertEquals(-8, expediente.Saldo_Expediente__c);
    }

    @IsTest
    static void testRechazaCuentaNoManual() {
        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);
        cg.Es_Carga_Manual__c = false;
        update cg;
        cg = [SELECT Name FROM Cuenta_Granaria__c WHERE Id = :cg.Id];

        Boolean fallo = false;
        Test.startTest();
        try {
            CuentaGranariaExpedienteService.generarExpedientePorNombre(cg.Name);
        } catch (CuentaGranariaExpedienteService.ExpedienteCgException e) {
            fallo = true;
            System.assert(e.getMessage().contains('no es de carga manual'));
        }
        Test.stopTest();

        System.assert(fallo, 'Debe rechazar cuentas que no son de carga manual.');
    }

    @IsTest
    static void testVincularToneladasYMovimientosPorNombresExpediente() {
        Test_TestUtils.disableFlows();

        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c(
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Cuenta_Granaria__c = cg.Id,
            Saldo_Previo_al_Expediente__c = -4,
            Saldo_Expediente__c = -4,
            Tipo_expendiente__c = 'EXP',
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );
        insert expediente;
        expediente = [SELECT Id, Name FROM Expediente_de_Negativos__c WHERE Id = :expediente.Id];

        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Id = :cg.Productor__c];
        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Estado__c = 'Creado',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'Enlist',
            CTG__c = 'CTG-VINC-001',
            Codigo_de_Muestra__c = 'MUE-VINC-001',
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
        CuentaGranariaExpedienteService.VinculacionExpedienteResult resultado =
            CuentaGranariaExpedienteService.vincularToneladasYMovimientosPorNombresExpediente(
                new Set<String>{ expediente.Name }
            );
        Test.stopTest();

        System.assertEquals(1, resultado.expedientesEncontrados);
        System.assertEquals(1, resultado.toneladasActualizadas);

        Tonelada__c tnActualizada = [
            SELECT Expediente_de_Negativos__c
            FROM Tonelada__c
            WHERE Id = :tn.Id
        ];
        System.assertEquals(expediente.Id, tnActualizada.Expediente_de_Negativos__c);
        System.assertEquals(
            expediente.Id,
            [SELECT Expediente_de_Negativos__c FROM Movimiento_BolsaTech__c WHERE Id = :mbt.Id].Expediente_de_Negativos__c,
            'El MBT asociado debe recibir el mismo expediente que la tonelada'
        );
    }

    @IsTest
    static void testVincularNoSobrescribeExpedientePri() {
        Test_TestUtils.disableFlows();

        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);

        Expediente_de_Negativos__c expedientePri = new Expediente_de_Negativos__c(
            Name = 'PRI-12345678-001',
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Tipo_expendiente__c = 'PRI',
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );
        insert expedientePri;
        expedientePri = [
            SELECT Id, Name
            FROM Expediente_de_Negativos__c
            WHERE Id = :expedientePri.Id
        ];

        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c(
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Cuenta_Granaria__c = cg.Id,
            Saldo_Previo_al_Expediente__c = -4,
            Saldo_Expediente__c = -4,
            Tipo_expendiente__c = 'EXP',
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );
        insert expediente;
        expediente = [SELECT Id, Name FROM Expediente_de_Negativos__c WHERE Id = :expediente.Id];

        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Id = :cg.Productor__c];
        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Estado__c = 'Creado',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'Enlist',
            CTG__c = 'CTG-VINC-PRI-001',
            Codigo_de_Muestra__c = 'MUE-VINC-PRI-001',
            Peso_Neto__c = 100,
            CUIT_Titular__c = productor.N_CUIT__c,
            Cuit_Destinatario__c = productor.N_CUIT__c,
            Expediente_de_Negativos__c = expedientePri.Id
        );
        insert mbt;

        Tonelada__c tn = new Tonelada__c(
            Productor__c = cg.Productor__c,
            Cultivo__c = cg.Cultivo__c,
            Cantidad__c = 10,
            Cuenta_Granaria__c = cg.Id,
            Mov_BolsaTech__c = mbt.Id,
            Origen__c = 'BolsaTech',
            Expediente_de_Negativos__c = expedientePri.Id
        );
        insert tn;

        Test.startTest();
        CuentaGranariaExpedienteService.VinculacionExpedienteResult resultado =
            CuentaGranariaExpedienteService.vincularToneladasYMovimientosPorNombresExpediente(
                new Set<String>{ expediente.Name }
            );
        Test.stopTest();

        System.assertEquals(1, resultado.expedientesEncontrados);
        System.assertEquals(0, resultado.toneladasActualizadas);
        System.assertEquals(0, resultado.movimientosActualizados);

        Tonelada__c tnActualizada = [
            SELECT Expediente_de_Negativos__c, Expediente_de_Origen__c
            FROM Tonelada__c
            WHERE Id = :tn.Id
        ];
        System.assertEquals(expedientePri.Id, tnActualizada.Expediente_de_Negativos__c);
        System.assertEquals(null, tnActualizada.Expediente_de_Origen__c);

        Movimiento_BolsaTech__c mbtActualizado = [
            SELECT Expediente_de_Negativos__c
            FROM Movimiento_BolsaTech__c
            WHERE Id = :mbt.Id
        ];
        System.assertEquals(expedientePri.Id, mbtActualizado.Expediente_de_Negativos__c);
    }

    @IsTest
    static void testVincularExpedientesNoFinalizados() {
        Test_TestUtils.disableFlows();

        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c(
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Cuenta_Granaria__c = cg.Id,
            Saldo_Previo_al_Expediente__c = -4,
            Saldo_Expediente__c = -4,
            Tipo_expendiente__c = 'EXP',
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );
        insert expediente;

        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Id = :cg.Productor__c];
        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Estado__c = 'Creado',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'Enlist',
            CTG__c = 'CTG-VINC-BULK-001',
            Codigo_de_Muestra__c = 'MUE-VINC-BULK-001',
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
        CuentaGranariaExpedienteService.VinculacionExpedienteResult resultado =
            CuentaGranariaExpedienteService.vincularToneladasYMovimientosExpedientesNoFinalizados();
        Test.stopTest();

        System.assertEquals(1, resultado.expedientesEncontrados);
        System.assertEquals(1, resultado.toneladasActualizadas);

        Tonelada__c tnActualizada = [
            SELECT Expediente_de_Negativos__c
            FROM Tonelada__c
            WHERE Id = :tn.Id
        ];
        System.assertEquals(expediente.Id, tnActualizada.Expediente_de_Negativos__c);
    }

    @IsTest
    static void testVincularExpedientesNoFinalizadosIgnoraFinalizados() {
        Test_TestUtils.disableFlows();

        Cuenta_Granaria__c cg = crearCuentaManualNegativa('RR1/RR2 - BT/Convencional', -4);
        insert new Expediente_de_Negativos__c(
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Cuenta_Granaria__c = cg.Id,
            Tipo_expendiente__c = 'EXP',
            Estado_de_la_Etapa__c = 'Finalizado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );

        Tonelada__c tn = new Tonelada__c(
            Productor__c = cg.Productor__c,
            Cultivo__c = cg.Cultivo__c,
            Cantidad__c = 10,
            Cuenta_Granaria__c = cg.Id,
            Origen__c = 'BolsaTech'
        );
        insert tn;

        Test.startTest();
        CuentaGranariaExpedienteService.VinculacionExpedienteResult resultado =
            CuentaGranariaExpedienteService.vincularToneladasYMovimientosExpedientesNoFinalizados();
        Test.stopTest();

        System.assertEquals(0, resultado.expedientesEncontrados);
        System.assertEquals(0, resultado.toneladasActualizadas);
        System.assertEquals(null, [SELECT Expediente_de_Negativos__c FROM Tonelada__c WHERE Id = :tn.Id].Expediente_de_Negativos__c);
    }

    @IsTest
    static void testVincularRequiereNombresExpediente() {
        Boolean fallo = false;
        try {
            CuentaGranariaExpedienteService.vincularToneladasYMovimientosPorNombresExpediente(new Set<String>());
        } catch (CuentaGranariaExpedienteService.ExpedienteCgException e) {
            fallo = true;
            System.assert(e.getMessage().contains('al menos un Name'));
        }
        System.assert(fallo, 'Debe exigir nombres de expediente.');
    }

    @IsTest
    static void testCompletarExpedienteMbtDesdeTonelada() {
        Test_TestUtils.disableFlows();
        CuentaGranariaTriggerHandler.HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = false;

        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c(
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Cuenta_Granaria__c = cg.Id,
            Tipo_expendiente__c = 'EXP',
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );
        insert expediente;

        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Id = :cg.Productor__c];
        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Estado__c = 'Creado',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'Enlist',
            CTG__c = 'CTG-MBT-DESDE-TN-001',
            Codigo_de_Muestra__c = 'MUE-MBT-DESDE-TN-001',
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
            Origen__c = 'BolsaTech',
            Expediente_de_Negativos__c = expediente.Id
        );
        insert tn;

        Test.startTest();
        CuentaGranariaExpedienteService.VinculacionExpedienteResult resultado =
            CuentaGranariaExpedienteService.completarExpedienteMbtDesdeTonelada();
        Test.stopTest();

        System.assertEquals(1, resultado.expedientesEncontrados);
        System.assertEquals(1, resultado.movimientosActualizados);
        System.assertEquals(
            expediente.Id,
            [SELECT Expediente_de_Negativos__c FROM Movimiento_BolsaTech__c WHERE Id = :mbt.Id].Expediente_de_Negativos__c
        );
    }

    @IsTest
    static void testCompletarExpedienteMbtDesdeTnId() {
        Test_TestUtils.disableFlows();
        CuentaGranariaTriggerHandler.HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = false;

        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c(
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Cuenta_Granaria__c = cg.Id,
            Tipo_expendiente__c = 'EXP',
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );
        insert expediente;

        Tonelada__c tn = new Tonelada__c(
            Productor__c = cg.Productor__c,
            Cultivo__c = cg.Cultivo__c,
            Cantidad__c = 10,
            Cuenta_Granaria__c = cg.Id,
            Origen__c = 'BolsaTech',
            Expediente_de_Negativos__c = expediente.Id
        );
        insert tn;

        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Id = :cg.Productor__c];
        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Estado__c = 'Creado',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'Enlist',
            CTG__c = 'CTG-MBT-DESDE-TNID-001',
            Codigo_de_Muestra__c = 'MUE-MBT-DESDE-TNID-001',
            Peso_Neto__c = 100,
            CUIT_Titular__c = productor.N_CUIT__c,
            Cuit_Destinatario__c = productor.N_CUIT__c,
            TN_Id__c = tn.Id
        );
        insert mbt;

        Test.startTest();
        CuentaGranariaExpedienteService.VinculacionExpedienteResult resultado =
            CuentaGranariaExpedienteService.completarExpedienteMbtDesdeTnId();
        Test.stopTest();

        System.assertEquals(1, resultado.expedientesEncontrados);
        System.assertEquals(1, resultado.movimientosActualizados);
        System.assertEquals(
            expediente.Id,
            [SELECT Expediente_de_Negativos__c FROM Movimiento_BolsaTech__c WHERE Id = :mbt.Id].Expediente_de_Negativos__c
        );
    }

    @IsTest
    static void testSincronizarMbtDesdeToneladasPorIds() {
        Test_TestUtils.disableFlows();
        CuentaGranariaTriggerHandler.HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = false;

        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c(
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Cuenta_Granaria__c = cg.Id,
            Tipo_expendiente__c = 'EXP',
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );
        insert expediente;

        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Id = :cg.Productor__c];
        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Estado__c = 'Creado',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'Enlist',
            CTG__c = 'CTG-SYNC-TN-IDS-001',
            Codigo_de_Muestra__c = 'MUE-SYNC-TN-IDS-001',
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
            Origen__c = 'BolsaTech',
            Expediente_de_Negativos__c = expediente.Id
        );
        insert tn;

        Test.startTest();
        CuentaGranariaExpedienteService.VinculacionExpedienteResult resultado =
            CuentaGranariaExpedienteService.sincronizarMbtDesdeToneladas(new Set<Id>{ tn.Id });
        Test.stopTest();

        System.assertEquals(1, resultado.movimientosActualizados);
        System.assertEquals(
            expediente.Id,
            [SELECT Expediente_de_Negativos__c FROM Movimiento_BolsaTech__c WHERE Id = :mbt.Id].Expediente_de_Negativos__c
        );
    }

    @IsTest
    static void testSincronizarMbtExpedienteQueueable() {
        Test_TestUtils.disableFlows();
        CuentaGranariaTriggerHandler.HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = false;

        Cuenta_Granaria__c cg = crearCuentaManualNegativa('Enlist E3/Conkesta E3', -4);
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c(
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Cuenta_Granaria__c = cg.Id,
            Tipo_expendiente__c = 'EXP',
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );
        insert expediente;

        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Id = :cg.Productor__c];
        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Estado__c = 'Creado',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'Enlist',
            CTG__c = 'CTG-SYNC-Q-001',
            Codigo_de_Muestra__c = 'MUE-SYNC-Q-001',
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
            Origen__c = 'BolsaTech',
            Expediente_de_Negativos__c = expediente.Id
        );
        insert tn;

        Test.startTest();
        System.enqueueJob(new SincronizarMbtExpedienteQueueable(new Set<Id>{ tn.Id }));
        System.enqueueJob(new SincronizarMbtExpedienteQueueable(null));
        Test.stopTest();

        System.assertEquals(
            expediente.Id,
            [SELECT Expediente_de_Negativos__c FROM Movimiento_BolsaTech__c WHERE Id = :mbt.Id].Expediente_de_Negativos__c
        );
    }
}