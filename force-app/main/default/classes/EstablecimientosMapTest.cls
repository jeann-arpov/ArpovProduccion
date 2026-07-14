@isTest
public class EstablecimientosMapTest {
    
    @isTest static void test(){

        Account productor = Test_TestUtils.crearProductor();

        Establecimiento__c establecimiento = new Establecimiento__c();
        establecimiento.Name = 'test';
        establecimiento.Coordenadas__latitude__s = -34.4566543;
        establecimiento.Coordenadas__longitude__s = -60.2355443;
        establecimiento.Origen__c = 'Propio';
        establecimiento.Productor__c = productor.Id;

        insert establecimiento;

        System.assertEquals(1, EstablecimientosMap.getEstablecimientos().size());
    }
     @isTest
    static void testGetAccountId() {
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

        System.runAs(communityUser) {
            Test.startTest();
            String accountId = EstablecimientosMap.getAccountId();
            Test.stopTest();

            System.assertEquals(acc.Id, accountId, 'El método debe devolver el AccountId correcto del usuario');
        }
    }

    @isTest
    static void testInsertEstablecimiento() {
        // Crear datos simulados
        Map<String, Object> fieldMap = new Map<String, Object>{
            'Name' => 'Farmacia Central',
            'Coordenadas__Latitude__s' => -20.0,
            'Coordenadas__Longitude__s' => -30.0,
            'Vigente__c' => true,
            'Origen__c'=> 'Propio'
        };

        Test.startTest();
        String resultado = EstablecimientosMap.insertEstablecimiento(fieldMap);
        Test.stopTest();

        // Validar resultado
        System.assertEquals('Nuevo Establecimiento creado con exito', resultado, 'El establecimiento debe crearse correctamente');

        // Validar que el registro fue insertado
        List<Establecimiento__c> establecimientos = [SELECT Id, Name FROM Establecimiento__c WHERE Name = 'Farmacia Central'];
        System.assertEquals(1, establecimientos.size(), 'Debe existir un establecimiento con el nombre especificado');
    }
}