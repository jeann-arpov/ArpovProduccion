@isTest
public class UserChangeEventTest {

    public static testmethod void test() {
        Account obtentor = Test_TestUtils.crearObtentor();

        Contact c = new Contact();
        c.accountId = obtentor.id;
        c.email = '123@test.com';
        c.lastName = 'test';

        insert c;

        Profile p = [SELECT Id FROM Profile WHERE Name='Servicio Al Productor']; 

        UserRole role = [Select Id, DeveloperName From UserRole where DeveloperName = 'Desarrollo' Limit 1];

        User u = new User(Alias = 'standt', Email='standarduser@testorg.com', 
        EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
        LocaleSidKey='en_US', ProfileId = p.Id, 
        TimeZoneSidKey='America/Los_Angeles', UserName='standarduser@testorg.com', contactId = c.id, Id_Externo__c = 'standarduser@testorg.com');

        System.runAs(new User(Id = UserInfo.getUserId())) {
            update new User(Id = UserInfo.getUserId(), UserRoleId = role.id);
            insert u;

            Test.startTest();
            Test.enableChangeDataCapture();
            u.Email = 'test@test.com';
            update u;
            Test.getEventBus().deliver();
            Test.stopTest();

            u = [select contact.email, email from user where id =: u.id];

            System.assertEquals(u.email, u.contact.email);
        }
    }
}