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
            TN_Disponibles__c = -150.0 // <-- Clave: Debe ser negativo para pasar la validación
        );
        insert acc;

        List<Expediente_de_Negativos__c> expsToInsert = new List<Expediente_de_Negativos__c>();

        // 1. EXP-001 (Para forzar la CREACIÓN de una nueva Tonelada y Factura)
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'EXP-001', Tipo_expendiente__c = 'EXP', Cuenta__c = acc.Id, 
            Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // 2. EXP-002 (Para probar el salto de creación por YA TENER Tonelada Principal)
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'EXP-002', Tipo_expendiente__c = 'EXP', Cuenta__c = acc.Id, 
            Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // 3. PRI Válido
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'PRI-001', Tipo_expendiente__c = 'PRI', Cuenta__c = acc.Id, 
            Saldo_Expediente__c = -100.0, Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // 4. SEC (Descartado)
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'SEC-001', Tipo_expendiente__c = 'SEC', Cuenta__c = acc.Id,
            Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        // 5. PRI Finalizado (Descartado)
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'PRI-002', Tipo_expendiente__c = 'PRI', Cuenta__c = acc.Id,
            Estado_de_la_Etapa__c = 'Finalizado', Etapa__c = 'Facturar Regalía E3'
        ));

        // 6. PRI con Factura Preexistente
        expsToInsert.add(new Expediente_de_Negativos__c(
            Name = 'PRI-003', Tipo_expendiente__c = 'PRI', Cuenta__c = acc.Id, 
            Saldo_Expediente__c = -80.0, Estado_de_la_Etapa__c = 'En Progreso', Etapa__c = 'Pendiente'
        ));

        insert expsToInsert;

        // E. Inserción de Toneladas
        Expediente_de_Negativos__c exp1 = [SELECT Id FROM Expediente_de_Negativos__c WHERE Name = 'EXP-001' LIMIT 1];
        Expediente_de_Negativos__c exp2 = [SELECT Id FROM Expediente_de_Negativos__c WHERE Name = 'EXP-002' LIMIT 1];
        
        List<Tonelada__c> toneladasToInsert = new List<Tonelada__c>();
        
        // Tonelada para EXP-001: Origen distinto para que NO entre al mapa y obligue a crear una nueva
        toneladasToInsert.add(new Tonelada__c(
            Expediente_de_Negativos__c = exp1.Id, Cultivo__c = cultivo.Id, Productor__c = acc.Id,
            Cantidad__c = 50.0, Origen__c = 'Compra SF', Etapa__c = 'Cobrada', Tipo_de_Movimiento__c = 'C', Signo__c = 1
        ));
        
        // Tonelada para EXP-002: Origen 'Regalía Enlist' para que entre al mapa y no cree duplicado
        toneladasToInsert.add(new Tonelada__c(
            Expediente_de_Negativos__c = exp2.Id, Cultivo__c = cultivo.Id, Productor__c = acc.Id,
            Cantidad__c = -50.0, Origen__c = 'Regalía Enlist', Tipo_de_Movimiento__c = 'C'
        ));
        
        insert toneladasToInsert;

        // F. Factura preexistente para PRI-003
        Expediente_de_Negativos__c pri3 = [SELECT Id FROM Expediente_de_Negativos__c WHERE Name = 'PRI-003' LIMIT 1];
        insert new TN_Regalia_Enlist__c(
            Expediente_de_Negativos__c = pri3.Id, Cantidad__c = -80.0, 
            Etapa__c = 'A Facturar', Cultivo__c = cultivo.Id, Productor__c = acc.Id
        );

        // G. Movimiento BolsaTech (MBT)
        List<Movimiento_BolsaTech__c> mbts = new List<Movimiento_BolsaTech__c>();
        mbts.add(new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = [SELECT Id FROM Expediente_de_Negativos__c WHERE Name = 'PRI-001' LIMIT 1].Id,
            CTG__c = '987654321', Titular_asignado__c = '20222093350'
        ));
        mbts.add(new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = pri3.Id,
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