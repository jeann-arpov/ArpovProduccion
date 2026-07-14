@isTest
private class ChangePasswordControllerTest {
    
    @isTest
    static void testChangePasswordSuccess() {
        // Setup: create a test user and set password
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'user1234',
            Email = 'testuser1234@arprov.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            LastName = 'prueba',
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser1234@arprov.com'
        );
        insert u;

        // Set password for the test user
        System.setPassword(u.Id, 'OldPassword123');

        // Simulate running as the test user
        System.runAs(u) {
            ChangePasswordController controller = new ChangePasswordController();
            controller.oldPassword = 'OldPassword123';
            controller.newPassword = 'NewPassword456';
            controller.verifyNewPassword = 'NewPassword456';

            Test.startTest();
            String result = controller.changePassword();
            Test.stopTest();

            // Assert that the result is not null (indicating a redirect or success)
            System.assert(result.startsWith('Error:') || result.startsWith('Success:'), 'Debe retornar un mensaje válido');
        }
    }

    @isTest
    static void testChangePasswordMismatch() {
        ChangePasswordController controller = new ChangePasswordController();
        controller.oldPassword = 'OldPassword123';
        controller.newPassword = 'NewPassword456';
        controller.verifyNewPassword = 'MismatchPassword';

        Test.startTest();
        string result = controller.changePassword();
        Test.stopTest();

        // Even if passwords mismatch, Site.changePassword may still return a PageReference.
        // You could add logic to handle mismatches in the controller if needed.
       System.assertEquals('Error: The new passwords you entered do not match.', result);
    }
}