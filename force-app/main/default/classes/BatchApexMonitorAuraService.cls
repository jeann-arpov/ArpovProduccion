public with sharing class BatchApexMonitorAuraService {
    
    @AuraEnabled
    public static List<BatchJob> getBatchJobs(Id batchId){

        List<BatchJob> batchJobs = new List<BatchJob>();

        Set<Id> batchIds = new Set<Id>{batchId};
        
        //Query the Batch apex jobs
        for(AggregateResult a : [SELECT SUM(TotalJobItems) TotalJobItems, SUM(JobItemsProcessed) JobItemsProcessed, Status, MIN(CreatedDate) CreatedDate, MAX(CompletedDate) CompletedDate, ApexClass.Name Name, MAX(ExtendedStatus) ExtendedStatus FROM AsyncApexJob WHERE ID IN :batchIds GROUP BY ApexClass.Name, Status, ID ORDER BY Status, ID DESC]){
            
            Double itemsProcessed = (Double)a.get('JobItemsProcessed');
            Double totalItems = (Double)a.get('TotalJobItems');
 
            BatchJob j = new BatchJob();
            j.name = (String)a.get('Name');
            j.createdDate = a.get('CreatedDate')!=null?((Datetime)a.get('CreatedDate')).format():'';
            j.completedDate = a.get('CompletedDate')!=null?((Datetime)a.get('CompletedDate')).format():'';
            j.status = (String)a.get('Status');
            j.extendedStatus = (String)a.get('ExtendedStatus');
 
            //Determine the pecent complete based on the number of batches complete
            j.percentComplete = (totalItems == 0) ? 0 : ((itemsProcessed  / totalItems) * 100.0).intValue();
 
            batchJobs.add(j);
            
        }

        return batchJobs;
    
    }
 
    //This is the wrapper class the includes the job itself and a value for the percent complete
    public class BatchJob{
        @AuraEnabled
        public String name {get; set;}
        @AuraEnabled
        public String createdDate {get; set;}
        @AuraEnabled
        public String completedDate {get; set;}
        @AuraEnabled
        public String status {get; set;}
        @AuraEnabled
        public String extendedStatus {get; set;}
        @AuraEnabled
        public Integer percentComplete {get; set;}
    }

}