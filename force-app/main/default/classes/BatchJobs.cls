public class BatchJobs{
 
    public List<BatchJob> batchJobs;
    public Integer numberOfJobs {get; set;}
    public String loteId {get; set;}
 
    public List<BatchJob> getBatchJobs(){
        //Create new list of BatchJobs, a wrapper class that includes the job and percent complete.
        batchJobs = new List<BatchJob>();
 
        //If number of jobs was not defined, default to 20
        if(numberOfJobs== null || numberofJobs <= 0){
            numberofJobs = 20;
        }
        System.debug(LoggingLevel.INFO, 'loteId: ' + loteId); 
        Set<String> batchIds = new Set<String>();
        for(Batch_Lote__c bl : [SELECT ID_Batch__c FROM Batch_Lote__c WHERE Lote__c = :loteId]){
            batchIds.add(bl.ID_Batch__c);
        }
        System.debug(LoggingLevel.INFO, 'batchIds: ' + batchIds); 
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
            if(totalItems == 0){
                //A little check here as we don't want to divide by 0.
                j.percentComplete = 0;
            }else{
                j.percentComplete = ((itemsProcessed  / totalItems) * 100.0).intValue();
            }
 
            batchJobs.add(j);
        }
        return batchJobs;
    }
 
    //This is the wrapper class the includes the job itself and a value for the percent complete
    public Class BatchJob{
        public String name {get; set;}
        public String createdDate {get; set;}
        public String completedDate {get; set;}
        public String status {get; set;}
        public String extendedStatus {get; set;}
        public Integer percentComplete {get; set;}
    }
 
}