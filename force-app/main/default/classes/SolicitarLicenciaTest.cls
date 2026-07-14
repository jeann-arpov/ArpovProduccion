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
}