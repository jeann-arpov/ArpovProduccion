@isTest
public class LicenciaTriggerHandlerTest {
    public static testmethod void main() {
        Account GDM = Test_TestUtils.crearObtentor(false);
        GDM.N_CUIT__C = '30616275905';
        GDM.Emite_Carta_de_Aceptacion__c = true;

        Account SYN = Test_TestUtils.crearObtentor(false);
        SYN.N_CUIT__C = '30646328450';
        SYN.Emite_Carta_de_Aceptacion__c = true;
        SYN.Id_Obtentor__c = '12';
        SYN.Clave_Unica__c = 'obtentor2';

        insert new List<Account>{GDM, SYN};

        Account productor = Test_TestUtils.crearProductor();
        CrearCompraController.acc = productor;

        SolicitarLicencia.solicitar(JSON.serialize(SolicitarLicencia.getTestData(GDM.id, productor.N_CUIT__C)));
        SolicitarLicencia.solicitar(JSON.serialize(SolicitarLicencia.getTestData(SYN.id, productor.N_CUIT__C)));

        List<Licencia__c> licencias = [select Name, id from Licencia__c];

        System.assertEquals(2, licencias.size());

        for (Licencia__c licencia: licencias) {
            licencia.Estado__c = 'Licencia Firmada';
        }

        Test.startTest();
        update licencias;
        Test.stopTest();

        System.assert(SolicitarLicencia.getLicenciaFiles(licencias[1].id).containsKey(licencias[1].Name + '-Carta de Aceptacion'));
    }
}