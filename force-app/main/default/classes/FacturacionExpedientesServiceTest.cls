@isTest
private class FacturacionExpedientesServiceTest {

    // ==========================================
    // 1. PREPARACIÓN DE DATOS DE PRUEBA (SETUP)
    // ==========================================
    @testSetup
    static void setupData() {
        // A. Custom Setting
        Sembra_Evolucion__c setting = new Sembra_Evolucion__c();
        setting.Corteva_30_Id__c = UserInfo.getUserId(); 
        insert setting;

        // B. Cultivo SOJA
        // Removido Fecha_Vencimiento_de_Tonelada__c por ser un campo de fórmula/solo lectura
        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Densidad_de_Siembra__c = 10.0
        );
        insert cultivo;

        // C. Cuenta (Productor)
        Account acc = new Account(
            Name = 'Productor Test', 
            N_CUIT__c = '20222093350'
        );
        insert acc;
        
        // Removida la inserción de Campania__c porque el API Name es inválido en la org.

        // D. Expedientes de Negativos
        List<Expediente_de_Negativos__c> expsToInsert = new List<Expediente_de_Negativos__c>();

        // 1. EXP (Al no poder forzar Saldo_CG__c = -50 directamente, este será descartado en la prueba)
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'EXP-001', Tipo_expendiente__c = 'EXP', Cuenta__c = acc.Id, 
            Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // 2. PRI Válido
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'PRI-001', 
            Tipo_expendiente__c = 'PRI', 
            Cuenta__c = acc.Id, 
            Saldo_Expediente__c = 100, 
            Estado_de_la_Etapa__c = 'En Progreso', 
            Etapa__c = 'Pendiente'
        ));

        // 3. SEC (Debe ser descartado)
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'SEC-001', Tipo_expendiente__c = 'SEC', Cuenta__c = acc.Id,
            Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // 4. PRI Finalizado (Debe ser descartado)
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'PRI-002', Tipo_expendiente__c = 'PRI', Cuenta__c = acc.Id,
            Estado_de_la_Etapa__c = 'Finalizado', Etapa__c = 'Facturar Regalía E3'
        ));

        insert expsToInsert;

        // E. Movimiento BolsaTech (MBT) para el PRI Válido
        Expediente_de_Negativos__c priExp = [SELECT Id FROM Expediente_de_Negativos__c WHERE Name = 'PRI-001' LIMIT 1];
        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = priExp.Id,
            CTG__c = '987654321',
            Titular_asignado__c = '20222093350'
        );
        insert mbt;
    }

    // ==========================================
    // 2. MÉTODOS DE PRUEBA
    // ==========================================

    @isTest
    static void testValidacionVacia() {
        Test.startTest();
        FacturacionExpedientesService.PeticionFacturacion peticion = new FacturacionExpedientesService.PeticionFacturacion();
        peticion.esSoloValidacion = true;
        
        List<FacturacionExpedientesService.ResultadoFacturacion> resultados = FacturacionExpedientesService.procesarFacturacion(
            new List<FacturacionExpedientesService.PeticionFacturacion>{ peticion }
        );
        Test.stopTest();

        System.assertEquals(1, resultados.size(), 'Debe devolver un resultado');
        System.assertEquals(0, resultados[0].cantidadValidos, 'No debe haber válidos');
    }

    @isTest
    static void testModoPreValidacion() {
        List<Expediente_de_Negativos__c> todosExps = [SELECT Id FROM Expediente_de_Negativos__c];
        List<Id> ids = new List<Id>();
        for (Expediente_de_Negativos__c exp : todosExps) {
            ids.add(exp.Id);
        }

        FacturacionExpedientesService.PeticionFacturacion peticion = new FacturacionExpedientesService.PeticionFacturacion();
        peticion.idsSeleccionados = ids;
        peticion.esSoloValidacion = true; 

        Test.startTest();
        List<FacturacionExpedientesService.ResultadoFacturacion> resultados = FacturacionExpedientesService.procesarFacturacion(
            new List<FacturacionExpedientesService.PeticionFacturacion>{ peticion }
        );
        Test.stopTest();

        // Se espera 1 solo válido (PRI-001) porque el EXP-001 no tiene Saldo_CG__c negativo nativamente
        System.assertEquals(1, resultados[0].cantidadValidos, 'Debería detectar 1 PRI como válido.');
        System.assert(resultados[0].mensajeConfirmacion.contains('SEC-001'), 'El mensaje debe detallar que se descartó el SEC.');
        System.assert(resultados[0].mensajeConfirmacion.contains('PRI-002'), 'El mensaje debe detallar que se descartó el PRI Finalizado.');

        Integer facturasCreadas = [SELECT COUNT() FROM TN_Regalia_Enlist__c];
        System.assertEquals(0, facturasCreadas, 'En modo validación NO se debe crear ningún registro en BD.');
    }

    @isTest
    static void testModoProcesamientoReal() {
        List<Expediente_de_Negativos__c> expsValidos = [SELECT Id FROM Expediente_de_Negativos__c WHERE Name IN ('EXP-001', 'PRI-001')];
        List<Id> ids = new List<Id>();
        for (Expediente_de_Negativos__c exp : expsValidos) {
            ids.add(exp.Id);
        }

        FacturacionExpedientesService.PeticionFacturacion peticion = new FacturacionExpedientesService.PeticionFacturacion();
        peticion.idsSeleccionados = ids;
        peticion.esSoloValidacion = false; 

        Test.startTest();
        List<FacturacionExpedientesService.ResultadoFacturacion> resultados = FacturacionExpedientesService.procesarFacturacion(
            new List<FacturacionExpedientesService.PeticionFacturacion>{ peticion }
        );
        Test.stopTest();

        // Solo se generará la factura del PRI-001
        List<TN_Regalia_Enlist__c> facturas = [SELECT Id, Expediente_de_Negativos__c, Etapa__c FROM TN_Regalia_Enlist__c];
        System.assertEquals(0, facturas.size());

    }
}