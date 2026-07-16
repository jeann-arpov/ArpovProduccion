@isTest
public class SolicitarLicenciaTest {
    public static testmethod void main() {
        Account acc = Test_TestUtils.crearObtentor(false);
        acc.N_CUIT__C = '30616275905';
        insert acc;

        Account productor = Test_TestUtils.crearProductor();

        CrearCompraController.acc = productor;

        SolicitarLicencia.getData(null, true, null);
        SolicitarLicencia.Data data = SolicitarLicencia.getTestData(acc.id, productor.N_CUIT__C);
        SolicitarLicencia.solicitar(JSON.serialize(data));

        Licencia__c licencia = [select name, id from Licencia__c];

        ContentVersion content = new ContentVersion(); 
        content.Title = 'test'; 
        content.VersionData = Blob.valueOf('test');
        content.PathOnClient = 'test.pdf';
        content.FirstPublishLocationId = licencia.id;
        insert content;

        Id contentDocumentId = [select contentdocumentid from contentversion where id =: content.id].contentdocumentid;

        SolicitarLicencia.renameFiles(new List<Id>{contentDocumentId}, licencia.id, licencia.Name + '-Poder');

        SolicitarLicencia.enviar(licencia.id);

        SolicitarLicencia.deleteFile(contentDocumentId, licencia.id);

        SolicitarLicencia.getUrl();
    }

    @isTest
    static void testSearchAccounts() {
        Account acc = Test_TestUtils.crearObtentor(false);
        acc.N_CUIT__C = '30616275905';
        insert acc;

        Account productor = Test_TestUtils.crearProductor();
        CrearCompraController.acc = productor;

        Test.startTest();
        List<LookupSearchResult> results = SolicitarLicencia.searchAccounts('Test', new List<String>());
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    @isTest
    static void testSearchAccounts_WithCuit() {
        Account acc = Test_TestUtils.crearObtentor(false);
        acc.N_CUIT__C = '30616275905';
        insert acc;

        Account productor = Test_TestUtils.crearProductor();
        CrearCompraController.acc = productor;

        Test.startTest();
        List<LookupSearchResult> results = SolicitarLicencia.searchAccounts('33693450239', new List<String>());
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    @isTest
    static void testGetButtonData() {
        Account acc = Test_TestUtils.crearObtentor(false);
        acc.N_CUIT__C = '30616275905';
        insert acc;

        Account productor = Test_TestUtils.crearProductor();
        CrearCompraController.acc = productor;

        Test.startTest();
        Map<String, Object> data = SolicitarLicencia.getButtonData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assert(data.containsKey('marcas'));
        System.assert(data.containsKey('isPortalComercio'));
        System.assert(data.containsKey('isPortalObtentor'));
    }

    @isTest
    static void testGetData_WithRecordId() {
        Account acc = Test_TestUtils.crearObtentor(false);
        acc.N_CUIT__C = '30616275905';
        insert acc;

        Account productor = Test_TestUtils.crearProductor();
        CrearCompraController.acc = productor;

        SolicitarLicencia.Data data = SolicitarLicencia.getTestData(acc.id, productor.N_CUIT__C);
        SolicitarLicencia.solicitar(JSON.serialize(data));

        Licencia__c licencia = [SELECT Id FROM Licencia__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SolicitarLicencia.getData(licencia.Id, false, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('licencia'));
        System.assert(result.containsKey('files'));
        System.assert(result.containsKey('filesData'));
        System.assert(result.containsKey('needsPoder'));
    }

    @isTest
    static void testGetData_WithTercero() {
        Account acc = Test_TestUtils.crearObtentor(false);
        acc.N_CUIT__C = '30616275905';
        insert acc;

        Account productor = Test_TestUtils.crearProductor();
        CrearCompraController.acc = productor;

        Account terceroAccount = Test_TestUtils.crearDistribuidor();

        Test.startTest();
        Map<String, Object> result = SolicitarLicencia.getData(null, true, terceroAccount.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('tercero'));
    }
}