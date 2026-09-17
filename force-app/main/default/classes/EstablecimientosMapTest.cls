@isTest
public class EstablecimientosMapTest {

    private class NominatimMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '{"display_name":"Béccar, Partido de San Isidro, Buenos Aires, Argentina",' +
                    '"address":{"town":"Béccar","state_district":"Partido de San Isidro",' +
                    '"state":"Buenos Aires","country":"Argentina","country_code":"ar"}}'
            );
            return res;
        }
    }

    @isTest
    static void test() {
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
        Map<String, Object> fieldMap = new Map<String, Object>{
            'Name' => 'Farmacia Central',
            'Coordenadas__Latitude__s' => -20.0,
            'Coordenadas__Longitude__s' => -30.0,
            'Vigente__c' => true,
            'Origen__c' => 'Propio'
        };

        Test.setMock(HttpCalloutMock.class, new NominatimMock());

        Test.startTest();
        String resultado = EstablecimientosMap.insertEstablecimiento(fieldMap);
        Test.stopTest();

        System.assertEquals(
            'Nuevo Establecimiento creado con exito',
            resultado,
            'El establecimiento debe crearse correctamente'
        );

        List<Establecimiento__c> establecimientos = [
            SELECT Id, Name
            FROM Establecimiento__c
            WHERE Name = 'Farmacia Central'
        ];
        System.assertEquals(1, establecimientos.size(), 'Debe existir un establecimiento con el nombre especificado');
    }

    @isTest
    static void testResolveLocalidadBeccar() {
        Provincia__c prov = new Provincia__c(Name = 'BUENOS AIRES');
        insert prov;

        Partido__c partido = new Partido__c(Name = 'SAN ISIDRO', Provincia__c = prov.Id);
        insert partido;

        Localidad__c loc = new Localidad__c(
            Name = 'BECCAR',
            Provincia__c = prov.Id,
            Partido__c = partido.Id
        );
        insert loc;

        // Otra BECCAR en otra provincia: no debe ganar
        Provincia__c otraProv = new Provincia__c(Name = 'CORDOBA');
        insert otraProv;
        insert new Localidad__c(Name = 'BECCAR', Provincia__c = otraProv.Id);

        Test.setMock(HttpCalloutMock.class, new NominatimMock());

        Test.startTest();
        Id resolved = EstablecimientosMap.resolveLocalidadId(-34.467769, -58.540158);
        Test.stopTest();

        System.assertEquals(loc.Id, resolved, 'Debe matchear Localidad BECCAR + BUENOS AIRES + SAN ISIDRO');
    }
}
