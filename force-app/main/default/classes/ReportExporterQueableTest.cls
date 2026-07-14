@isTest
public with sharing class ReportExporterQueableTest {
@isTest (seeAllData= true)
    static void testQueueable(){
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ReportExporterMock());
        System.enqueueJob(new ReportExporterQueable());
        Test.stopTest();
    }
}