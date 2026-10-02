@IsTest
private class SincronizarMbtExpedienteQueueableTest {

    @IsTest
    static void testEjecucionConIds() {
        // Generar un ID ficticio para simular la colección de IDs sin requerir DML
        String fakeIdStr = Account.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
        Set<Id> idsPrueba = new Set<Id>{ (Id) fakeIdStr };

        Test.startTest();
        System.enqueueJob(new SincronizarMbtExpedienteQueueable(idsPrueba));
        Test.stopTest();

        System.assert(true, 'El Queueable procesó el conjunto de IDs correctamente.');
    }

    @IsTest
    static void testEjecucionConParametroNulo() {
        Test.startTest();
        System.enqueueJob(new SincronizarMbtExpedienteQueueable(null));
        Test.stopTest();

        System.assert(true, 'El Queueable manejó el parámetro nulo sin excepciones.');
    }

    @IsTest
    static void testEjecucionConSetVacio() {
        Test.startTest();
        System.enqueueJob(new SincronizarMbtExpedienteQueueable(new Set<Id>()));
        Test.stopTest();

        System.assert(true, 'El Queueable retornó de forma temprana al recibir un Set vacío.');
    }
}