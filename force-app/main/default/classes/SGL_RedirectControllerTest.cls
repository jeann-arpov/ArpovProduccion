@isTest
private class SGL_RedirectControllerTest {

    @isTest
    static void testGetUrl() {
        Test.startTest();
        String url = SGL_RedirectController.getUrl();
        Test.stopTest();

        System.assertNotEquals(null, url, 'La URL no debe ser nula');
    }

    @isTest
    static void testSingleLicenseJWTSigner() {
        // Crear datos de prueba
        Account acc = new Account(Name = 'Cuenta Test', Type = 'Productor');
        insert acc;

        Contact ctc = new Contact(FirstName = 'Test', LastName = 'User', AccountId = acc.Id);
        insert ctc;

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Servicio al Productor']; // Obtener un perfil
        
        User usr = new User(
            Email = 'testuser@test.com',
            ContactId = ctc.Id,
            Username = '30134232347testuser@test.com' + System.currentTimeMillis(), // Asegúrate de que el nombre de usuario sea único
            LastName = 'Test User',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id, 
            LanguageLocaleKey = 'en_US'
        );
        insert usr;

         Licencia__c lic = new Licencia__c(
            Name = 'Test Licencia',
            Tipo_de_Licencia__c = 'Productor',
            Cuenta_Productor__c = acc.Id
        );
        insert lic;


        Test.startTest();
        String jwt = SGL_RedirectController.singleLicenseJWTSigner(usr.Id, ctc.Id, lic.Id);
        Test.stopTest();

        System.assert(jwt.contains('.'), 'El JWT debe tener formato válido');
    }

    @isTest
    static void testConstructorAndInit() {

        // Crear datos de prueba
        Account acc = new Account(Name = 'Cuenta Test', Type = 'Productor');
        insert acc;

        Contact ctc = new Contact(FirstName = 'Test', LastName = 'User', AccountId = acc.Id);
        insert ctc;

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Servicio al Productor']; // Obtener un perfil
        
        User usr = new User(
            Email = 'testuser@test.com',
            ContactId = ctc.Id,
            Username = '30134232347testuser@test.com' + System.currentTimeMillis(), // Asegúrate de que el nombre de usuario sea único
            LastName = 'Test User',
            Alias = 'test',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id, 
            LanguageLocaleKey = 'en_US'
        );
        insert usr;

         Licencia__c lic = new Licencia__c(
            Name = 'Test Licencia',
            Tipo_de_Licencia__c = 'Productor',
            Cuenta_Productor__c = acc.Id
        );
        insert lic;


        // Simular parámetros de URL
        Test.setCurrentPageReference(new PageReference('/apex/fakePage'));
        ApexPages.currentPage().getParameters().put('userId', usr.Id);
        ApexPages.currentPage().getParameters().put('contactId', ctc.Id);
        ApexPages.currentPage().getParameters().put('licenseId', lic.Id);

        SGL_RedirectController ctrl = new SGL_RedirectController();
        ctrl.init();

        System.assertNotEquals(null, ctrl.targetUrl, 'La URL debe estar inicializada');
        System.assertNotEquals(null, ctrl.jwtToken, 'El token JWT debe estar generado');
    }
}