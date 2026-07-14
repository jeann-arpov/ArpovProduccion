@isTest
public class ReportExporterTest {
    @IsTest (seeAllData = true)
    static void testReportExporter() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ReportExporterMock());
        ReportExporter.exportReportAndUpload('Licencias_Enlist_Aprobadas_LnP');
        Test.stopTest();
    }
}