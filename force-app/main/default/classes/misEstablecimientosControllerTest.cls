@isTest
private class misEstablecimientosControllerTest {

    @isTest
    static void testGetEstablecimientos() {
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

        // Crear establecimientos asociados al AccountId del usuario
        List<Establecimiento__c> listaEstablecimientos = new List<Establecimiento__c>{
            new Establecimiento__c(
                Name = 'Finca El Sol',
                Productor__c = acc.Id,
                Coordenadas__Latitude__s = 10.123,
                Coordenadas__Longitude__s = -71.456
            ),
            new Establecimiento__c(
                Name = 'Granja La Luna',
                Productor__c = acc.Id,
                Coordenadas__Latitude__s = 10.789,
                Coordenadas__Longitude__s = -71.987
            )
        };
        insert listaEstablecimientos;

        // Ejecutar como el usuario
        System.runAs(communityUser) {
            Test.startTest();
            List<Establecimiento__c> resultado = misEstablecimientosController.getEstablecimientos();
            Test.stopTest();

            System.assertEquals(2, resultado.size(), 'Debe devolver los establecimientos asociados al productor');
            System.assertEquals('Finca El Sol', resultado[0].Name);
            System.assertEquals('Granja La Luna', resultado[1].Name);
        }
    }
}