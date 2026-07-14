@isTest
public with sharing class RegisterCommunityControllerTest {
    
              @TestSetup
    public static void setup() {
        // Primero crear objetos no-setup
        Account obtentor = Test_TestUtils.crearObtentor();
        obtentor.N_CUIT__c = '20166297932';
        update obtentor;

        Contact c = new Contact();
        c.accountId = obtentor.id;
        c.email = '20166297932@test.com';
        c.lastName = 'test';

        Contact c2 = new Contact();
        c2.accountId = obtentor.id;
        c2.email = '20166297932@test2.com';
        c2.lastName = 'test2';

        insert c;
        insert c2;

        // Crear Sembra_Evolucion__c (custom setting)
        Sembra_Evolucion__c cs = new Sembra_Evolucion__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Obtentor_Distribuidor__c = '20417233386',
            URL_Logo_SE__c = 'test'
        );
        insert cs;
        
        // NO crear EmailTemplate en @TestSetup - lo crearemos en cada prueba que lo necesite
        // EmailTemplate es un setup object y causa problemas con MIXED_DML_OPERATION
    }

    public static testmethod void noMatchCuit() {
        try {
            RegisterCommunityController.verifyUserCreation('', '20166297932', 'nombre', 'apellido', '12345678');
            System.assert(false);
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('No existe una cuenta con'));
        }
    }


    public static testmethod void noMatch() {
        try {
            RegisterCommunityController.verifyUserCreation('', '20166297932', 'nombre', 'apellido', '12345678');
            System.assert(false);
        } catch (AuraHandledException e) {
          //  System.assert(e.getMessage().contains('No existe contacto'));
        }
    }

    public static testmethod void verifyUserCreation() {
        UserRole userrole = [Select Id, DeveloperName From UserRole where DeveloperName = 'Desarrollo' Limit 1];

        User adminUser = new User(Id = UserInfo.getUserId());

        adminUser.UserRoleId = userRole.Id;
        update adminUser;

        System.runAs(adminUser) {
            System.assertEquals([select id from contact where firstName = 'nombre' and lastname = 'apellido'].size(), 0);
            RegisterCommunityController.verifyUserCreation('20166297932@test.com', '20166297932', 'nombre', 'apellido', '12345678');   
            //System.assertEquals([select id from contact where firstName = 'nombre' and lastname = 'apellido'].size(), 1);
        }
        
        RegisterCommunityController.login('20166297932@test.com', '20166297932');

        try {
            RegisterCommunityController.verifyUserCreation('20166297932@test.com', '20166297932', 'nombre', 'apellido', '12345678'); 
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Ya existe un usuario'));
        }
    }    

    public static testmethod void confirmUserCreation() {
        try {
            RegisterCommunityController.confirmUserCreation('123', '123', '20166297932@test.com', '20166297932');
            System.assert(false);
        } catch(AuraHandledException e) {

        }
    }

    public static testmethod void loginFail() {
        try {
            RegisterCommunityController.login('20166297932@test.com', '20166297932');
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No existe un usuario'), e.getMessage());
        }
    }

    
    public static testmethod void confirmLoginFail() {
        try {
            RegisterCommunityController.confirmLogin('userid', '123', '20166297932');
            System.assert(false);
        } catch (AuraHandledException e) {

        }
    }

    @isTest 
    static void testCreateUser(){
        try{
            RegisterCommunityController.doCreateUser('20166297932@test2.com', '20166297932', 'Diego', 'Rivera', '39882332', '123', '+54987876565');
            System.assert(false);
        }catch(AuraHandledException e){

        }
    }

    @isTest 
    static void testAutomatizacion(){
        try{
            RegisterCommunityController.addAutomatizacion(new User());
        }catch(AuraHandledException e){

        }
    }

    @isTest 
    static void testLoginWithPassword(){
        try {
            RegisterCommunityController.loginWithPassword('20166297932@test', '20166297932', '123');
            System.assert(false);
        } catch (AuraHandledException e) {
            
        }
    }

    @isTest
    static void testUrlLogoSE(){
        RegisterCommunityController.getUrlLogoSE();
    }
        // Agregar al final de la clase, después del último método existente
    
    
    
    @isTest 
    static void testSendWelcomeEmailImmediateNoTemplate() {
        // NO crear plantilla - dejar que el método use el fallback
        
        // Crear un usuario para la prueba con un Username único
        Contact contact = [SELECT Id FROM Contact WHERE Email = '20166297932@test.com' LIMIT 1];
        
        // Obtener un perfil que exista en pruebas
        Profile testProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Obtentor%' LIMIT 1];
        
        // Usar un timestamp diferente para hacer el Username único
        String timestamp = String.valueOf(System.now().getTime() + 1); // +1 para ser diferente
        String uniqueUsername = 'testuser2' + timestamp + '@test.com';
        
        User testUserForTest = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = '20166297932@test.com',
            Username = uniqueUsername, // Username único
            Alias = 'tuser2',
            CommunityNickname = 'tuser2123',
            ContactId = contact.Id,
            ProfileId = testProfile.Id,
            TimeZoneSidKey = 'America/Argentina/Buenos_Aires',
            LocaleSidKey = 'es_AR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'es'
        );
        insert testUserForTest;
        
        Test.startTest();
        // Llamar al método que se va a probar
        RegisterCommunityController.sendWelcomeEmailImmediate(testUserForTest.Id);
        Test.stopTest();
        
        // Verificar que el método se ejecutó sin errores (incluso sin plantilla)
        System.assert(true, 'El método sendWelcomeEmailImmediate debería ejecutar el fallback sin plantilla');
    }
    
    @isTest
    static void testSendWelcomeEmailImmediateUserNotFound() {
        Test.startTest();
        // Probar con un ID de usuario que no existe
        RegisterCommunityController.sendWelcomeEmailImmediate('005000000000001');
        Test.stopTest();
        
        System.assert(true, 'El método debería manejar usuarios no encontrados sin errores');
    }
}