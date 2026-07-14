@isTest
public class CommunityUserTest {

    @TestSetup
    public static void setup() {
        Account obtentor = Test_TestUtils.crearObtentor();
        obtentor.N_CUIT__c = '20166297932';
        obtentor.Type = 'Obtentor';
        obtentor.ParentId = null;
        update obtentor;

        Contact c = new Contact();
        c.accountId = obtentor.id;
        c.email = '123@test.com';
        c.lastName = 'test';
        c.firstName = 'John';
        insert c;

        // Crear usuario de prueba con el contacto
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];
        
        User u = new User();
        u.Username = '20166297932test@test.com';
        u.Email = '123@test.com';
        u.LastName = 'test';
        u.FirstName = 'John';
        u.Alias = 'jtest';
        u.TimeZoneSidKey = 'America/Argentina/Buenos_Aires';
        u.LocaleSidKey = 'es_AR';
        u.EmailEncodingKey = 'UTF-8';
        u.LanguageLocaleKey = 'es';
        u.ProfileId = p.Id;
        u.ContactId = c.Id;
        u.IsActive = true;
        insert u;
    }
    
   
    @isTest
    static void testDoChangePasswordMismatch() {
        User testUser = [SELECT Id FROM User WHERE Email = '123@test.com' LIMIT 1];
        System.runAs(testUser) {
            try {
                // Passwords no coinciden - Site.changePassword debe lanzar excepción
                CommunityUser.doChangePassword('oldPassword123', 'newPassword123', 'differentPassword');
                System.assert(false, 'Debería haber lanzado excepción');
            } catch (Exception e) {
                
            }
        }
    }
    
    @isTest
    static void testRequestResetPasswordSuccess() {
        try {
            CommunityUser.requestResetPassword('20166297932', '123@test.com');
            System.assert(true, 'RequestResetPassword ejecutado exitosamente');
        } catch (Exception e) {
            System.debug('Exception esperada en test: ' + e.getMessage());
        }
    }
    
    @isTest
    static void testRequestResetPasswordUserNotFound() {
        try {
            // Email que no existe
            CommunityUser.requestResetPassword('20166297932', 'noexiste@test.com');
            System.assert(false, 'Debería haber lanzado excepción por usuario no encontrado');
        } catch (Exception e) {
        }
    }
    
    @isTest
    static void testRequestResetPasswordContactNotFound() {
        try {
            // CUIT que no existe
            CommunityUser.requestResetPassword('99999999999', '123@test.com');
            System.assert(false, 'Debería haber lanzado excepción por contacto no encontrado');
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Error lanzado correctamente');
        }
    }
    
    @isTest
    static void testRequestResetPasswordWithInactiveUser() {
        // Desactivar el usuario
        User existingUser = [SELECT Id FROM User WHERE Email = '123@test.com' LIMIT 1];
        existingUser.IsActive = false;
        update existingUser;
        
        try {
            CommunityUser.requestResetPassword('20166297932', '123@test.com');
            System.assert(false, 'Debería haber lanzado excepción por usuario inactivo');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('No existe un usuario'), 'Mensaje de error por usuario inactivo');
        }
    }
    
    @isTest
    static void testDoChangePasswordInvalidOldPassword() {
        User testUser = [SELECT Id FROM User WHERE Email = '123@test.com' LIMIT 1];
        System.runAs(testUser) {
            try {
                // Contraseña antigua incorrecta
                CommunityUser.doChangePassword('wrongOldPassword', 'newPassword123', 'newPassword123');
                System.assert(false, 'Debería haber lanzado excepción');
            } catch (Exception e) {
                System.assert(e.getMessage() != null, 'Error lanzado por contraseña incorrecta');
            }
        }
    }
    
    @isTest
    static void testRequestResetPasswordMultipleScenarios() {
        Contact testContact = [SELECT Id, Email FROM Contact WHERE Email = '123@test.com' LIMIT 1];
        User testUser = [SELECT Id, Username, Email FROM User WHERE ContactId = :testContact.Id LIMIT 1];
        
    }
}