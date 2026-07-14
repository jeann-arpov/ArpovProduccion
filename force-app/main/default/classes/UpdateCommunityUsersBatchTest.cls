@IsTest
public class UpdateCommunityUsersBatchTest {

    @testSetup
    static void setupData() {

        // Crear Account para Community Users
        Account acc = new Account(Name='Cuenta Test Community');
        insert acc;

        // Obtener profiles necesarios y guardar Ids
        Map<String, Id> profiles = new Map<String, Id>();
        for(Profile p : [SELECT Id, Name FROM Profile WHERE Name IN (
            'Distribuidor', 'Distribuidor Plus',
            'Obtentor','Obtentor Abogado','Obtentor Plus'
        )]){
            profiles.put(p.Name, p.Id);
        }

        List<User> users = new List<User>();

        // Contact + Usuario Distribuidor
        Contact c1 = new Contact(LastName='Contacto Dist', AccountId=acc.Id, Email='dist@test.com');
        insert c1;
        users.add(createUser(profiles.get('Distribuidor'), c1.Id, 'dist@test.com'));

        // Contact + Usuario Obtentor
        Contact c2 = new Contact(LastName='Contacto Obt', AccountId=acc.Id, Email='obt@test.com');
        insert c2;
        users.add(createUser(profiles.get('Obtentor'), c2.Id, 'obt@test.com'));

        // Contact + Usuario Obtentor Abogado
        Contact c3 = new Contact(LastName='Contacto Abog', AccountId=acc.Id, Email='abog@test.com');
        insert c3;
        users.add(createUser(profiles.get('Obtentor Abogado'), c3.Id, 'abog@test.com'));

        insert users;
    }

    @IsTest
    static void testBatchExecution() {

        // Contar usuarios de prueba
        Integer totalUsuariosPrueba = [SELECT COUNT() FROM User WHERE Username IN ('dist@test.com','obt@test.com','abog@test.com')];

        Test.startTest();
        // Ejecutar batch con batch size >= registros de prueba
        Database.executeBatch(new UpdateCommunityUsersBatch(), totalUsuariosPrueba + 1);
        Test.stopTest();

        // Validaciones
        Map<String, User> users = new Map<String, User>();
        for(User u : [SELECT Id, IsActive, Profile.Name, Username 
                      FROM User 
                      WHERE Username IN ('dist@test.com','obt@test.com','abog@test.com')]){
            users.put(u.Username, u);
        }

       
        
    }

    // Helper para crear usuarios Community
    private static User createUser(Id profileId, Id contactId, String username){
        return new User(
            Username = username,
            Email = username,
            Alias = username.substring(0,5),
            LastName = 'Test',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'es_AR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'es',
            ProfileId = profileId,
            ContactId = contactId
        );
    }
}