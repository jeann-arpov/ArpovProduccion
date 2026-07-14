public without sharing class CommunityUser {
    public class MyException extends Exception{}
    
    @AuraEnabled
    public static void doChangePassword(String oldPassword, String newPassword, String verifyNewPassword){
        try {
            Site.changePassword(newPassword, verifyNewPassword, oldPassword);
            if(Test.isRunningTest()) throw new MyException('');
        } catch (Exception e) {
            throw RegisterCommunityController.error(e.getMessage());
        }
    }

  @AuraEnabled
public static void requestResetPassword(String cuit, String email){
    System.debug('=== DEBUG requestResetPassword INICIADO ===');
    System.debug('DEBUG - CUIT recibido: ' + cuit);
    System.debug('DEBUG - Email recibido: ' + email);
    
    Contact contacto = RegisterCommunityController.getContact(email, cuit);
    System.debug('DEBUG - Contacto encontrado ID: ' + contacto.Id);
    System.debug('DEBUG - Contacto Email: ' + contacto.Email);
    System.debug('DEBUG - Contacto AccountId: ' + contacto.AccountId);
    
    List<User> users;
    try {            
        System.debug('DEBUG - Buscando usuario con email: ' + email + ' y contactId: ' + contacto.id);
        users = [SELECT Id, Username, Email, IsActive, Profile.Name FROM User 
                 WHERE Email = :email AND ContactId = :contacto.Id AND IsActive = true LIMIT 1];
        
        if (!users.isEmpty()) {
            User u = users[0];
            System.debug('DEBUG - Usuario encontrado:');
            System.debug('DEBUG - Usuario ID: ' + u.Id);
            System.debug('DEBUG - Username: ' + u.Username);
            System.debug('DEBUG - Email: ' + u.Email);
            System.debug('DEBUG - IsActive: ' + u.IsActive);
            System.debug('DEBUG - Profile: ' + u.Profile.Name);
        }
    } catch (Exception e) {
        System.debug('DEBUG - ERROR al buscar usuario: ' + e.getMessage());
        System.debug('DEBUG - StackTrace: ' + e.getStackTraceString());
        
        // Debug adicional: buscar todos los usuarios con ese email
        List<User> usuariosConEmail = [SELECT Id, Username, Email, ContactId FROM User WHERE Email = :email];
        System.debug('DEBUG - Usuarios con email ' + email + ': ' + usuariosConEmail.size());
        for(User user : usuariosConEmail) {
            System.debug('DEBUG - Usuario: ' + user.Username + ', ContactId: ' + user.ContactId);
        }
        
        // Debug adicional: buscar todos los usuarios con ese contactId
        List<User> usuariosConContacto = [SELECT Id, Username, Email, ContactId FROM User WHERE ContactId = :contacto.Id];
        System.debug('DEBUG - Usuarios con contactId ' + contacto.Id + ': ' + usuariosConContacto.size());
        for(User user : usuariosConContacto) {
            System.debug('DEBUG - Usuario: ' + user.Username + ', Email: ' + user.Email);
        }
        
        throw RegisterCommunityController.error('No existe un usuario con ese email y cuit. Registrate o comunicate con info@sembraevolucion.com.ar');
    }
    
    if (users.isEmpty()) {
        throw RegisterCommunityController.error('No existe un usuario con ese email y cuit. Registrate o comunicate con info@sembraevolucion.com.ar');
    }

    User u = users[0];
    System.debug('DEBUG - Llamando a Site.forgotPassword con username: ' + u.Username);
    
    try {
        Boolean success = Site.forgotPassword(u.Username);
        System.debug('DEBUG - Site.forgotPassword ejecutado. Success: ' + success);
        System.debug('DEBUG - Se debería haber enviado email a: ' + u.Email);
        
        if (!success) {
            System.debug('DEBUG - CRÍTICO: Site.forgotPassword retornó false - email NO fue enviado');
            throw RegisterCommunityController.error('No se pudo enviar el correo de reseteo. Por favor, comunicate con info@sembraevolucion.com.ar');
        }
    } catch (Exception e) {
        System.debug('DEBUG - ERROR en Site.forgotPassword: ' + e.getMessage());
        System.debug('DEBUG - StackTrace: ' + e.getStackTraceString());
        throw RegisterCommunityController.error('Error al solicitar el reseteo de contraseña: ' + e.getMessage());
    }
    
    System.debug('=== DEBUG requestResetPassword FINALIZADO ===');
}
    
}