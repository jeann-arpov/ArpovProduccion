@isTest
private class Test_BacthsLotes{

    static testMethod void myUnitTest() {
        
        BatchJobs controller = new BatchJobs();
        controller.getBatchJobs();
        
        SchdEliminarBatchsLotes schd = new SchdEliminarBatchsLotes();
        schd.eliminarBatchsLotes();
        
    }
    
}