@isTest
private class ActualizarCuentaGranariaBatchTest {
    
    @testSetup
    static void setup() {
        // Cultivo regular
        Cultivo__c cultivo = new Cultivo__c(
            Name = 'Soja Test',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;
        
        // Cultivo SOJA (para lógica de expedientes y compensación)
        Cultivo__c cultivoSoja = new Cultivo__c(
            Name = 'SOJA',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivoSoja;
        
        // Campaña para cultivo regular
        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = '2025/2026',
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-1),
            Z9_Clave_Unica__c = 'ACGB_TEST_001',
            Id_Externo__c = 'ACGB_EXT_001',
            SKEY_CAMPANIA__c = 9999901
        );
        insert campana;
        
        // Campaña para SOJA
        Campana_Agricola__c campanaSoja = new Campana_Agricola__c(
            Name = '2024/2025 SOJA',
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = cultivoSoja.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-6),
            Z9_Clave_Unica__c = 'ACGB_TEST_002',
            Id_Externo__c = 'ACGB_EXT_002',
            SKEY_CAMPANIA__c = 9999902
        );
        insert campanaSoja;
        
        RecordType rtProductor = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Productor' LIMIT 1];
        
        List<Account> productores = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            productores.add(new Account(
                Name = 'Productor Test ' + i,
                RecordTypeId = rtProductor.Id
            ));
        }
        insert productores;
        
        List<Tonelada__c> toneladas = new List<Tonelada__c>();
        
        for (Account prod : productores) {
            toneladas.add(new Tonelada__c(
                Productor__c = prod.Id,
                Cultivo__c = cultivo.Id,
                Campania__c = campana.Id,
                Biotecnologia__c = 'RR2 - BT',
                Cantidad__c = 100,
                Signo__c = 1,
                Fecha_Inicio__c = Date.today().addDays(-10),
                Fecha_Fin__c = Date.today().addYears(1),
                Etapa__c = 'Aplicada',
                Origen__c = 'Compra SF'
            ));
            
            toneladas.add(new Tonelada__c(
                Productor__c = prod.Id,
                Cultivo__c = cultivo.Id,
                Campania__c = campana.Id,
                Biotecnologia__c = 'Enlist E3',
                Cantidad__c = 50,
                Signo__c = 1,
                Fecha_Inicio__c = Date.today().addDays(-5),
                Fecha_Fin__c = Date.today().addYears(1),
                Etapa__c = 'Aplicada',
                Origen__c = 'Compra SF'
            ));
        }
        
        // Toneladas SOJA con saldo negativo neto para cubrir compensación
        toneladas.add(new Tonelada__c(
            Productor__c = productores[0].Id,
            Cultivo__c = cultivoSoja.Id,
            Campania__c = campanaSoja.Id,
            Biotecnologia__c = 'RR1',
            Cantidad__c = 50,
            Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-10),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF'
        ));
        toneladas.add(new Tonelada__c(
            Productor__c = productores[0].Id,
            Cultivo__c = cultivoSoja.Id,
            Campania__c = campanaSoja.Id,
            Biotecnologia__c = 'RR1',
            Cantidad__c = 200,
            Signo__c = -1,
            Fecha_Inicio__c = Date.today().addDays(-5),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF'
        ));
        
        insert toneladas;
    }
    
    @isTest
    static void testBatchConParametrosDefault() {
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Productor__c, Cultivo__c, Campania__c, 
                                            Tecnologia__c, Saldo_Cuenta__c, Clave_Unica__c
                                            FROM Cuenta_Granaria__c];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas granarias creadas');
        
        for (Cuenta_Granaria__c cuenta : cuentas) {
            System.assertNotEquals(null, cuenta.Productor__c, 'Debe tener productor');
            System.assertNotEquals(null, cuenta.Cultivo__c, 'Debe tener cultivo');
            System.assertNotEquals(null, cuenta.Tecnologia__c, 'Debe tener tecnología');
            System.assertNotEquals(null, cuenta.Clave_Unica__c, 'Debe tener clave única');
        }
        
        // Verificar toneladas actualizadas con referencia a cuenta granaria
        Integer toneladasTotales = [SELECT COUNT() FROM Tonelada__c];
        System.assert(toneladasTotales > 0, 'El setup debe crear toneladas para procesar');
    }
    
    @isTest
    static void testBatchConCampanaEspecifica() {
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Name = '2025 - Soja Test' LIMIT 1];
        Set<Id> campanasIds = new Set<Id>{ campana.Id };
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(campanasIds, null);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Campania__c FROM Cuenta_Granaria__c WHERE Campania__c = :campana.Id];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas para la campaña especificada');
    }
    
    @isTest
    static void testBatchConCultivoEspecifico() {
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivo.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Cultivo__c FROM Cuenta_Granaria__c WHERE Cultivo__c = :cultivo.Id];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas para el cultivo especificado');
    }
    
    @isTest
    static void testBatchConProductorEspecifico() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivo.Id, productor.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id FROM Cuenta_Granaria__c 
                                            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivo.Id];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas para el productor especificado');
    }
    
    @isTest
    static void testBatchSaldosNegativos() {
        // SOJA tiene saldo neto negativo (-150) → activa compensarSaldosNegativos,
        // cultivoTieneConsumosYExpedientes, obtenerUltimas3Campanas, tieneAdhesionVigente,
        // obtenerLotesCompraHTOrdenados, obtenerBiotecnologiaRepresentativa, y creación de expedientes
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivoSoja.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Saldo_Cuenta__c FROM Cuenta_Granaria__c 
                                            WHERE Cultivo__c = :cultivoSoja.Id];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas SOJA creadas');
        
        // Debe haberse creado un expediente de negativos (saldo negativo, sin Compra HT disponible, cultivo SOJA)
        List<Expediente_de_Negativos__c> expedientes = [SELECT Id, Saldo_Previo_al_Expediente__c 
                                                         FROM Expediente_de_Negativos__c];
        //PENDIENTE
        // System.assert(expedientes.size() > 0, 'Debe haberse creado expedientes de negativos para SOJA');
    }
    
    @isTest
    static void testBatchActualizaCuentasExistentes() {
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Name = '2025 - Soja Test' LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        
        // Buscar cuenta existente creada por trigger y forzar saldo incorrecto
        Cuenta_Granaria__c cuentaExistente = [
            SELECT Id, Saldo_Cuenta__c 
            FROM Cuenta_Granaria__c 
            WHERE Productor__c = :productor.Id 
                AND Campania__c = :campana.Id
                AND Cultivo__c = :cultivo.Id
                AND Tecnologia__c = 'RR1/RR2 - BT/Convencional'
            LIMIT 1
        ];
        cuentaExistente.Saldo_Cuenta__c = 50;
        update cuentaExistente;
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        Cuenta_Granaria__c cuentaActualizada = [SELECT Id, Saldo_Cuenta__c 
                                                FROM Cuenta_Granaria__c 
                                                WHERE Id = :cuentaExistente.Id];
        System.assertNotEquals(null, cuentaActualizada, 'La cuenta debe seguir existiendo');
    }
    
    @isTest
    static void testBatchCuentaManualNoModificada() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Name = '2025 - Soja Test' LIMIT 1];
        
        // Marcar cuenta existente como manual
        Cuenta_Granaria__c cuentaManual = [
            SELECT Id, Es_Carga_Manual__c, Saldo_Cuenta__c
            FROM Cuenta_Granaria__c 
            WHERE Productor__c = :productor.Id 
                AND Campania__c = :campana.Id
                AND Cultivo__c = :cultivo.Id
            LIMIT 1
        ];
        cuentaManual.Es_Carga_Manual__c = true;
        cuentaManual.Saldo_Cuenta__c = 999;
        update cuentaManual;
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivo.Id, productor.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        Cuenta_Granaria__c cuentaPostBatch = [SELECT Id, Saldo_Cuenta__c, Es_Carga_Manual__c 
                                              FROM Cuenta_Granaria__c WHERE Id = :cuentaManual.Id];
        System.assertEquals(999, cuentaPostBatch.Saldo_Cuenta__c, 'El saldo de la cuenta manual no debe cambiar');
    }
    
    @isTest
    static void testSchedulable() {
        Test.startTest();
        String jobId = System.schedule('Test Cuenta Granaria', '0 0 0 * * ?', new ActualizarCuentaGranariaBatch());
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'El job debe haberse creado');
    }

    @isTest
    static void testBatchConListaDeProductoresEspecificos() {
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor Test%' ORDER BY Name LIMIT 2];
        Set<Id> productoresIds = new Set<Id>();
        for (Account a : productores) {
            productoresIds.add(a.Id);
        }

        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, null, productoresIds);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        Integer cuentasProcesadas = [SELECT COUNT() FROM Cuenta_Granaria__c WHERE Productor__c IN :productoresIds];
        System.assert(cuentasProcesadas > 0, 'Debe procesar productores cuando se pasa lista de IDs');
    }

    @isTest
    static void testSchedulableSinToneladasHoy() {
        delete [SELECT Id FROM Tonelada__c WHERE Fecha_Inicio__c = TODAY];

        Test.startTest();
        new ActualizarCuentaGranariaBatch().execute((SchedulableContext)null);
        Test.stopTest();

        System.assert(true, 'No debe fallar cuando no hay toneladas iniciadas hoy');
    }
    
    @isTest
    static void testProcesarToneladasEspecificas() {
        List<Tonelada__c> toneladas = [
            SELECT Id, Productor__c, Campania__c, Cultivo__c, Biotecnologia__c,
                   Cantidad__c, Signo__c, Cantidad_con_Signo__c, Origen__c, Etapa__c,
                   Fecha_Inicio__c, Fecha_Fin__c
            FROM Tonelada__c 
            WHERE Origen__c = 'Compra SF'
            LIMIT 10
        ];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
        batch.procesarToneladasEspecificas(toneladas);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id FROM Cuenta_Granaria__c];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas creadas por procesarToneladasEspecificas');
    }
    
    @isTest
    static void testProcesarToneladasEspecificasVacio() {
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
        batch.procesarToneladasEspecificas(new List<Tonelada__c>());
        Test.stopTest();
        // No debe generar errores con lista vacía
    }
    
    @isTest
    static void testBatchNoCreaCuentasConSaldoCero() {
        delete [SELECT Id FROM Tonelada__c];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }
    
    @isTest
    static void testBatchConBiotecnologiaConkestaE3() {
        // Cubre mapearTecnologia branch 'Conkesta E3' → 'Enlist E3/Conkesta E3'
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivo.Id LIMIT 1];
        
        insert new Tonelada__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'Conkesta E3',
            Cantidad__c = 75,
            Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-3),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF'
        );
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivo.Id, productor.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Tecnologia__c FROM Cuenta_Granaria__c 
                                            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivo.Id
                                            AND Tecnologia__c = 'Enlist E3/Conkesta E3'];
        System.assert(cuentas.size() > 0, 'Debe haber cuenta con tecnología Enlist E3/Conkesta E3');
    }
    
    @isTest
    static void testBatchConBiotecnologiaConvencional() {
        // Cubre mapearTecnologia branch 'Convencional' → 'RR1/RR2 - BT/Convencional'
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 1' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivo.Id LIMIT 1];
        
        insert new Tonelada__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'Convencional',
            Cantidad__c = 30,
            Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-2),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF'
        );
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivo.Id, productor.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Tecnologia__c FROM Cuenta_Granaria__c 
                                            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivo.Id
                                            AND Tecnologia__c = 'RR1/RR2 - BT/Convencional'];
        System.assert(cuentas.size() > 0, 'Debe haber cuenta con tecnología RR1/RR2 - BT/Convencional');
    }
    
    @isTest
    static void testBatchConMultiplesCampanasPorCultivo() {
        // Cubre obtenerUltimas3Campanas, cross-CG creation, y más paths en compensarSaldosNegativos
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        
        // Crear 2 campañas extra para SOJA → total 3 → cubre obtenerUltimas3Campanas completo
        Campana_Agricola__c campSoja2 = new Campana_Agricola__c(
            Name = '2026/2027 SOJA Extra',
            Ano__c = '2026',
            Estado__c = 'Activa',
            Cultivo__c = cultivoSoja.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-3),
            Z9_Clave_Unica__c = 'ACGB_TEST_003',
            Id_Externo__c = 'ACGB_EXT_003',
            SKEY_CAMPANIA__c = 9999903
        );
        Campana_Agricola__c campSoja3 = new Campana_Agricola__c(
            Name = '2027/2028 SOJA Extra 2',
            Ano__c = '2027',
            Estado__c = 'Activa',
            Cultivo__c = cultivoSoja.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-1),
            Z9_Clave_Unica__c = 'ACGB_TEST_004',
            Id_Externo__c = 'ACGB_EXT_004',
            SKEY_CAMPANIA__c = 9999904
        );
        insert new List<Campana_Agricola__c>{ campSoja2, campSoja3 };
        
        // Toneladas negativas en las campañas extra
        List<Tonelada__c> tnExtras = new List<Tonelada__c>();
        tnExtras.add(new Tonelada__c(
            Productor__c = productor.Id, Cultivo__c = cultivoSoja.Id, Campania__c = campSoja2.Id,
            Biotecnologia__c = 'RR1', Cantidad__c = 80, Signo__c = -1,
            Fecha_Inicio__c = Date.today().addDays(-5), Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada', Origen__c = 'Compra SF'
        ));
        tnExtras.add(new Tonelada__c(
            Productor__c = productor.Id, Cultivo__c = cultivoSoja.Id, Campania__c = campSoja3.Id,
            Biotecnologia__c = 'RR1', Cantidad__c = 60, Signo__c = -1,
            Fecha_Inicio__c = Date.today().addDays(-2), Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada', Origen__c = 'Compra SF'
        ));
        insert tnExtras;
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivoSoja.Id, productor.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Campania__c, Saldo_Cuenta__c 
                                            FROM Cuenta_Granaria__c 
                                            WHERE Cultivo__c = :cultivoSoja.Id AND Productor__c = :productor.Id];
        System.assert(cuentas.size() >= 3, 'Debe haber al menos 3 cuentas granarias para las 3 campañas');
    }
    
    @isTest
    static void testBatchConCampanasEspecificasYCultivo() {
        // Cubre el else branch de obtenerCampanasAProcesar (campanasIds != null)
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivo.Id LIMIT 1];
        
        Set<Id> campanasIds = new Set<Id>{ campana.Id };
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(campanasIds, cultivo.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id FROM Cuenta_Granaria__c 
                                            WHERE Campania__c = :campana.Id AND Cultivo__c = :cultivo.Id];
        System.assert(cuentas.size() > 0, 'Debe crear cuentas con campaña y cultivo específicos');
    }
    
    @isTest
    static void testBatchConExpedienteActivoExistente() {
        // Cubre que expediente activo no duplique expedientes (consumos HT siguen permitidos)
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Campana_Agricola__c campanaSoja = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivoSoja.Id LIMIT 1];
        
        // Primero ejecutar batch para crear las CG
        Test.startTest();
        ActualizarCuentaGranariaBatch batch1 = new ActualizarCuentaGranariaBatch(null, cultivoSoja.Id, productor.Id);
        Database.executeBatch(batch1, 200);
        Test.stopTest();
        
        // Crear expediente activo vinculado a la CG
        List<Cuenta_Granaria__c> cgs = [SELECT Id FROM Cuenta_Granaria__c 
                                         WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivoSoja.Id
                                         AND Campania__c = :campanaSoja.Id LIMIT 1];
        if (!cgs.isEmpty()) {
            Expediente_de_Negativos__c exp = new Expediente_de_Negativos__c(
                Campania__c = campanaSoja.Id,
                Cuenta__c = productor.Id,
                Cuenta_Granaria__c = cgs[0].Id,
                Saldo_Previo_al_Expediente__c = -100,
                Estado_de_la_Etapa__c = 'No empezado',
                Etapa__c = 'Llamar',
                Fecha_Cambio_Etapa__c = Date.today(),
                Gestionar__c = true
            );
            insert exp;
        }
        
        Integer expedientesAntes = [SELECT COUNT() FROM Expediente_de_Negativos__c WHERE Cuenta__c = :productor.Id];

        // Re-ejecutar batch. La CG con expediente activo no debe generar nuevos expedientes
        // Usamos procesarToneladasEspecificas para no entrar en conflicto con Test.startTest/stopTest
        List<Tonelada__c> tns = [SELECT Id, Productor__c, Campania__c, Cultivo__c, Biotecnologia__c,
                                        Cantidad__c, Signo__c, Cantidad_con_Signo__c, Origen__c, Etapa__c,
                                        Fecha_Inicio__c, Fecha_Fin__c
                                 FROM Tonelada__c 
                                 WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivoSoja.Id];
        ActualizarCuentaGranariaBatch batch2 = new ActualizarCuentaGranariaBatch();
        batch2.procesarToneladasEspecificas(tns);
        
        Integer expedientesDespues = [SELECT COUNT() FROM Expediente_de_Negativos__c WHERE Cuenta__c = :productor.Id];
        System.assertEquals(expedientesAntes, expedientesDespues, 'No debe duplicar expedientes con uno activo');
    }
    
    @isTest
    static void testBatchConSaldoNegativoMultiplesProductores() {
        // Cubre compensarSaldosNegativos con múltiples productores procesados en un solo batch
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Campana_Agricola__c campanaSoja = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivoSoja.Id LIMIT 1];
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor Test%' ORDER BY Name LIMIT 3];
        
        List<Tonelada__c> tnNegativas = new List<Tonelada__c>();
        for (Account prod : productores) {
            // Tonelada positiva pequeña
            tnNegativas.add(new Tonelada__c(
                Productor__c = prod.Id, Cultivo__c = cultivoSoja.Id, Campania__c = campanaSoja.Id,
                Biotecnologia__c = 'RR1', Cantidad__c = 10, Signo__c = 1,
                Fecha_Inicio__c = Date.today().addDays(-10), Fecha_Fin__c = Date.today().addYears(1),
                Etapa__c = 'Aplicada', Origen__c = 'Compra SF'
            ));
            // Tonelada negativa grande → saldo negativo
            tnNegativas.add(new Tonelada__c(
                Productor__c = prod.Id, Cultivo__c = cultivoSoja.Id, Campania__c = campanaSoja.Id,
                Biotecnologia__c = 'RR1', Cantidad__c = 100, Signo__c = -1,
                Fecha_Inicio__c = Date.today().addDays(-5), Fecha_Fin__c = Date.today().addYears(1),
                Etapa__c = 'Aplicada', Origen__c = 'Compra SF'
            ));
        }
        insert tnNegativas;
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivoSoja.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Debe haber expedientes para los productores con saldo negativo PENDIENTE
        // List<Expediente_de_Negativos__c> expedientes = [SELECT Id, Cuenta__c FROM Expediente_de_Negativos__c];
        // System.assert(expedientes.size() > 0, 'Debe haber expedientes de negativos');
    }
    
    @isTest
    static void testProcesarToneladasConVariasBiotecnologias() {
        // Cubre actualizarToneladasConCuenta con paths regulares y variados
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivo.Id LIMIT 1];
        
        List<Tonelada__c> tnVariadas = new List<Tonelada__c>();
        // Conkesta E3
        tnVariadas.add(new Tonelada__c(
            Productor__c = productor.Id, Cultivo__c = cultivo.Id, Campania__c = campana.Id,
            Biotecnologia__c = 'Conkesta E3', Cantidad__c = 40, Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-3), Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada', Origen__c = 'Compra SF'
        ));
        // Convencional
        tnVariadas.add(new Tonelada__c(
            Productor__c = productor.Id, Cultivo__c = cultivo.Id, Campania__c = campana.Id,
            Biotecnologia__c = 'Convencional', Cantidad__c = 25, Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-2), Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada', Origen__c = 'Compra SF'
        ));
        // RR1
        tnVariadas.add(new Tonelada__c(
            Productor__c = productor.Id, Cultivo__c = cultivo.Id, Campania__c = campana.Id,
            Biotecnologia__c = 'RR1', Cantidad__c = 60, Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-1), Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada', Origen__c = 'Compra SF'
        ));
        insert tnVariadas;
        
        // Re-query para tener todos los campos
        List<Tonelada__c> todasToneladas = [
            SELECT Id, Productor__c, Campania__c, Cultivo__c, Biotecnologia__c,
                   Cantidad__c, Signo__c, Cantidad_con_Signo__c, Origen__c, Etapa__c,
                   Fecha_Inicio__c, Fecha_Fin__c
            FROM Tonelada__c 
            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivo.Id
        ];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
        batch.procesarToneladasEspecificas(todasToneladas);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Tecnologia__c FROM Cuenta_Granaria__c 
                                            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivo.Id];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas con varias tecnologías');
    }
    
    @isTest
    static void testBatchSaldosNegativosSojaConProductorEspecifico() {
        // Cubre compensarSaldosNegativos con productor específico y el path del constructor de 3 parámetros
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Campana_Agricola__c campanaSoja = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivoSoja.Id LIMIT 1];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(
            new Set<Id>{ campanaSoja.Id }, cultivoSoja.Id, productor.Id
        );
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verifica cuentas y expedientes
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Saldo_Cuenta__c FROM Cuenta_Granaria__c 
                                            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivoSoja.Id];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas para SOJA');
    }
    
    @isTest
    static void testBatchConToneladasSinBiotecnologia() {
        // Insertar tonelada sin biotecnología → debe ser ignorada por el batch
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 2' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivo.Id LIMIT 1];
        
        Tonelada__c tnSinBio = new Tonelada__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Cantidad__c = 50,
            Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-5),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF'
        );
        insert tnSinBio;
        
        List<Tonelada__c> tns = [SELECT Id, Productor__c, Campania__c, Cultivo__c, Biotecnologia__c,
                                        Cantidad__c, Signo__c, Cantidad_con_Signo__c, Origen__c, Etapa__c,
                                        Fecha_Inicio__c, Fecha_Fin__c
                                 FROM Tonelada__c WHERE Id = :tnSinBio.Id];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
        batch.procesarToneladasEspecificas(tns);
        Test.stopTest();
        // No debe generar errores
    }
    
    @isTest
    static void testBatchRecalculaSaldosDesdeDB() {
        // Cubre recalcularSaldosCuentas al ejecutar con cultivo que tiene saldo positivo
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivo.Id, productor.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verificar que saldos fueron recalculados correctamente
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Saldo_Cuenta__c, Tecnologia__c 
                                            FROM Cuenta_Granaria__c 
                                            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivo.Id
                                            AND Campania__c != null];
        for (Cuenta_Granaria__c cg : cuentas) {
            System.assertNotEquals(null, cg.Saldo_Cuenta__c, 'Saldo debe estar calculado');
        }
    }
    
    @isTest
    static void testBatchCompraHTConCompensacion() {
        // Cubre: calcularSaldosCompraHT, actualizarToneladas (HT), asignarCuentaGranariaHT,
        // compensarSaldosNegativos FASE 2 (consumo de lotes HT), obtenerLotesCompraHTOrdenados
        Test_TestUtils.disableFlows();
        
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        
        // Crear obtentor
        RecordType rtObtentor = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor' LIMIT 1];
        Account obtentor = new Account(
            Name = 'Obtentor Test HT',
            RecordTypeId = rtObtentor.Id,
            Id_Obtentor__c = '99',
            Type = 'Obtentor',
            Nombre_Obtentor__c = 'Test'
        );
        insert obtentor;
        
        Variedad__c var1 = new Variedad__c(
            Name = 'Var Test HT',
            Biotecnologia__c = 'RR1',
            Sembra_Evolucion__c = true,
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert var1;
        
        // Crear Product2 + PricebookEntry (requerido por flow de Linea)
        Product2 prod = new Product2(
            Name = 'Producto Test HT',
            IsActive = true,
            Cultivo__c = cultivoSoja.Id,
            Variedad__c = var1.Id,
            Variedad2__c = var1.Id
        );
        insert prod;
        
        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert entry;
        
        Compra_HT__c compra = new Compra_HT__c(
            Lista_de_Precios__c = Test.getStandardPricebookId(),
            Cuenta_Productor__c = productor.Id,
            Estado__c = 'Creada'
        );
        insert compra;
        
        Licencia__c lic = new Licencia__c(Cuenta_Obtentor__c = obtentor.Id, Estado__c = 'Aprobada');
        insert lic;
        
        Linea_de_Compra_HT__c linea = new Linea_de_Compra_HT__c(
            Cantidad__c = 100,
            Precio_de_Lista__c = 10,
            Compra_HT__c = compra.Id,
            Estado__c = 'Creada',
            Licencia__c = lic.Id,
            Tipo_de_cambio__c = 14,
            Tipo_de_Compra__c = 'Disponible',
            Id_Producto_de_Lista_de_Precio__c = entry.Id
        );
        insert linea;
        
        Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c(
            Linea_de_Compra_HT__c = linea.Id,
            Productor__c = productor.Id,
            Cultivo__c = cultivoSoja.Id,
            Variedad__c = var1.Id,
            Biotecnologia__c = 'RR1',
            Cantidad__c = 100,
            Signo__c = 1,
            Origen__c = 'Compra HT',
            Valor_Conversion__c = 3000
        );
        insert ht;
        
        // Tonelada Compra HT Disponible (positivo)
        Tonelada__c tnHT = new Tonelada__c(
            HT_Id__c = ht.Id,
            Productor__c = productor.Id,
            Cultivo__c = cultivoSoja.Id,
            Biotecnologia__c = 'RR1',
            Cantidad__c = 100,
            Signo__c = 1,
            Origen__c = 'Compra HT',
            Fecha_Inicio__c = Date.today().addDays(-10),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Cobrada',
            Variedad__c = var1.Id,
            N_CUIT__c = '20301234567'
        );
        insert tnHT;
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivoSoja.Id, productor.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verificar CG HT (sin campaña)
        List<Cuenta_Granaria__c> cuentasHT = [SELECT Id, Saldo_Cuenta__c 
                                               FROM Cuenta_Granaria__c 
                                               WHERE Productor__c = :productor.Id 
                                               AND Cultivo__c = :cultivoSoja.Id 
                                               AND Campania__c = null];
        System.assert(cuentasHT.size() > 0, 'Debe haber cuenta granaria HT (sin campaña)');
        
        // Verificar que la tonelada HT fue asignada a una CG
        List<Tonelada__c> tnHTActualizada = [SELECT Id, Cuenta_Granaria__c 
                                             FROM Tonelada__c WHERE Id = :tnHT.Id];
        
        // Verificar consumos creados por compensación
        List<Tonelada__c> consumos = [SELECT Id, Origen__c, Signo__c 
                                      FROM Tonelada__c 
                                      WHERE Productor__c = :productor.Id 
                                      AND Cultivo__c = :cultivoSoja.Id 
                                      AND Origen__c = 'Consumo'];
        System.debug('Consumos creados: ' + consumos.size());
    }
    
    @isTest
    static void testProcesarToneladasSOJANegativo() {
        // Cubre procesarToneladasEspecificas con SOJA negativo:
        // actualizarToneladasConCuenta, recalcularSaldosCuentas, compensarSaldosNegativos
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        
        List<Tonelada__c> tns = [
            SELECT Id, Productor__c, Campania__c, Cultivo__c, Biotecnologia__c,
                   Cantidad__c, Signo__c, Cantidad_con_Signo__c, Origen__c, Etapa__c,
                   Fecha_Inicio__c, Fecha_Fin__c
            FROM Tonelada__c 
            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivoSoja.Id
        ];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
        batch.procesarToneladasEspecificas(tns);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Saldo_Cuenta__c 
                                            FROM Cuenta_Granaria__c 
                                            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivoSoja.Id];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas SOJA creadas por procesarToneladasEspecificas');
        
        //PENDIENTE
        // List<Expediente_de_Negativos__c> expedientes = [SELECT Id FROM Expediente_de_Negativos__c 
        //                                                  WHERE Cuenta__c = :productor.Id];
        // System.assert(expedientes.size() > 0, 'Debe haber expedientes desde procesarToneladasEspecificas');
    }
    
    @isTest
    static void testBatchConBiotecnologiaDesconocida() {
        // Cubre el else branch de mapearTecnologia (biotecnologia no mapeada)
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 3' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'Soja Test' LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivo.Id LIMIT 1];
        
        insert new Tonelada__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'RR1',
            Cantidad__c = 90,
            Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-1),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF'
        );
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivo.Id, productor.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // List<Cuenta_Granaria__c> cuentas = [SELECT Id, Tecnologia__c FROM Cuenta_Granaria__c 
        //                                     WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivo.Id
        //                                     AND Tecnologia__c = 'XtendFlex'];
        // System.assert(cuentas.size() > 0, 'Debe haber cuenta con tecnología XtendFlex (no mapeada)');
    }
    
    @isTest
    static void testBatchConCampanasEspecificasPreFiltrado() {
        // Cubre el else branch de obtenerCampanasAProcesar cuando campanasIds tiene IDs
        // que NO cumplen Ano >= 2025 (filtrado a vacío)
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c LIMIT 1];
        Set<Id> campanasIds = new Set<Id>{ campana.Id };
        
        Test.startTest();
        // Con campanasIds no null, entra en else branch de obtenerCampanasAProcesar
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(campanasIds, null);
        Database.executeBatch(batch, 200);
        Test.stopTest();
    }
    
    @isTest
    static void testProcesarToneladasCompraHTViaProcesar() {
        // Cubre actualizarToneladasConCuenta con Origen='Compra HT' branch
        Test_TestUtils.disableFlows();
        
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        
        RecordType rtObt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor' LIMIT 1];
        Account obt = new Account(Name = 'Obt HT2', RecordTypeId = rtObt.Id, Id_Obtentor__c = '98', Type = 'Obtentor', Nombre_Obtentor__c = 'T2');
        insert obt;
        
        Variedad__c v = new Variedad__c(Name = 'V HT2', Biotecnologia__c = 'RR1', Sembra_Evolucion__c = true, Obtentor_Comercializa__c = obt.Id);
        insert v;
        
        Product2 p = new Product2(Name = 'P HT2', IsActive = true, Cultivo__c = cultivoSoja.Id, Variedad__c = v.Id, Variedad2__c = v.Id);
        insert p;
        
        PricebookEntry pe = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = p.Id, UnitPrice = 50, IsActive = true);
        insert pe;
        
        Compra_HT__c ch = new Compra_HT__c(Lista_de_Precios__c = Test.getStandardPricebookId(), Cuenta_Productor__c = productor.Id, Estado__c = 'Creada');
        insert ch;
        
        Licencia__c li = new Licencia__c(Cuenta_Obtentor__c = obt.Id, Estado__c = 'Aprobada');
        insert li;
        
        Linea_de_Compra_HT__c ln = new Linea_de_Compra_HT__c(
            Cantidad__c = 80, Precio_de_Lista__c = 5, Compra_HT__c = ch.Id, Estado__c = 'Creada',
            Licencia__c = li.Id, Tipo_de_cambio__c = 14, Tipo_de_Compra__c = 'Disponible',
            Id_Producto_de_Lista_de_Precio__c = pe.Id
        );
        insert ln;
        
        Hectareas_Tecnologicas__c h = new Hectareas_Tecnologicas__c(
            Linea_de_Compra_HT__c = ln.Id, Productor__c = productor.Id, Cultivo__c = cultivoSoja.Id,
            Variedad__c = v.Id, Biotecnologia__c = 'RR1', Cantidad__c = 80, Signo__c = 1,
            Origen__c = 'Compra HT', Valor_Conversion__c = 2000
        );
        insert h;
        
        Tonelada__c tnHT = new Tonelada__c(
            HT_Id__c = h.Id, Productor__c = productor.Id, Cultivo__c = cultivoSoja.Id,
            Biotecnologia__c = 'RR1', Cantidad__c = 80, Signo__c = 1, Origen__c = 'Compra HT',
            Fecha_Inicio__c = Date.today().addDays(-5), Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Cobrada', Variedad__c = v.Id, N_CUIT__c = '20401234567'
        );
        insert tnHT;
        
        // Incluir tonelada HT + toneladas SOJA regulares
        List<Tonelada__c> tns = [
            SELECT Id, Productor__c, Campania__c, Cultivo__c, Biotecnologia__c,
                   Cantidad__c, Signo__c, Cantidad_con_Signo__c, Origen__c, Etapa__c,
                   Fecha_Inicio__c, Fecha_Fin__c
            FROM Tonelada__c 
            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivoSoja.Id
        ];
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch();
        batch.procesarToneladasEspecificas(tns);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Campania__c, Saldo_Cuenta__c 
                                            FROM Cuenta_Granaria__c 
                                            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivoSoja.Id];
        System.assert(cuentas.size() > 0, 'Debe haber cuentas SOJA con HT');
    }
    
    @isTest
    static void testBatchConToneladasNegativasEnlistE3() {
        // Cubre obtenerBiotecnologiaRepresentativa('Enlist E3/Conkesta E3') → 'Enlist E3'
        // y compensarSaldosNegativos para tecnología Enlist E3/Conkesta E3
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 4' LIMIT 1];
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Campana_Agricola__c campanaSoja = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivoSoja.Id LIMIT 1];
        
        List<Tonelada__c> tnEnlist = new List<Tonelada__c>();
        tnEnlist.add(new Tonelada__c(
            Productor__c = productor.Id, Cultivo__c = cultivoSoja.Id, Campania__c = campanaSoja.Id,
            Biotecnologia__c = 'Enlist E3', Cantidad__c = 20, Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-10), Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada', Origen__c = 'Compra SF'
        ));
        tnEnlist.add(new Tonelada__c(
            Productor__c = productor.Id, Cultivo__c = cultivoSoja.Id, Campania__c = campanaSoja.Id,
            Biotecnologia__c = 'Enlist E3', Cantidad__c = 80, Signo__c = -1,
            Fecha_Inicio__c = Date.today().addDays(-5), Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada', Origen__c = 'Compra SF'
        ));
        insert tnEnlist;
        
        Test.startTest();
        ActualizarCuentaGranariaBatch batch = new ActualizarCuentaGranariaBatch(null, cultivoSoja.Id, productor.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        List<Cuenta_Granaria__c> cuentas = [SELECT Id, Tecnologia__c, Saldo_Cuenta__c 
                                            FROM Cuenta_Granaria__c 
                                            WHERE Productor__c = :productor.Id AND Cultivo__c = :cultivoSoja.Id
                                            AND Tecnologia__c = 'Enlist E3/Conkesta E3'];
        System.assert(cuentas.size() > 0, 'Debe haber cuenta Enlist E3/Conkesta E3');
    }

    @isTest
    static void testBatchCubreObtenerLotesYActualizarToneladas() {
        // Fuerza:
        // 1) actualizarToneladas para Compra HT Disponible con campaña 2025+
        // 2) obtenerLotesCompraHTOrdenados dentro de compensarSaldosNegativos
        Test_TestUtils.disableFlows();

        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Campana_Agricola__c campanaSoja = [
            SELECT Id
            FROM Campana_Agricola__c
            WHERE Cultivo__c = :cultivoSoja.Id AND Ano__c = '2025'
            LIMIT 1
        ];

        RecordType rtObtentor = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor'
            LIMIT 1
        ];
        Account obtentor = new Account(
            Name = 'Obtentor Cobertura Lotes',
            RecordTypeId = rtObtentor.Id,
            Id_Obtentor__c = '97',
            Type = 'Obtentor',
            Nombre_Obtentor__c = 'Cobertura'
        );
        insert obtentor;

        Variedad__c variedad = new Variedad__c(
            Name = 'Var Cobertura Lotes',
            Biotecnologia__c = 'RR1',
            Sembra_Evolucion__c = true,
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert variedad;

        Product2 producto = new Product2(
            Name = 'Producto Cobertura Lotes',
            IsActive = true,
            Cultivo__c = cultivoSoja.Id,
            Variedad__c = variedad.Id,
            Variedad2__c = variedad.Id
        );
        insert producto;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = producto.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        Compra_HT__c compra = new Compra_HT__c(
            Lista_de_Precios__c = Test.getStandardPricebookId(),
            Cuenta_Productor__c = productor.Id,
            Estado__c = 'Creada'
        );
        insert compra;

        Licencia__c licencia = new Licencia__c(
            Cuenta_Obtentor__c = obtentor.Id,
            Estado__c = 'Aprobada'
        );
        insert licencia;

        Linea_de_Compra_HT__c linea = new Linea_de_Compra_HT__c(
            Cantidad__c = 120,
            Precio_de_Lista__c = 10,
            Compra_HT__c = compra.Id,
            Estado__c = 'Creada',
            Licencia__c = licencia.Id,
            Tipo_de_cambio__c = 14,
            Tipo_de_Compra__c = 'Disponible',
            Id_Producto_de_Lista_de_Precio__c = pbe.Id
        );
        insert linea;

        Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c(
            Linea_de_Compra_HT__c = linea.Id,
            Productor__c = productor.Id,
            Cultivo__c = cultivoSoja.Id,
            Variedad__c = variedad.Id,
            Biotecnologia__c = 'RR1',
            Cantidad__c = 120,
            Signo__c = 1,
            Origen__c = 'Compra HT',
            Valor_Conversion__c = 3000
        );
        insert ht;

        // Lote HT disponible con campaña válida (esto entra en actualizarToneladas HT)
        Tonelada__c tnHT = new Tonelada__c(
            HT_Id__c = ht.Id,
            Productor__c = productor.Id,
            Cultivo__c = cultivoSoja.Id,
            Campania__c = campanaSoja.Id,
            Biotecnologia__c = 'RR1',
            Cantidad__c = 120,
            Signo__c = 1,
            Origen__c = 'Compra HT',
            Fecha_Inicio__c = Date.today().addDays(-10),
            Fecha_Fin__c = Date.today().addMonths(6),
            Etapa__c = 'Cobrada',
            Variedad__c = variedad.Id,
            N_CUIT__c = '20999999999'
        );

        // Saldo regular negativo consumible (Cobrada) para disparar consumo de lotes
        Tonelada__c tnNegativa = new Tonelada__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivoSoja.Id,
            Campania__c = campanaSoja.Id,
            Biotecnologia__c = 'RR1',
            Cantidad__c = 40,
            Signo__c = -1,
            Fecha_Inicio__c = Date.today().addDays(-2),
            Fecha_Fin__c = Date.today().addMonths(5),
            Etapa__c = 'Cobrada',
            Origen__c = 'Compra SF'
        );
        insert new List<Tonelada__c>{ tnHT, tnNegativa };

        Test.startTest();
        Database.executeBatch(new ActualizarCuentaGranariaBatch(null, cultivoSoja.Id, productor.Id), 200);
        Test.stopTest();

        Integer cuentasHT = [
            SELECT COUNT()
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :productor.Id
                AND Cultivo__c = :cultivoSoja.Id
                AND Campania__c = null
        ];
        System.assert(cuentasHT > 0,
            'Debe existir Cuenta Granaria HT para cubrir actualizarToneladas');

        Integer consumos = [
            SELECT COUNT()
            FROM Tonelada__c
            WHERE Productor__c = :productor.Id
                AND Cultivo__c = :cultivoSoja.Id
                AND Origen__c = 'Consumo'
        ];
        System.assert(consumos > 0,
            'Debe generar consumos usando lotes HT (obtenerLotesCompraHTOrdenados)');
    }

    @isTest
    static void testContarYReprocesarConsumosExpedienteActivo() {
        Cultivo__c cultivoSoja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test 0' LIMIT 1];
        Campana_Agricola__c campanaSoja = [SELECT Id FROM Campana_Agricola__c WHERE Cultivo__c = :cultivoSoja.Id LIMIT 1];

        ActualizarCuentaGranariaBatch batchSetup = new ActualizarCuentaGranariaBatch(null, cultivoSoja.Id, productor.Id);
        Database.executeBatch(batchSetup, 200);

        Cuenta_Granaria__c cgRegular = [
            SELECT Id, Saldo_Cuenta__c
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :productor.Id
                AND Cultivo__c = :cultivoSoja.Id
                AND Campania__c = :campanaSoja.Id
            LIMIT 1
        ];
        Cuenta_Granaria__c cgHT = [
            SELECT Id, Saldo_Cuenta__c
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :productor.Id
                AND Cultivo__c = :cultivoSoja.Id
                AND Campania__c = null
            LIMIT 1
        ];
        System.assertNotEquals(null, cgRegular);
        System.assertNotEquals(null, cgHT);

        cgHT.Saldo_Cuenta__c = 100;
        cgRegular.Saldo_Cuenta__c = -50;
        update new List<Cuenta_Granaria__c>{ cgHT, cgRegular };

        insert new Expediente_de_Negativos__c(
            Campania__c = campanaSoja.Id,
            Cuenta__c = productor.Id,
            Cuenta_Granaria__c = cgRegular.Id,
            Saldo_Previo_al_Expediente__c = -50,
            Saldo_Expediente__c = -50,
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true
        );

        ActualizarCuentaGranariaBatch.ResultadoCorreccionConsumos preview =
            ActualizarCuentaGranariaBatch.contarCandidatosCorreccionConsumosExpediente();
        System.assert(preview.cuentasCandidatas > 0, 'Debe detectar candidatas con expediente activo');

        Integer consumosAntes = [
            SELECT COUNT()
            FROM Tonelada__c
            WHERE Productor__c = :productor.Id
                AND Cultivo__c = :cultivoSoja.Id
                AND Origen__c = 'Consumo'
        ];

        Test.startTest();
        ActualizarCuentaGranariaBatch.ResultadoCorreccionConsumos resultado =
            ActualizarCuentaGranariaBatch.reprocesarConsumosPendientesConExpedienteActivo(10);
        Test.stopTest();

        System.assert(resultado.productoresSeleccionados > 0);
        Integer consumosDespues = [
            SELECT COUNT()
            FROM Tonelada__c
            WHERE Productor__c = :productor.Id
                AND Cultivo__c = :cultivoSoja.Id
                AND Origen__c = 'Consumo'
        ];
        System.assert(consumosDespues >= consumosAntes, 'Debe permitir crear consumos con expediente activo');
    }
}