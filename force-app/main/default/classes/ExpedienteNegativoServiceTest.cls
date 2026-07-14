@IsTest
public class ExpedienteNegativoServiceTest {

    @IsTest
    static void testCrearExpediente() {

        // Crear datos base
        Account cuenta = new Account(Name = 'Cuenta Test');
        insert cuenta;

        Campana_Agricola__c campania = new Campana_Agricola__c(Name = 'Campaña Test');
        insert campania;

        // Preparar request para crear expediente
        ExpedienteNegativoService.Request req = new ExpedienteNegativoService.Request();
        req.cuentaId = cuenta.Id;
        req.nombreExpediente = 'Expediente Test';
        req.tipoExpediente = 'PRI';
        req.toneladas = 5;
        req.obtentorId = null;

        List<ExpedienteNegativoService.Request> requests = new List<ExpedienteNegativoService.Request>{ req };

        Test.startTest();
        List<ExpedienteNegativoService.Response> responses = ExpedienteNegativoService.crearActualizar(requests);
        Test.stopTest();

        // Validar creación del expediente
        System.assertEquals(1, responses.size(), 'Debe retornar una respuesta');

        Expediente_de_Negativos__c exp = [
            SELECT Id, Cuenta__c, Saldo_Expediente__c, Estado_de_la_Etapa__c, Etapa__c
            FROM Expediente_de_Negativos__c
            WHERE Id = :responses[0].expedienteId
        ];

        System.assertEquals(cuenta.Id, exp.Cuenta__c, 'La cuenta debe coincidir');
        System.assertEquals(5, exp.Saldo_Expediente__c, 'El saldo debe ser igual a las toneladas del movimiento');
        System.assertEquals('No empezado', exp.Estado_de_la_Etapa__c, 'Estado incorrecto');
        System.assertEquals('Pendiente', exp.Etapa__c, 'Etapa incorrecta');
    }


    @IsTest
    static void testActualizarExpediente() {

        // Crear datos base
        Account cuenta = new Account(Name = 'Cuenta Test 2');
        insert cuenta;

        // Crear expediente existente
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c(
            Name = 'Exp existente',
            Cuenta__c = cuenta.Id,
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Pendiente',
            Tipo_expendiente__c = 'PRI',
            Saldo_Expediente__c = 10
        );
        insert expediente;

        // Preparar request para actualizar expediente
        ExpedienteNegativoService.Request req = new ExpedienteNegativoService.Request();
        req.cuentaId = cuenta.Id;
        req.campaniaId = null;
        req.nombreExpediente = 'PRI-TEST';
        req.tipoExpediente = 'PRI';
        req.toneladas = 3;
        req.obtentorId = null;

        List<ExpedienteNegativoService.Request> requests = new List<ExpedienteNegativoService.Request>{ req };

        Test.startTest();
        List<ExpedienteNegativoService.Response> responses = ExpedienteNegativoService.crearActualizar(requests);
        Test.stopTest();

        // Validar actualización del expediente
        Expediente_de_Negativos__c exp = [
            SELECT Id, Saldo_Expediente__c
            FROM Expediente_de_Negativos__c
            WHERE Id = :expediente.Id
        ];

        System.assertEquals(13, exp.Saldo_Expediente__c, 'El saldo debe haberse incrementado correctamente');
    }
}