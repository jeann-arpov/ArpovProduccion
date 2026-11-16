@isTest
private class PortalUserContactHandlerTest {
    @isTest
    static void marksContactAsPortalUser() {
        Account account = Test_TestUtils.crearObtentor();
        Contact contact = new Contact(
            AccountId = account.Id,
            LastName = 'Portal',
            Email = 'portal-flag@test.com',
            Es_Usuario_de_Portal__c = false
        );
        insert contact;

        Test.startTest();
        PortalUserContactHandler.markPortalContacts(new Set<Id>{ contact.Id });
        Test.stopTest();

        contact = [SELECT Es_Usuario_de_Portal__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(true, contact.Es_Usuario_de_Portal__c);
    }

    @isTest
    static void ignoresUsersWithoutContact() {
        PortalUserContactHandler.afterInsert(new List<User>{ new User(LastName = 'Interno') });
        PortalUserContactHandler.markPortalContacts(new Set<Id>());
    }

    @isTest
    static void triggerMarksContactWhenPortalUserIsCreated() {
        Account account = Test_TestUtils.crearObtentor();
        Contact contact = new Contact(
            AccountId = account.Id,
            LastName = 'Trigger',
            Email = 'trigger-portal@test.com',
            Es_Usuario_de_Portal__c = false
        );
        insert contact;

        Profile communityProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Customer Community Login User'
            LIMIT 1
        ];

        User portalUser = new User(
            Username = 'portalflag' + System.currentTimeMillis() + '@test.com',
            Email = 'trigger-portal@test.com',
            LastName = 'Trigger',
            FirstName = 'Portal',
            Alias = 'pflag',
            TimeZoneSidKey = 'America/Argentina/Buenos_Aires',
            LocaleSidKey = 'es_AR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'es',
            ProfileId = communityProfile.Id,
            ContactId = contact.Id,
            IsActive = true
        );

        Test.startTest();
        insert portalUser;
        Test.stopTest();

        contact = [SELECT Es_Usuario_de_Portal__c FROM Contact WHERE Id = :contact.Id];
        System.assertEquals(true, contact.Es_Usuario_de_Portal__c);
    }
}
