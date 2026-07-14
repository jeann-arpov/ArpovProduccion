@isTest
private class misCesionesControllerTest {

    @testSetup
    static void setupData() {
        // Crear una cuenta simulada
        Account acc = Test_TestUtils.crearProductor();

        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];

        Contact contact = new Contact(
            FirstName = 'Juan',
            LastName = 'Pérez',
            Email = 'juan.perez@example.com',
            AccountId = acc.Id
        );

        insert contact;

        // Crear un usuario vinculado a esa cuenta
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User communityUser = new User(
            Username = 'juan.perez+' + System.currentTimeMillis() + '@example.com',
            Alias = 'jperez',
            Email = contact.Email,
            EmailEncodingKey = 'UTF-8',
            FirstName = contact.FirstName,
            LastName = contact.LastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Caracas',
            ProfileId = communityProfile.Id,
            ContactId = contact.Id,
            CommunityNickname = 'juanperez' + String.valueOf(Math.mod(System.currentTimeMillis(), 10000)),
            IsActive = true
        );

        insert communityUser;

        // Crear un registro de Cesion_HT__c vinculado a la cuenta
        Cesion_HT__c cesion = new Cesion_HT__c(
            Name = 'Cesión Test',
            Cuenta_Cedente__c = acc.Id,
            Tipo_de_Cesion__c = 'Semilla Original',
            Estado__c = 'Validada',
            Variedades__c = 'Maíz'
            //Cultivo__r = new Cultivo__c(Name = 'Cultivo Test') // Si Cultivo__r es lookup, se debe insertar primero
        );
        insert cesion;
    }

    static testMethod void testGetCesiones() {
        // Obtener el usuario creado en testSetup
        User testUser = [SELECT Id FROM User WHERE Alias = 'jperez' LIMIT 1];

        // Simular ejecución como ese usuario
        System.runAs(testUser) {
            Test.startTest();
            List<Cesion_HT__c> result = misCesionesController.getCesiones();
            Test.stopTest();

            System.assertNotEquals(0, result.size(), 'Debe retornar al menos una cesión');
            System.assertEquals('Cesión Test', result[0].Name, 'El nombre de la cesión debe coincidir');
            System.assertEquals('Validada', result[0].Estado__c, 'El estado debe coincidir');
        }
    }
}