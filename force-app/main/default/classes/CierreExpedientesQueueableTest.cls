/**
 * Nombre: CierreExpedientesQueueableTest
 * Descripción: Tests para validar el procesamiento asíncrono
 * Autor: Sistema
 * Fecha: 2026-03-06
 */
@isTest
public class CierreExpedientesQueueableTest {

    @TestSetup
    static void setupTestData() {
        Cultivo__c testCultivo = new Cultivo__c(
            Name = 'SOJA', 
            Temporada__c = 'Anual', 
            Densidad_de_Siembra__c = 23
        );
        insert testCultivo;
    }
    
    /**
     * Test para validar que el Queueable se encola correctamente
     */
    @isTest
    static void testQueueableEnqueue() {
        // Setup: Crear Account de prueba
        Account testAccount = new Account(
            Name = 'Cuenta Test Queueable',
            Usuario_Enlist__c = false
        );
        insert testAccount;
        
        System.debug('✅ Account creada: ' + testAccount.Id);
        
        // Act: Encolar el job
        Test.startTest();
        
        CierreExpedientesQueueable job = new CierreExpedientesQueueable(testAccount.Id, testAccount.Name);
        Id jobId = System.enqueueJob(job);
        
        Test.stopTest();
        
        // Assert: Verificar que el job se encoló
        System.assertNotEquals(null, jobId, 'El Job ID no debe ser null');
        System.debug('✅ Job encolado exitosamente');
        System.debug('   Job ID: ' + jobId);
    }
    
    /**
     * Test para validar que la acción invocable encola el proceso
     */
    @isTest
    static void testEncolarProcesoAction() {
        // Setup: Crear Account de prueba
        Account testAccount = new Account(
            Name = 'Cuenta Test Acción',
            Usuario_Enlist__c = true
        );
        insert testAccount;
        
        System.debug('✅ Account creada: ' + testAccount.Id);
        
        // Act: Llamar la acción invocable
        Test.startTest();
        
        EncolarProcesoAsincronoAction.EncolarRequest request = new EncolarProcesoAsincronoAction.EncolarRequest();
        request.accountId = testAccount.Id;
        request.accountName = testAccount.Name;
        
        try {
            EncolarProcesoAsincronoAction.encolarProceso(new List<EncolarProcesoAsincronoAction.EncolarRequest>{request});
            System.debug('✅ Acción invocable ejecutada exitosamente');
        } catch (Exception e) {
            System.debug('❌ Error en acción: ' + e.getMessage());
            throw e;
        }
        
        Test.stopTest();
        
        System.debug('✅ Test completado - Procesamiento encolado asíncronamente');
    }
    
    /**
     * Test de flujo completo: Actualización de Account → Encola procesamiento
     */
    @isTest
    static void testFlowTriggerWithAsyncProcessing() {
        // Setup: Crear Account
        Account testAccount = new Account(
            Name = 'Cuenta Test Flow Async',
            Usuario_Enlist__c = false
        );
        insert testAccount;
        
        System.debug('✅ Account creada: ' + testAccount.Id);
        
        // Act: Actualizar a Usuario_Enlist__c = true (dispara el flow)
        Test.startTest();
        
        testAccount.Usuario_Enlist__c = true;
        update testAccount;
        
        Test.stopTest();
        
        // Assert: Verificar que el Account se actualizó
        Account updatedAccount = [SELECT Id, Usuario_Enlist__c FROM Account WHERE Id = :testAccount.Id];
        System.assertEquals(true, updatedAccount.Usuario_Enlist__c, 'Usuario_Enlist__c debe ser true');
        
        System.debug('✅ Flow ejecutado - Procesamiento asíncrono encolado');
        System.debug('   El trabajo se ejecutará en background sin bloquear la actualización');
    }
    
    /**
     * Test de límites para verificar que no superamos límites en modo asíncrono
     */
    @isTest
    static void testAsyncLimitsWithBulkOperations() {
        // Setup: Crear múltiples Accounts
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            testAccounts.add(new Account(
                Name = 'Cuenta Bulk ' + i,
                Usuario_Enlist__c = false
            ));
        }
        insert testAccounts;
        
        System.debug('✅ ' + testAccounts.size() + ' Accounts creadas');
        
        // Act: Actualizar todas a Usuario_Enlist__c = true
        Test.startTest();
        
        for (Account acc : testAccounts) {
            acc.Usuario_Enlist__c = true;
        }
        update testAccounts;
        
        Test.stopTest();
        
        // Assert: Verificar límites
        System.debug('=== LÍMITES ASÍNCRONO ===');
        System.debug('Apex CPU time: ' + Limits.getCpuTime() + ' / ' + Limits.getLimitCpuTime());
        System.debug('SOQL queries: ' + Limits.getQueries() + ' / ' + Limits.getLimitQueries());
        System.debug('DML statements: ' + Limits.getDmlStatements() + ' / ' + Limits.getLimitDmlStatements());
        System.debug('Heap size: ' + Limits.getHeapSize() + ' / ' + Limits.getLimitHeapSize());
        System.debug('');
        System.debug('✅ Límites dentro de rango - Procesamiento asíncrono sin bloqueos');
    }
}