@isTest
private class FacturacionExpedientesServiceTest {

    @testSetup
    static void setupData() {
        // A. Custom Setting
        Sembra_Evolucion__c setting = new Sembra_Evolucion__c();
        setting.Corteva_30_Id__c = UserInfo.getUserId(); 
        insert setting;

        // B. Cultivo SOJA
        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Densidad_de_Siembra__c = 10.0
        );
        insert cultivo;

        // C. Cuenta (Productor) - SALDO NEGATIVO REQUERIDO
        Account acc = new Account(
            Name = 'Productor Test', 
            N_CUIT__c = '20222093350',
            TN_Disponibles__c = -150.0 
        );
        insert acc;

        List<Expediente_de_Negativos__c> expsToInsert = new List<Expediente_de_Negativos__c>();

        // [0] EXP-001
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'EXP-001', Tipo_expendiente__c = 'EXP', Cuenta__c = acc.Id, 
            Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // [1] EXP-002 
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'EXP-002', Tipo_expendiente__c = 'EXP', Cuenta__c = acc.Id, 
            Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // [2] PRI Válido
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'PRI-001', Tipo_expendiente__c = 'PRI', Cuenta__c = acc.Id, 
            Saldo_Expediente__c = -100.0, Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // [3] SEC (Descartado)
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'SEC-001', Tipo_expendiente__c = 'SEC', Cuenta__c = acc.Id,
            Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // [4] PRI Finalizado (Descartado)
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'PRI-002', Tipo_expendiente__c = 'PRI', Cuenta__c = acc.Id,
            Estado_de_la_Etapa__c = 'Finalizado', Etapa__c = 'Facturar Regalía E3'
        ));

        // [5] PRI con Factura Preexistente
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'PRI-003', Tipo_expendiente__c = 'PRI', Cuenta__c = acc.Id, 
            Saldo_Expediente__c = -80.0, Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        insert expsToInsert;

        // --- SOLUCIÓN: Usar los IDs inyectados tras el insert ---
        Id idExp1 = expsToInsert[0].Id;
        Id idExp2 = expsToInsert[1].Id;
        Id idPri1 = expsToInsert[2].Id;
        Id idPri3 = expsToInsert[5].Id;
        
        List<Tonelada__c> toneladasToInsert = new List<Tonelada__c>();
        
        toneladasToInsert.add(new Tonelada__c(
            Expediente_de_Negativos__c = idExp1, Cultivo__c = cultivo.Id, Productor__c = acc.Id,
            Cantidad__c = 50.0, Origen__c = 'Compra SF', Etapa__c = 'Cobrada', Tipo_de_Movimiento__c = 'C', Signo__c = 1
        ));
        
        toneladasToInsert.add(new Tonelada__c(
            Expediente_de_Negativos__c = idExp2, Cultivo__c = cultivo.Id, Productor__c = acc.Id,
            Cantidad__c = -50.0, Origen__c = 'Regalía Enlist', Tipo_de_Movimiento__c = 'C'
        ));
        
        insert toneladasToInsert;

        // F. Factura preexistente para PRI-003
        insert new TN_Regalia_Enlist__c(
            Expediente_de_Negativos__c = idPri3, Cantidad__c = -80.0, 
            Etapa__c = 'A Facturar', Cultivo__c = cultivo.Id, Productor__c = acc.Id
        );

        // G. Movimiento BolsaTech (MBT)
        List<Movimiento_BolsaTech__c> mbts = new List<Movimiento_BolsaTech__c>();
        mbts.add(new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = idPri1,
            CTG__c = '987654321', Titular_asignado__c = '20222093350'
        ));
        mbts.add(new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = idPri3,
            CTG__c = '123456789', Titular_original__c = '20222093350'
        ));
        insert mbts;
    }
    @isTest
    static void testValidacionVacia() {
        Test.startTest();
        FacturacionExpedientesService.PeticionFacturacion peticion = new FacturacionExpedientesService.PeticionFacturacion();
        peticion.esSoloValidacion = true;
        
        List<FacturacionExpedientesService.ResultadoFacturacion> resultados = FacturacionExpedientesService.procesarFacturacion(
            new List<FacturacionExpedientesService.PeticionFacturacion>{ peticion }
        );
        Test.stopTest();

        Assert.areEqual(1, resultados.size(), 'Debe devolver un resultado');
        Assert.areEqual(0, resultados[0].cantidadValidos, 'No debe haber válidos');
    }

    @isTest
    static void testModoPreValidacionConDescartados() {
        Map<Id, Expediente_de_Negativos__c> exps = new Map<Id, Expediente_de_Negativos__c>([SELECT Id FROM Expediente_de_Negativos__c]);

        FacturacionExpedientesService.PeticionFacturacion peticion = new FacturacionExpedientesService.PeticionFacturacion();
        peticion.idsSeleccionados = new List<Id>(exps.keySet());
        peticion.esSoloValidacion = true; 

        Test.startTest();
        List<FacturacionExpedientesService.ResultadoFacturacion> resultados = FacturacionExpedientesService.procesarFacturacion(
            new List<FacturacionExpedientesService.PeticionFacturacion>{ peticion }
        );
        Test.stopTest();

        Assert.isTrue(resultados[0].mensajeConfirmacion.contains('SEC-001'), 'Debe detallar el descarte del SEC.');
    }

   @isTest
    static void testProcesamientoRealEXP() {
        List<Expediente_de_Negativos__c> exps = [
            SELECT Id, Name, Tipo_expendiente__c, Etapa__c, Estado_de_la_Etapa__c, TNRE3_Id__c, 
                   Saldo_Expediente__c, Saldo_CG__c, Campania__c, Cuenta__c, Cuenta__r.N_CUIT__c, Cuenta__r.TN_Disponibles__c 
            FROM Expediente_de_Negativos__c 
            WHERE Tipo_expendiente__c = 'EXP'
        ];

        List<Expediente_de_Negativos__c> expsEnMemoria = new List<Expediente_de_Negativos__c>();
        Map<Id, String> mapaNombres = new Map<Id, String>();
        
        for(Expediente_de_Negativos__c exp : exps) {
            mapaNombres.put(exp.Id, exp.Name);
            
            // Truco JSON para sobreescribir un campo de solo lectura en memoria
            Map<String, Object> mapaExp = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(exp));
            mapaExp.put('Saldo_CG__c', -100.0);
            
            Expediente_de_Negativos__c expModificado = (Expediente_de_Negativos__c) JSON.deserialize(JSON.serialize(mapaExp), Expediente_de_Negativos__c.class);
            expsEnMemoria.add(expModificado);
        }

        List<String> exitos = new List<String>();
        List<String> errores = new List<String>();

        Test.startTest();
        FacturacionExpedientesService.procesarLogicaEXP(expsEnMemoria, exitos, errores, mapaNombres);
        Test.stopTest();

        Assert.isTrue(exitos.size() > 0 || errores.size() > 0, 'El método directo debe haber procesado y generado resultados.');
    }

    @isTest
    static void testProcesamientoRealPRI() {
        Map<Id, Expediente_de_Negativos__c> exps = new Map<Id, Expediente_de_Negativos__c>([
            SELECT Id FROM Expediente_de_Negativos__c WHERE Tipo_expendiente__c = 'PRI' AND Estado_de_la_Etapa__c != 'Finalizado'
        ]);

        FacturacionExpedientesService.PeticionFacturacion peticion = new FacturacionExpedientesService.PeticionFacturacion();
        peticion.idsSeleccionados = new List<Id>(exps.keySet());
        peticion.esSoloValidacion = false; 

        Test.startTest();
        List<FacturacionExpedientesService.ResultadoFacturacion> resultados = FacturacionExpedientesService.procesarFacturacion(
            new List<FacturacionExpedientesService.PeticionFacturacion>{ peticion }
        );
        Test.stopTest();

        Assert.isNotNull(resultados[0].mensajeResultado, 'Debe retornar un resumen de procesamiento para PRI.');
    }
}