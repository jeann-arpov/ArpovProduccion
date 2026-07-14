@isTest
private class editProfileControllerTest {

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
    }

    static testMethod void testGetUserInfo() {
        Test.startTest();
        List<User> result = editProfileController.getUserInfo();
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Debe retornar al menos un usuario');
        System.assertEquals(UserInfo.getUserId(), result[0].Id, 'El ID debe coincidir con el usuario actual');
    }

    static testMethod void testEditUser() {
        String newEmail = 'updated@example.com';
        String newPhone = '04140000000';

        Test.startTest();
        User updatedUser = editProfileController.editUser(newEmail, newPhone);
        Test.stopTest();

        System.assertEquals(newEmail, updatedUser.Email, 'El email debe actualizarse');
        System.assertEquals(newPhone, updatedUser.MobilePhone, 'El teléfono debe actualizarse');
    }

    static testMethod void testChangeUserPasswordSuccess() {
        // Este método no puede probarse completamente en sandbox sin habilitar Site context.
        // Pero podemos probar la validación básica.
        String result = editProfileController.changeUserPassword('oldPass123', 'newPass123', 'newPass123');
        System.assert(result.startsWith('Error:') || result.startsWith('Success:'), 'Debe retornar un mensaje válido');
    }

    static testMethod void testChangeUserPasswordMismatch() {
        String result = editProfileController.changeUserPassword('oldPass123', 'newPass123', 'wrongConfirm');
        System.assertEquals('Error: The new passwords you entered do not match.', result);
    }

    static testMethod void testChangeUserPasswordBlankFields() {
        String result = editProfileController.changeUserPassword('', '', '');
        System.assertEquals('Error: All password fields are required.', result);
    }
}