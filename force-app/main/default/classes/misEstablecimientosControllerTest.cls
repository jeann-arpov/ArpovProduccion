@isTest
private class misEstablecimientosControllerTest {

    private class NominatimMock implements HttpCalloutMock {
        private final Integer status;
        private final String body;

        NominatimMock(Integer status, String body) {
            this.status = status;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody(body);
            return res;
        }
    }

    private static NominatimMock paisMock(String countryCode) {
        return new NominatimMock(200, '{"address":{"country_code":"' + countryCode + '"}}');
    }

    private static User crearUsuarioComunidad(Account acc) {
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];

        Contact contact = new Contact(
            FirstName = 'Juan',
            LastName = 'Pérez',
            Email = 'juan.perez@example.com',
            AccountId = acc.Id
        );
        insert contact;

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
        return communityUser;
    }

    @isTest
    static void testGetEstablecimientos() {
        Account acc = Test_TestUtils.crearProductor();
        User communityUser = crearUsuarioComunidad(acc);

        List<Establecimiento__c> listaEstablecimientos = new List<Establecimiento__c>{
            new Establecimiento__c(
                Name = 'Finca El Sol',
                Productor__c = acc.Id,
                Coordenadas__Latitude__s = 10.123,
                Coordenadas__Longitude__s = -71.456,
                Vigente__c = true
            ),
            new Establecimiento__c(
                Name = 'Granja La Luna',
                Productor__c = acc.Id,
                Coordenadas__Latitude__s = 10.789,
                Coordenadas__Longitude__s = -71.987,
                Vigente__c = true
            ),
            new Establecimiento__c(
                Name = acc.N_CUIT__c + ' - Plan de Siembra 2025/2026 - SOJA',
                Productor__c = acc.Id,
                Origen__c = 'Grandes Cuentas',
                Coordenadas__Latitude__s = 10.5,
                Coordenadas__Longitude__s = -71.5,
                Vigente__c = true
            )
        };
        insert listaEstablecimientos;

        System.runAs(communityUser) {
            Test.startTest();
            List<misEstablecimientosController.EstRow> resultado = misEstablecimientosController.getEstablecimientos();
            Test.stopTest();

            System.assertEquals(2, resultado.size(), 'Debe devolver solo los establecimientos propios del productor (sin los de Grandes Cuentas)');
            System.assertEquals('Finca El Sol', resultado[0].name);
            System.assertEquals('Granja La Luna', resultado[1].name);
            System.assertEquals(false, resultado[0].hasHt);
            System.assertEquals(false, resultado[0].adheridoPph);
            System.assertNotEquals(null, resultado[0].createdDate);
        }
    }

    @isTest
    static void testGetEstablecimientosConPph() {
        Account acc = Test_TestUtils.crearProductor();
        User communityUser = crearUsuarioComunidad(acc);

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
        cultivo.Sembra_Evolucion__c = true;
        insert cultivo;

        Parametro_PPH__c param = new Parametro_PPH__c(
            Name = 'Plan de Siembra 2026/2027 - SOJA',
            Cultivo__c = cultivo.Id,
            Fecha_Inicio_Adhesion_PPH__c = Date.today(),
            Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2)
        );
        insert param;

        Plan_de_Siembra__c plan = new Plan_de_Siembra__c(
            Productor__c = acc.Id,
            Parametro_PPH__c = param.Id,
            Estado__c = 'En Preparación',
            Version__c = 'Original',
            Name = 'Plan ' + acc.N_CUIT__c + ' Original'
        );
        insert plan;

        Establecimiento__c est = new Establecimiento__c(
            Name = 'Las rosas',
            Productor__c = acc.Id,
            Coordenadas__Latitude__s = -36.0027,
            Coordenadas__Longitude__s = -63.3015,
            Vigente__c = true
        );
        insert est;

        Establecimiento_PPH__c estPph = new Establecimiento_PPH__c(
            Establecimiento__c = est.Id,
            Plan_de_Siembra__c = plan.Id,
            Cantidad_Variedad_No_SE__c = 5
        );
        insert estPph;
        insert new Linea_PPH__c(Establecimiento_PPH__c = estPph.Id, Cantidad_Declarada__c = 10);

        System.runAs(communityUser) {
            Test.startTest();
            List<misEstablecimientosController.EstRow> resultado = misEstablecimientosController.getEstablecimientos();
            Test.stopTest();

            System.assertEquals(1, resultado.size());
            System.assertEquals(true, resultado[0].hasHt);
            System.assertNotEquals(null, resultado[0].cultivo);
            System.assertEquals(5, resultado[0].superficieSinSembrar);
        }
    }

    @isTest
    static void testUpdateEstablecimiento() {
        Account acc = Test_TestUtils.crearProductor();
        User communityUser = crearUsuarioComunidad(acc);

        Establecimiento__c est = new Establecimiento__c(
            Name = 'Las rosas',
            Productor__c = acc.Id,
            Coordenadas__Latitude__s = -36.0027,
            Coordenadas__Longitude__s = -63.3015,
            Vigente__c = true
        );
        insert est;

        Test.setMock(HttpCalloutMock.class, paisMock('ar'));
        System.runAs(communityUser) {
            Test.startTest();
            misEstablecimientosController.updateEstablecimiento(est.Id, ' Las rosas 2 ', -35.5, -62.25, false);
            Test.stopTest();
        }

        Establecimiento__c updated = [
            SELECT Name, Coordenadas__Latitude__s, Coordenadas__Longitude__s, Vigente__c
            FROM Establecimiento__c
            WHERE Id = :est.Id
        ];
        System.assertEquals('Las rosas 2', updated.Name);
        System.assertEquals(-35.5, updated.Coordenadas__Latitude__s);
        System.assertEquals(-62.25, updated.Coordenadas__Longitude__s);
        System.assertEquals(false, updated.Vigente__c);
    }

    @isTest
    static void testUpdateEstablecimientoValidaciones() {
        Account acc = Test_TestUtils.crearProductor();
        User communityUser = crearUsuarioComunidad(acc);

        Establecimiento__c est = new Establecimiento__c(
            Name = 'Las rosas',
            Productor__c = acc.Id,
            Coordenadas__Latitude__s = -36.0027,
            Coordenadas__Longitude__s = -63.3015
        );
        insert est;

        Establecimiento__c borrado = new Establecimiento__c(
            Name = 'Borrado',
            Productor__c = acc.Id,
            Coordenadas__Latitude__s = -36.0,
            Coordenadas__Longitude__s = -63.0
        );
        insert borrado;
        delete borrado;

        Boolean sinNombre = false;
        Boolean noEncontrado = false;
        System.runAs(communityUser) {
            Test.startTest();
            try {
                misEstablecimientosController.updateEstablecimiento(est.Id, '  ', -36.0, -63.0, true);
            } catch (AuraHandledException e) {
                sinNombre = true;
            }
            try {
                misEstablecimientosController.updateEstablecimiento(borrado.Id, 'Otro', -36.0, -63.0, true);
            } catch (AuraHandledException e) {
                noEncontrado = true;
            }
            Test.stopTest();
        }
        System.assert(sinNombre, 'Debe exigir el nombre');
        System.assert(noEncontrado, 'Debe fallar si el establecimiento no existe para el productor');
    }

    private static Establecimiento__c crearEstablecimiento(Account acc) {
        Establecimiento__c est = new Establecimiento__c(
            Name = 'QA Establecimiento',
            Productor__c = acc.Id,
            Coordenadas__Latitude__s = -34.8475,
            Coordenadas__Longitude__s = -59.3484
        );
        insert est;
        return est;
    }

    private static String intentarModificar(User u, Id estId, Decimal lat, Decimal lng) {
        String error;
        System.runAs(u) {
            Test.startTest();
            try {
                misEstablecimientosController.updateEstablecimiento(estId, 'QA Establecimiento', lat, lng, true);
            } catch (AuraHandledException e) {
                error = e.getMessage();
            }
            Test.stopTest();
        }
        return error;
    }

    @isTest
    static void testUpdateRechazaUruguay() {
        Account acc = Test_TestUtils.crearProductor();
        User communityUser = crearUsuarioComunidad(acc);
        Establecimiento__c est = crearEstablecimiento(acc);

        Test.setMock(HttpCalloutMock.class, paisMock('uy'));
        String error = intentarModificar(communityUser, est.Id, -34.4626, -57.84);

        System.assertNotEquals(null, error, 'Colonia (Uruguay) no debe guardarse');
        Establecimiento__c actual = [SELECT Coordenadas__Latitude__s FROM Establecimiento__c WHERE Id = :est.Id];
        System.assertEquals(-34.8475, actual.Coordenadas__Latitude__s, 'Las coordenadas no deben cambiar');
    }

    @isTest
    static void testUpdateRechazaMar() {
        Account acc = Test_TestUtils.crearProductor();
        User communityUser = crearUsuarioComunidad(acc);
        Establecimiento__c est = crearEstablecimiento(acc);

        Test.setMock(HttpCalloutMock.class, new NominatimMock(200, '{"error":"Unable to geocode"}'));
        String error = intentarModificar(communityUser, est.Id, -35.2, -56.9);

        System.assertNotEquals(null, error, 'Un punto en el agua no debe guardarse');
    }

    @isTest
    static void testUpdateSinServicioNoBloquea() {
        Account acc = Test_TestUtils.crearProductor();
        User communityUser = crearUsuarioComunidad(acc);
        Establecimiento__c est = crearEstablecimiento(acc);

        Test.setMock(HttpCalloutMock.class, new NominatimMock(503, ''));
        String error = intentarModificar(communityUser, est.Id, -35.5, -62.25);

        System.assertEquals(null, error, 'Si Nominatim no responde se guarda igual');
        Establecimiento__c actual = [SELECT Coordenadas__Latitude__s FROM Establecimiento__c WHERE Id = :est.Id];
        System.assertEquals(-35.5, actual.Coordenadas__Latitude__s);
    }
}
