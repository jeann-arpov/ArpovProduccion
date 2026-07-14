@isTest
private class CustomJWTSignerTest {
    @isTest
    static void testCustomJWTSigner() {
        // Crear un usuario de prueba
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Servicio al Productor']; // Obtener un perfil
        
        Account testAccount = new Account(
            Name = 'Test Account',
            ERPvs__Denominacion_Y_Razon_Social__c = 'Test User',
            Type = 'Productor'
        );
        insert testAccount;
        
        Contact testContact = new Contact(
            LastName = 'Contact',
            FirstName = 'Test',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        User testUser = new User(
            Email = 'testuser@test.com',
            ContactId = testContact.Id,
            Username = '30134232347testuser@test.com' + System.currentTimeMillis(), // Asegúrate de que el nombre de usuario sea único
            LastName = 'Test User',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id, 
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        // Ejecutar el método CustomJWTSigner
        Test.startTest();
        String jwt = CustomJWTSigner.CustomJWTSigner(testUser.Id, 'https://test.com', testContact.Id);
        Test.stopTest();
        
        // Verificar que el JWT no sea nulo
        System.assert(jwt != null);
        
        // Dividir el JWT en sus partes
        List<String> jwtParts = jwt.split('\\.');
        System.assertEquals(3, jwtParts.size());
        
        // Decodificar el encabezado y la carga útil
        String jsonString = EncodingUtil.base64Decode(jwtParts[0].replace('-', '+').replace('_', '/')).toString();
        Map<String, Object> header = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        
        jsonString = EncodingUtil.base64Decode(jwtParts[1].replace('-', '+').replace('_', '/')).toString();
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        
        // Verificar las reclamaciones en el encabezado y la carga útil
        System.assertEquals('JWT', header.get('typ'));
        System.assertEquals('HS256', header.get('alg'));
        System.assertEquals('user@example.com', payload.get('sub'));
        System.assertEquals('testuser@test.com', payload.get('email'));
        
        System.assertEquals('30134232347', payload.get('cuit'));
        System.assertEquals('Productor', payload.get('accType'));
        System.assertEquals('Test', payload.get('firstName'));
        System.assertEquals('Contact', payload.get('lastName'));
        
        System.assertEquals(true, payload.get('admin'));
    }
    
    @isTest
    static void testCustomJWTSignerLicencias() {
        // Crear datos de prueba
        Account testAccount = new Account(
            Name = 'Test Account',
            Type = 'Productor'
        );
        insert testAccount;
        
        Contact testContact = new Contact(
            LastName = 'Contact',
            FirstName = 'Test',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Obtener un perfil
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Servicio al Productor']; 
        
        // Crear un usuario de prueba con los campos obligatorios
        User testUser = new User(
            Email = 'testuser@test.com',
            ContactId = testContact.Id,
            Username = 'testuser@test.com' + System.currentTimeMillis(),
            LastName = 'Test User',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id, 
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        Licencia__c testLicencia = new Licencia__c(
            Name = 'Test Licencia',
            Tipo_de_Licencia__c = 'Productor',
            Cuenta_Productor__c = testAccount.Id
        );
        insert testLicencia;
        
        // Ejecutar el método CustomJWTSignerLicencias
        Test.startTest();
        String jwt = CustomJWTSigner.CustomJWTSignerLicencias(testUser.Id, 'https://test.com', testContact.Id);
        Test.stopTest();
        
        // Verificar que el JWT no sea nulo
        System.assert(jwt != null);
        
        // Obtener la licencia actualizada
        Licencia__c updatedLicencia = [SELECT sglUrl__c, tokenHeaderFromApex__c, tokenPayloadFromApex__c, tokenPayloadFromApex2__c, tokenSignatureFromApex__c, urlFromApex__c FROM Licencia__c WHERE Id = :testLicencia.Id];
        
        // Verificar que los campos de la licencia se hayan actualizado correctamente
        System.assert(updatedLicencia.tokenHeaderFromApex__c != null);
        System.assert(updatedLicencia.tokenPayloadFromApex__c != null);
        System.assert(updatedLicencia.tokenPayloadFromApex2__c != null);
        System.assert(updatedLicencia.tokenSignatureFromApex__c != null);
    }

    @isTest
    static void testCustomJWTSignerSingleLicencia() {
        // Crear datos de prueba
         Profile p = [SELECT Id FROM Profile WHERE Name = 'Servicio al Productor']; // Obtener un perfil
        
        Account testAccount = new Account(
            Name = 'Test Account',
            ERPvs__Denominacion_Y_Razon_Social__c = 'Test User',
            Type = 'Productor'
        );
        insert testAccount;
        
        Contact testContact = new Contact(
            LastName = 'Contact',
            FirstName = 'Test',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        User testUser = new User(
            Email = 'testuser@test.com',
            ContactId = testContact.Id,
            Username = '30134232347testuser@test.com' + System.currentTimeMillis(), // Asegúrate de que el nombre de usuario sea único
            LastName = 'Test User',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id, 
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        Licencia__c testLicencia = new Licencia__c(
            Name = 'Test Licencia',
            Tipo_de_Licencia__c = 'Productor',
            Cuenta_Productor__c = testAccount.Id
        );
        insert testLicencia;
        
        // Ejecutar el método singleLicenseJWTSigner
        Test.startTest();
        String jwt = CustomJWTSigner.singleLicenseJWTSigner(testUser.Id, testContact.Id, testLicencia.Id);
        Test.stopTest();
        
        // Verificar que el JWT no sea nulo
        System.assert(jwt != null);
        
        // Dividir el JWT en sus partes
        List<String> jwtParts = jwt.split('\\.');
        System.assertEquals(3, jwtParts.size());
        
        // Decodificar el encabezado y la carga útil
        String jsonString = EncodingUtil.base64Decode(jwtParts[0].replace('-', '+').replace('_', '/')).toString();
        Map<String, Object> header = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        
        jsonString = EncodingUtil.base64Decode(jwtParts[1].replace('-', '+').replace('_', '/')).toString();
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        
        // Verificar las reclamaciones en el encabezado y la carga útil
        System.assertEquals('JWT', header.get('typ'));
        System.assertEquals('HS256', header.get('alg'));
        System.assertEquals('user@example.com', payload.get('sub'));
        System.assertEquals('testuser@test.com', payload.get('email'));
        
        System.assertEquals('30134232347', payload.get('cuit'));
        System.assertEquals('Productor', payload.get('accType'));
        System.assertEquals('Test', payload.get('firstName'));
        System.assertEquals('Contact', payload.get('lastName'));
        
        System.assertEquals(true, payload.get('admin'));
    }

    @isTest
    static void testCustomJWTSignerSingleLicenciaSigner() {
        // Crear datos de prueba
         Profile p = [SELECT Id FROM Profile WHERE Name = 'Servicio al Productor']; // Obtener un perfil
        
        Account testAccount = new Account(
            Name = 'Test Account',
            ERPvs__Denominacion_Y_Razon_Social__c = 'Test User',
            Type = 'Productor'
        );
        insert testAccount;
        
        Contact testContact = new Contact(
            LastName = 'Contact',
            FirstName = 'Test',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        User testUser = new User(
            Email = 'testuser@test.com',
            ContactId = testContact.Id,
            Username = '30134232347testuser@test.com' + System.currentTimeMillis(), // Asegúrate de que el nombre de usuario sea único
            LastName = 'Test User',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id, 
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        
        Licencia__c testLicencia = new Licencia__c(
            Name = 'Test Licencia',
            Tipo_de_Licencia__c = 'Productor',
            Cuenta_Productor__c = testAccount.Id
        );
        insert testLicencia;
        
        // Ejecutar el método singleLicenseJWTSigner
        Test.startTest();
        String jwt = CustomJWTSigner.singleNewLicenseRequestJWTSigner(testUser.Id, testContact.Id);
        Test.stopTest();
        
        // Verificar que el JWT no sea nulo
        System.assert(jwt != null);
    }
}