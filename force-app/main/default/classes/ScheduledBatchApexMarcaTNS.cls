public with sharing class ScheduledBatchApexMarcaTNS implements Schedulable {

    public void execute(SchedulableContext sc){
        BatchApexMarcarTNS batch = new BatchApexMarcarTNS();
        Database.executeBatch(batch);
    }
}