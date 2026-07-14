@isTest
public class PDFLicenciaControllerTest {
    @isTest static void test(){
        Account obtentor = Test_TestUtils.crearObtentor();
        obtentor.BillingCity = 'Buenos Aires';
        update obtentor;

        Account productor = Test_TestUtils.crearProductor();

        Licencia__c licencia = new Licencia__c();
        licencia.Name = 'GMD000097783743';
        licencia.Email__c = 'test@test.com';
        licencia.LicenciaId__c = 'sdsfsdfw1d';
        licencia.Cuenta_Obtentor__c = obtentor.Id;
        licencia.Created__c = Date.today();
        licencia.Cuenta_Productor__c = productor.Id;
        licencia.Localidad__c = 'Olivos';
        insert licencia;

        PageReference vf = Page.pdfLicencia;
        Test.setCurrentPage(vf);

        ApexPages.currentPage().getParameters().put('id', licencia.Id);

        PDFLicenciaController controller = new PDFLicenciaController();

        controller.getAddressAndDate();
        controller.getTodayDate();
        controller.getIsCuil();
        controller.getNameFirmante();
        controller.getDomicilioCompleto();
    }
}