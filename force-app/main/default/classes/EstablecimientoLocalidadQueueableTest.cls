@isTest
private class EstablecimientoLocalidadQueueableTest {

    private class NominatimMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '{"address":{"town":"Béccar","state_district":"Partido de San Isidro",' +
                    '"state":"Buenos Aires","country":"Argentina","country_code":"ar"}}'
            );
            return res;
        }
    }

    @isTest
    static void completaLocalidadDesdeCoordenadas() {
        Provincia__c prov = new Provincia__c(Name = 'BUENOS AIRES');
        insert prov;
        Partido__c partido = new Partido__c(Name = 'SAN ISIDRO', Provincia__c = prov.Id);
        insert partido;
        Localidad__c loc = new Localidad__c(Name = 'BECCAR', Provincia__c = prov.Id, Partido__c = partido.Id);
        insert loc;

        Account productor = Test_TestUtils.crearProductor();
        Establecimiento__c conCoords = new Establecimiento__c(
            Name = 'Con coordenadas',
            Productor__c = productor.Id,
            Origen__c = 'Propio',
            Coordenadas__Latitude__s = -34.467769,
            Coordenadas__Longitude__s = -58.540158
        );
        Localidad__c otraLoc = new Localidad__c(Name = 'SAN ISIDRO', Provincia__c = prov.Id, Partido__c = partido.Id);
        insert otraLoc;
        Establecimiento__c yaConLocalidad = new Establecimiento__c(
            Name = 'Ya con localidad',
            Productor__c = productor.Id,
            Origen__c = 'Propio',
            Coordenadas__Latitude__s = -34.47,
            Coordenadas__Longitude__s = -58.52,
            Localidad__c = otraLoc.Id
        );
        insert new List<Establecimiento__c>{ conCoords, yaConLocalidad };

        Test.setMock(HttpCalloutMock.class, new NominatimMock());
        EstablecimientoLocalidadQueueable.runInTests = true;

        Test.startTest();
        EstablecimientoLocalidadQueueable.enqueue(new List<Establecimiento__c>{ conCoords, yaConLocalidad });
        Test.stopTest();

        System.assertEquals(loc.Id, [SELECT Localidad__c FROM Establecimiento__c WHERE Id = :conCoords.Id].Localidad__c);
        System.assertEquals(otraLoc.Id, [SELECT Localidad__c FROM Establecimiento__c WHERE Id = :yaConLocalidad.Id].Localidad__c);
    }

    @isTest
    static void noEncolaEnTestsNiSinRegistros() {
        EstablecimientoLocalidadQueueable.enqueue(null);
        EstablecimientoLocalidadQueueable.enqueue(new List<Establecimiento__c>{ new Establecimiento__c(Name = 'x') });
        System.assertEquals(0, Limits.getQueueableJobs());
    }
}
