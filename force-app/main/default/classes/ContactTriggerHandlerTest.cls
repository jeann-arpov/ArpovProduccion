@isTest
private class ContactTriggerHandlerTest {
    @TestSetup
    static void setup() {
        Account account = Test_TestUtils.crearObtentor();
        Contact contact = new Contact(
            AccountId = account.Id,
            FirstName = 'Portal',
            LastName = 'User',
            Email = 'portal@test.com',
            Es_Usuario_de_Portal__c = true,
            Activo__c = true
        );
        insert contact;

        Profile communityProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Customer Community Login User'
            LIMIT 1
        ];

        insert new User(
            Username = 'portaluser' + System.currentTimeMillis() + '@test.com',
            Email = 'portal@test.com',
            LastName = 'User',
            FirstName = 'Portal',
            Alias = 'puser',
            TimeZoneSidKey = 'America/Argentina/Buenos_Aires',
            LocaleSidKey = 'es_AR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'es',
            ProfileId = communityProfile.Id,
            ContactId = contact.Id,
            IsActive = true
        );
    }

    @isTest
    static void blocksDeactivationWhenPortalUserIsActive() {
        Contact contact = [
            SELECT Id, Activo__c
            FROM Contact
            WHERE Email = 'portal@test.com'
            LIMIT 1
        ];
        contact.Activo__c = false;

        Test.startTest();
        try {
            update contact;
            System.assert(false, 'Expected validation error');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('No se puede desactivar'),
                e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void blocksDeactivationWhenNonPortalContactHasActiveUser() {
        Contact contact = [
            SELECT Id, Activo__c, Es_Usuario_de_Portal__c
            FROM Contact
            WHERE Email = 'portal@test.com'
            LIMIT 1
        ];
        contact.Es_Usuario_de_Portal__c = false;
        update contact;

        contact.Activo__c = false;

        Test.startTest();
        try {
            update contact;
            System.assert(false, 'Expected validation error');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('No se puede desactivar'),
                e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void allowsDeactivationWhenLinkedUserIsInactive() {
        User portalUser = [
            SELECT Id
            FROM User
            WHERE Email = 'portal@test.com'
            LIMIT 1
        ];
        portalUser.IsActive = false;
        update portalUser;

        Contact contact = [
            SELECT Id, Activo__c
            FROM Contact
            WHERE Email = 'portal@test.com'
            LIMIT 1
        ];
        contact.Activo__c = false;

        Test.startTest();
        update contact;
        Test.stopTest();

        contact = [SELECT Activo__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(false, contact.Activo__c);
    }

    @isTest
    static void allowsDeactivationForContactWithoutActiveUser() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact contact = new Contact(
            AccountId = account.Id,
            FirstName = 'Regular',
            LastName = 'Contact',
            Email = 'regular@test.com',
            Es_Usuario_de_Portal__c = false,
            Activo__c = true
        );
        insert contact;
        contact.Activo__c = false;

        Test.startTest();
        update contact;
        Test.stopTest();

        contact = [SELECT Activo__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(false, contact.Activo__c);
    }
}