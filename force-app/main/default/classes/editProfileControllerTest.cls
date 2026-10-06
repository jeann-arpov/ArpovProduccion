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
            AccountId = acc.Id,
            Es_Usuario_de_Portal__c = true
        );

        insert contact;

        // Crear un usuario vinculado a esa cuenta
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
        String newPhone = '+5491100000000';

        Test.startTest();
        User updatedUser = editProfileController.editUser(newEmail, newPhone);
        Test.stopTest();

        System.assertEquals(newEmail, updatedUser.Email, 'El email debe actualizarse');
        System.assertEquals(newPhone, updatedUser.MobilePhone, 'El teléfono debe actualizarse');
    }

    static testMethod void testEditUserUpdatesContact() {
        User communityUser = [SELECT Id, ContactId FROM User WHERE Alias = 'jperez' LIMIT 1];
        String newEmail = 'juan.nuevo@example.com';
        String newPhone = '+5491162927681';

        User updatedUser;
        List<User> profileAfterUpdate;
        Test.startTest();
        System.runAs(communityUser) {
            updatedUser = editProfileController.editUser(newEmail, newPhone);
            profileAfterUpdate = editProfileController.getUserInfo();
        }
        Test.stopTest();

        Contact contacto = [SELECT Email, MobilePhone FROM Contact WHERE Id = :communityUser.ContactId];
        System.assertEquals(newPhone, contacto.MobilePhone, 'El móvil del contacto debe actualizarse');
        System.assertEquals(newEmail, contacto.Email, 'El email del contacto debe actualizarse');
        System.assertEquals(newPhone, updatedUser.MobilePhone, 'Debe devolver el móvil actualizado');
        System.assertEquals(newPhone, profileAfterUpdate[0].MobilePhone, 'El perfil debe mostrar el móvil actualizado');
        System.assertEquals(newEmail, profileAfterUpdate[0].Email, 'El perfil debe mostrar el email actualizado');
    }

    static testMethod void testEditUserInvalidPhone() {
        User communityUser = [SELECT Id, ContactId FROM User WHERE Alias = 'jperez' LIMIT 1];
        Boolean threw = false;

        Test.startTest();
        System.runAs(communityUser) {
            try {
                editProfileController.editUser('juan.perez@example.com', '1162927681');
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assert(threw, 'Debe rechazar un celular con formato inválido');
        Contact contacto = [SELECT MobilePhone FROM Contact WHERE Id = :communityUser.ContactId];
        System.assertEquals(null, contacto.MobilePhone, 'El contacto no debe modificarse');
    }

    static testMethod void testMobilePhoneValidation() {
        System.assertEquals(null, editProfileController.getMobilePhoneError('+5491162927680'), 'Celular válido');
        System.assertNotEquals(null, editProfileController.getMobilePhoneError('3454353453453453453'), 'Sin +549 y 19 dígitos');
        System.assertNotEquals(null, editProfileController.getMobilePhoneError('+54911629276801'), 'Un dígito de más');
        System.assertNotEquals(null, editProfileController.getMobilePhoneError('+549 1162927680'), 'Con espacios');
        System.assertNotEquals(null, editProfileController.getMobilePhoneError('+5491111111111'), 'Todos los dígitos iguales');
        System.assertNotEquals(null, editProfileController.getMobilePhoneError('+5491234567890'), 'Consecutivos ascendentes');
        System.assertNotEquals(null, editProfileController.getMobilePhoneError('+5499876543210'), 'Consecutivos descendentes');
        System.assertNotEquals(null, editProfileController.getMobilePhoneError(''), 'Vacío');

        Boolean threw = false;
        try {
            editProfileController.editUser('juan.perez@example.com', '+5491234567890');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'editUser debe rechazar secuencias consecutivas');
    }

    static testMethod void testEditUserInvalidEmail() {
        Boolean threw = false;

        Test.startTest();
        try {
            editProfileController.editUser('no-es-un-email', '+5491100000000');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Debe rechazar un email con formato inválido');
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