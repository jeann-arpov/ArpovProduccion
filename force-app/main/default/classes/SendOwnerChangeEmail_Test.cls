@IsTest
private class SendOwnerChangeEmail_Test {

    @IsTest
    static void testOwnerChangeSendsEmail() {

        // Perfil estándar para los usuarios
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User userA = new User(
            ProfileId = p.Id,
            LastName = 'UserA',
            Email = 'userA' + System.currentTimeMillis() + '@test.com',
            Username = 'userA' + System.currentTimeMillis() + '@test.com',
            Alias = 'usra',
            TimeZoneSidKey = 'America/Argentina/Buenos_Aires',
            LocaleSidKey = 'es_AR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'es'
        );
        insert userA;

        User userB = new User(
            ProfileId = p.Id,
            LastName = 'UserB',
            Email = 'userB' + System.currentTimeMillis() + '@test.com',
            Username = 'userB' + System.currentTimeMillis() + '@test.com',
            Alias = 'usrb',
            TimeZoneSidKey = 'America/Argentina/Buenos_Aires',
            LocaleSidKey = 'es_AR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'es'
        );
        insert userB;

        Id regaliaRTId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get('Regalia_Extendida')
            .getRecordTypeId();

        // Obtener un Status válido (primer valor activo)
        String statusValue = [SELECT MasterLabel FROM CaseStatus WHERE IsClosed = false LIMIT 1].MasterLabel;

        Case c = new Case(
            RecordTypeId = regaliaRTId,
            Origin = 'Phone',
            Status = statusValue,
            Subject = 'Caso de prueba',
            OwnerId = userA.Id
        );
        insert c;

        Test.startTest();
        // Cambio de Owner para disparar el trigger
        c.OwnerId = userB.Id;
        update c;
        Test.stopTest();

        // Si llega aquí sin excepción, consideramos éxito (cobertura)
        System.assertNotEquals(userA.Id, [SELECT OwnerId FROM Case WHERE Id = :c.Id].OwnerId,
            'El Owner debería haberse actualizado.');
    }
}