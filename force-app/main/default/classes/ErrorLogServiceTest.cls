@isTest
private with sharing class ErrorLogServiceTest {
    static { ErrorLogService.setSyncMode(true); }

    @isTest
    static void testDirectInsertDiagnostic() {
        ErrorLog__c entry = new ErrorLog__c();
        entry.ErrorCode__c = 'ERR-TEST-001';
        entry.Severity__c = 'ERROR';
        entry.Component__c = 'Test';

        Test.startTest();
        try {
            insert entry;
            System.assert(true, 'Insert exitoso');
        } catch (Exception e) {
            System.assert(false, 'FALLO INSERT: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetUserFriendlyMessage() {
        String msg = ErrorLogService.getUserFriendlyMessage('ERR-VTA-003');
        System.assert(msg.contains('ERR-VTA-003'));
        System.assert(msg.contains('Mesa de Ayuda'));
    }

    @isTest
    static void testAllPrefixes() {
        for (String prefix : new Set<String>{'ERR-VTA','ERR-CES','ERR-ADH','ERR-COM','ERR-LIC','ERR-FAC','ERR-DUP','ERR-TRANS','ERR-EXP','ERR-NC','ERR-INT','ERR-SYS','ERR-LWC','ERR-FLOW','ERR-VAL'}) {
            String msg = ErrorLogService.getUserFriendlyMessage(prefix + '-001');
            System.assert(String.isNotBlank(msg));
            System.assert(msg.contains('Mesa de Ayuda'));
        }
    }

    @isTest
    static void testApexErrorHandler() {
        Exception testEx;
        try { Integer x = 1 / 0; } catch (Exception e) { testEx = e; }
        Test.startTest();
        try { throw ApexErrorHandler.handleException(testEx, 'ERR-VTA-002', 'CrearVenta', UserInfo.getUserId()); }
        catch (AuraHandledException aex) {
            System.assert(aex.getMessage().contains('ERR-VTA-002'));
            System.assert(aex.getMessage().contains('Mesa de Ayuda'));
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleExceptionWithContext() {
        Exception testEx;
        try { Integer x = 1 / 0; } catch (Exception e) { testEx = e; }
        Map<String, Object> ctx = new Map<String, Object>{'action' => 'aprobar', 'step' => 3};
        Test.startTest();
        try { throw ApexErrorHandler.handleException(testEx, 'ERR-TRANS-001', 'Transacciones', ctx, 'Error personalizado'); }
        catch (AuraHandledException aex) {
            System.assert(aex.getMessage().contains('ERR-TRANS-001'));
        }
        Test.stopTest();
    }
}
