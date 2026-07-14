@isTest
public with sharing class ReportExporterSchedulerTest {
    @isTest
    static void testScheduler(){
        test.startTest();
        Test.setMock(HttpCalloutMock.class, new ReportExporterMock());
        ReportExporterScheduler m = new ReportExporterScheduler();
        String jobID = System.schedule('Test', '20 30 8 10 2 ?', m);
        test.stopTest();
    }
}