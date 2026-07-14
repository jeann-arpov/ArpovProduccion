@IsTest
public class ExportEstadoCuentaCyOControllerTest {

    @TestSetup
    static void makeData() {
        // Crear cuenta de prueba
        Account testAccount = new Account(
            Name = 'Cuenta de Prueba',
            N_CUIT__c = '20166289050'
        );
        insert testAccount;

        // Crear oportunidades de prueba
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 3; i++) {
            Opportunity opp = new Opportunity(
                AccountId = testAccount.Id,
                Name = 'Opp ' + i,
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                Fecha_Vencimiento_Comprobante__c = Date.today().addDays(30),
                N_de_Comprobante__c = 'TEST-0004-' + String.valueOf(i).leftPad(4, '0'),
                Divisa_Comprobante__c = 'USD',
                Fecha_Emision_Comprobante__c = Date.today().addDays(-30),
                Saldo_a_Cobrar_Comprobante__c = 50.00 + i * 25,
                Total_Comprobante__c = 150.00 + i * 75
            );
            opps.add(opp);
        }
        insert opps;
    }

    @IsTest
    static void testGetEstadoCuentaSuccess() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        ExportEstadoCuentaCyOController.ExportData result = ExportEstadoCuentaCyOController.getEstadoCuenta(
            testAccount.Id,
            Date.today().addDays(-1),
            Date.today().addDays(1)
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'El resultado no debe ser nulo');
        System.assertNotEquals(null, result.headers, 'Los headers no deben ser nulos');
        System.assert(result.headers.size() > 0, 'Debe haber headers');
        System.assertNotEquals(null, result.rows, 'Las filas no deben ser nulas');
        System.assert(result.rows.size() > 0, 'Debe haber filas');
    }

    @IsTest
    static void testGetEstadoCuentaNoData() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            ExportEstadoCuentaCyOController.ExportData result = ExportEstadoCuentaCyOController.getEstadoCuenta(
                testAccount.Id,
                Date.today().addDays(-10),
                Date.today().addDays(-5)
            );
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No se encontraron'), 'Mensaje de error incorrecto');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetEstadoCuentaInvalidDates() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            ExportEstadoCuentaCyOController.getEstadoCuenta(
                testAccount.Id,
                Date.today(),
                Date.today().addDays(-1)
            );
            System.assert(false, 'Debería lanzar una excepción');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendEstadoCuentaEmailSuccess() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        ExportEstadoCuentaCyOController.sendEstadoCuentaEmail(
            testAccount.Id,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'test@example.com'
        );
        Test.stopTest();

        // Verificar que se envió el email
    }

    @IsTest
    static void testSendEstadoCuentaEmailNoEmail() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            ExportEstadoCuentaCyOController.sendEstadoCuentaEmail(
                testAccount.Id,
                Date.today().addDays(-1),
                Date.today().addDays(1),
                ''
            );
            System.assert(false, 'Debería lanzar una excepción');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendEstadoCuentaEmailNoData() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            ExportEstadoCuentaCyOController.sendEstadoCuentaEmail(
                testAccount.Id,
                Date.today().addDays(-10),
                Date.today().addDays(-5),
                'test@example.com'
            );
            System.assert(false, 'Debería lanzar una excepción');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
}