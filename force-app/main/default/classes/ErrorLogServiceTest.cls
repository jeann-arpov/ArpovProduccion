/**
 * @description Test para ErrorLogService y ApexErrorHandler.
 *              Valida insercion de logs, extraccion de stack trace, mensajes amigables.
 */
@isTest
private with sharing class ErrorLogServiceTest {

    static {
        ErrorLogService.setSyncMode(true);
    }

    @isTest
    static void testLogExceptionWithAllDetails() {
        Exception testEx;
        try {
            List<Account> accs = new List<Account>();
            Account a = accs.get(0);
        } catch (Exception e) {
            testEx = e;
        }

        Test.startTest();
        ErrorLogService.log(testEx, 'ERR-VTA-001', ErrorLogService.Severity.ERROR,
                            'CrearVenta', new Map<String, Object>{'recordId' => 'a00TEST000000001'});
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, ErrorCode__c, Severity__c, Component__c,
                                         ClassName__c, MethodName__c, StackTrace__c,
                                         OriginalMessage__c, UserMessage__c, RelatedRecordId__c,
                                         Environment__c, Origin__c
                                  FROM ErrorLog__c WHERE ErrorCode__c = 'ERR-VTA-001'];
        System.assertEquals(1, logs.size(), 'Debe existir un registro de log');
        ErrorLog__c log = logs[0];
        System.assertEquals('ERR-VTA-001', log.ErrorCode__c);
        System.assertEquals('ERROR', log.Severity__c);
        System.assertEquals('CrearVenta', log.Component__c);
        System.assertNotEquals(null, log.StackTrace__c, 'Debe tener stack trace');
        System.assert(log.StackTrace__c.contains('ErrorLogServiceTest'), 'Stack debe contener clase test');
        System.assertNotEquals(null, log.ClassName__c);
        System.assertNotEquals(null, log.MethodName__c);
        System.assert(log.UserMessage__c.contains('ERR-VTA-001'), 'Mensaje usuario debe incluir codigo');
        System.assert(log.UserMessage__c.contains('Mesa de Ayuda'), 'Mensaje debe mencionar Mesa de Ayuda');
        System.assertEquals('a00TEST000000001', log.RelatedRecordId__c);
        System.assertNotEquals(null, log.Environment__c);
    }

    @isTest
    static void testLogMessage() {
        Test.startTest();
        ErrorLogService.logMessage('Error de validacion: campo requerido', 'ERR-INT-001',
                                   ErrorLogService.Severity.WARNING, 'IntegracionERP', null);
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, OriginalMessage__c, Severity__c
                                  FROM ErrorLog__c WHERE ErrorCode__c = 'ERR-INT-001'];
        System.assertEquals(1, logs.size());
        System.assertEquals('WARNING', logs[0].Severity__c);
        System.assertEquals('Error de validacion: campo requerido', logs[0].OriginalMessage__c);
    }

    @isTest
    static void testGetUserFriendlyMessage_KnownPrefix() {
        String msg = ErrorLogService.getUserFriendlyMessage('ERR-VTA-003');
        System.assert(msg.contains('ERR-VTA-003'), 'Debe contener el codigo');
        System.assert(msg.contains('Mesa de Ayuda'), 'Debe mencionar Mesa de Ayuda');
        System.assert(msg.containsIgnoreCase('venta'), 'Debe describir el contexto de venta');
    }

    @isTest
    static void testGetUserFriendlyMessage_UnknownPrefix() {
        String msg = ErrorLogService.getUserFriendlyMessage('ERR-ZZZ-999');
        System.assert(msg.contains('ERR-ZZZ-999'), 'Debe contener el codigo');
        System.assert(msg.contains('Mesa de Ayuda'), 'Debe mencionar Mesa de Ayuda');
    }

    @isTest
    static void testGetUserFriendlyMessage_AllPrefixes() {
        Set<String> prefixes = new Set<String>{
            'ERR-VTA', 'ERR-CES', 'ERR-ADH', 'ERR-COM', 'ERR-LIC',
            'ERR-FAC', 'ERR-DUP', 'ERR-TRANS', 'ERR-EXP', 'ERR-NC',
            'ERR-INT', 'ERR-SYS', 'ERR-LWC', 'ERR-FLOW', 'ERR-VAL'
        };
        for (String prefix : prefixes) {
            String msg = ErrorLogService.getUserFriendlyMessage(prefix + '-001');
            System.assert(String.isNotBlank(msg), 'Debe generar mensaje para ' + prefix);
            System.assert(msg.contains('Mesa de Ayuda'), prefix + ' debe sugerir Mesa de Ayuda');
        }
    }

    @isTest
    static void testApexErrorHandler_HandleException() {
        Exception testEx;
        try {
            Integer x = 1 / 0;
        } catch (Exception e) {
            testEx = e;
        }

        Test.startTest();
        try {
            throw ApexErrorHandler.handleException(testEx, 'ERR-VTA-002', 'CrearVenta',
                                                    'a00TEST000000002');
        } catch (AuraHandledException aex) {
            System.assert(aex.getMessage().contains('ERR-VTA-002'));
            System.assert(aex.getMessage().contains('Mesa de Ayuda'));
        }
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, RelatedRecordId__c
                                  FROM ErrorLog__c WHERE ErrorCode__c = 'ERR-VTA-002'];
        System.assertEquals(1, logs.size());
        System.assertEquals('a00TEST000000002', logs[0].RelatedRecordId__c);
    }

    @isTest
    static void testApexErrorHandler_WithCustomMessage() {
        Test.startTest();
        try {
            throw ApexErrorHandler.handleException(
                new DmlException('Test error'), 'ERR-SYS-003', 'TestComponent',
                new Map<String, Object>{'action' => 'delete'},
                'No se pudo eliminar el registro porque tiene dependencias');
        } catch (AuraHandledException aex) {
            System.assert(aex.getMessage().contains('ERR-SYS-003'));
        }
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, ContextData__c
                                  FROM ErrorLog__c WHERE ErrorCode__c = 'ERR-SYS-003'];
        System.assertEquals(1, logs.size());
        System.assert(logs[0].ContextData__c.contains('customMessage'));
        System.assert(logs[0].ContextData__c.contains('dependencias'));
    }

    @isTest
    static void testLogWarning() {
        Test.startTest();
        ApexErrorHandler.logWarning(
            new DmlException('Warning test'), 'ERR-SYS-004',
            'TestComponent', new Map<String, Object>{'note' => 'test'});
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, Severity__c
                                  FROM ErrorLog__c WHERE ErrorCode__c = 'ERR-SYS-004'];
        System.assertEquals(1, logs.size());
        System.assertEquals('WARNING', logs[0].Severity__c);
    }

    @isTest
    static void testLogInfo() {
        Test.startTest();
        ApexErrorHandler.logInfo('Auditoria: usuario modifico configuracion',
                                 'ERR-SYS-005', 'Configuracion', null);
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, Severity__c, OriginalMessage__c
                                  FROM ErrorLog__c WHERE ErrorCode__c = 'ERR-SYS-005'];
        System.assertEquals(1, logs.size());
        System.assertEquals('INFO', logs[0].Severity__c);
    }

    @isTest
    static void testContextDataPreserved() {
        Map<String, Object> ctx = new Map<String, Object>{
            'recordId' => 'a0FTEST000000000',
            'action' => 'aprobar',
            'step' => 3,
            'details' => new Map<String, Object>{'monto' => 1500.00, 'moneda' => 'USD'}
        };

        Test.startTest();
        ErrorLogService.log(new DmlException('Test context'), 'ERR-TRANS-001',
                            ErrorLogService.Severity.ERROR, 'Transacciones', ctx);
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, ContextData__c, RelatedRecordId__c
                                  FROM ErrorLog__c WHERE ErrorCode__c = 'ERR-TRANS-001'];
        System.assertEquals(1, logs.size());
        System.assert(logs[0].ContextData__c.contains('aprobar'));
        System.assert(logs[0].ContextData__c.contains('USD'));
        System.assertEquals('a0FTEST000000000', logs[0].RelatedRecordId__c);
    }
}
