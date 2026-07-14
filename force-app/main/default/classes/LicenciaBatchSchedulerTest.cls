@isTest
private class LicenciaBatchSchedulerTest {
    @isTest
    static void testSchedulerRunsBatch() {
        // Programar el scheduler
        Test.startTest();
        String cronExp = '0 0 0 15 3 ?'; // cron dummy para test
        System.schedule('Test LicenciaBatchScheduler', cronExp, new LicenciaBatchScheduler());
        Test.stopTest();
    }
}