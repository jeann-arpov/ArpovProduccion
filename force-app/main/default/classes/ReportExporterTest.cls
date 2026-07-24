@isTest
public class ReportExporterTest {
    // WI-000010 SE-50 Magoya: emails adicionales + carpetas GCS licencias/contactos
    @IsTest (seeAllData = true)
    static void testReportExporter() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ReportExporterMock());
        ReportExporter.exportReportAndUpload('Licencias_Enlist_Aprobadas_LnP');
        Test.stopTest();
    }
}