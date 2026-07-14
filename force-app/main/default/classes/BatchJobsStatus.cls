public with sharing class BatchJobsStatus {

    public List<BatchJob> batchJobs;
    public String idJob {get; set;}
    public String nameApexClass {get; set;}
    public Integer qty {get; set;}
    private Date today;


    public BatchJobsStatus(){
        today = Date.today();
    }
    
    public List<BatchJob> getBatchJobs(){

        batchJobs = new List<BatchJob>();
        
        List<AsyncApexJob> jobs = null;

        if(String.isNotEmpty(idJob)){
            jobs = [SELECT TotalJobItems, Status, NumberOfErrors, MethodName, JobType, JobItemsProcessed, Id, CreatedDate, CreatedById, CompletedDate, ApexClassId, ApexClass.Name,ExtendedStatus FROM AsyncApexJob WHERE Id = :idJob AND DAY_ONLY(CreatedDate) = :today ORDER BY CreatedDate DESC ];
        }else if(String.isNotEmpty(nameApexClass)){
            jobs = [SELECT TotalJobItems, Status, NumberOfErrors, MethodName, JobType, JobItemsProcessed, Id, CreatedDate, CreatedById, CompletedDate, ApexClassId, ApexClass.Name,ExtendedStatus FROM AsyncApexJob WHERE ApexClass.Name = :nameApexClass AND DAY_ONLY(CreatedDate) = :today ORDER BY CreatedDate DESC];
        }

        //System.debug(LoggingLevel.WARN, jobs);

        //Query the Batch apex jobs
        if(qty == null){
            for(AsyncApexJob a : jobs){
        
                Double itemsProcessed = a.JobItemsProcessed;
                Double totalItems = a.TotalJobItems;
     
                BatchJob j = new BatchJob();
                j.job = a;
     
                if(totalItems == 0){
                    j.percentComplete = 0;
                }else{
                    j.percentComplete = ((itemsProcessed  / totalItems) * 100.0).intValue();
                }
     
                batchJobs.add(j);
            
            }
        } else {
            AsyncApexJob a;
            for(Integer i = 0; i < qty && i < jobs.size(); i++){
                
                a = jobs.get(i);
                Double itemsProcessed = a.JobItemsProcessed;
                Double totalItems = a.TotalJobItems;
     
                BatchJob j = new BatchJob();
                j.job = a;
     
                if(totalItems == 0){
                    j.percentComplete = 0;
                }else{
                    j.percentComplete = ((itemsProcessed  / totalItems) * 100.0).intValue();
                }
     
                batchJobs.add(j);
            
            }
        }
        
        
        return batchJobs;
    
    }
    


    public class BatchJob{
        public AsyncApexJob job {get; set;}
        public Integer percentComplete {get; set;}
    }
    
    
}