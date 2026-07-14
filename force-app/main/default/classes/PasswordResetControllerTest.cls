@isTest
public class PasswordResetControllerTest {
    
    @testSetup
    static void setup() {
        // Crear una cuenta de prueba
        Account acc = new Account();
        acc.Name = 'Test Account';
        acc.N_CUIT__c = '27283744103';
        insert acc;
        
        // Crear un contacto
        Contact con = new Contact();
        con.FirstName = 'Test';
        con.LastName = 'User';
        con.Email = 'testuser@example.com';
        con.AccountId = acc.Id;
        insert con;
        
        // Crear un usuario
        User testUser = new User();
        testUser.FirstName = 'Test';
        testUser.LastName = 'User';
        testUser.Email = 'testuser@example.com';
        testUser.Username = 'testuser@example.com.arpov';
        testUser.Alias = 'testuser';
        testUser.LocaleSidKey = 'es_ES';
        testUser.EmailEncodingKey = 'UTF-8';
        testUser.LanguageLocaleKey = 'ES';
        testUser.TimeZoneSidKey = 'America/Argentina/Buenos_Aires';
        testUser.ProfileId = [SELECT Id FROM Profile WHERE Name LIKE '%Distribuidor Plus%' LIMIT 1].Id;
        testUser.IsActive = true;
        testUser.ContactId = con.Id;
        insert testUser;
    }
    
    @isTest
    static void testSearchUsersByEmail() {
        // Buscar usuario por email y cuit
        List<Map<String, String>> results = PasswordResetController.searchUsersByEmail('testuser@example.com', '27283744103');
        
        Assert.isTrue(results.size() > 0, 'Debería encontrar al menos un usuario');
        Assert.isTrue(results[0].containsKey('id'), 'El resultado debe contener id');
        Assert.isTrue(results[0].containsKey('email'), 'El resultado debe contener email');
        Assert.areEqual('27283744103', results[0].get('cuit'), 'Debe devolver el CUIT asociado');
    }
    
    @isTest
    static void testSearchUsersByEmailBlank() {
        // Buscar con email vacío
        List<Map<String, String>> results = PasswordResetController.searchUsersByEmail('', '27283744103');
        
        Assert.isTrue(results.size() == 0, 'No debería encontrar resultados con email vacío');
    }
    
    @isTest
    static void testGetUserDetails() {
        // Obtener usuario de prueba
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Obtener detalles
        Map<String, String> userDetails = PasswordResetController.getUserDetails(testUser.Id);
        
        Assert.isTrue(userDetails.containsKey('id'), 'Debe contener id');
        Assert.isTrue(userDetails.containsKey('name'), 'Debe contener name');
        Assert.isTrue(userDetails.containsKey('email'), 'Debe contener email');
        Assert.areEqual(testUser.Id, userDetails.get('id'), 'El id debe coincidir');
    }
    
    @isTest
    static void testResetUserPassword() {
        // Obtener usuario de prueba
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Resetear contraseña
        Map<String, String> result = PasswordResetController.resetUserPassword(
            testUser.Id, 
            'NewPassword123!@#'
        );
        
        Assert.isTrue(result.containsKey('success'), 'Debe contener success');
        Assert.areEqual('true', result.get('success'), 'El reset debe ser exitoso');
        Assert.isTrue(result.containsKey('message'), 'Debe contener mensaje');
    }
    
    @isTest
    static void testResetUserPasswordBlank() {
        // Intentar resetear con contraseña vacía
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        
        try {
            PasswordResetController.resetUserPassword(testUser.Id, '');
            Assert.fail('Debería lanzar una excepción');
        } catch (AuraHandledException e) {
        }
    }
    
    @isTest
    static void testResetUserPasswordShort() {
        // Intentar resetear con contraseña muy corta
        User testUser = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        
        try {
            PasswordResetController.resetUserPassword(testUser.Id, '123456');
            Assert.fail('Debería lanzar una excepción');
        } catch (AuraHandledException e) {
            
        }
    }
}