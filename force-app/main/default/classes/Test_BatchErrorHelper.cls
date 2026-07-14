@isTest
public class Test_BatchErrorHelper{

    public static testmethod void main(){
        
        Destinatarios_Errores_Batchs__c dest = new Destinatarios_Errores_Batchs__c();
        dest.name = 'test';
        dest.email__c = 'email@email.com';
        insert dest;

        Test.startTest();
        
        Date dt = System.today();
        
        BatchApexGeneracionFacturas bc = new BatchApexGeneracionFacturas();
        
        Id jobId = Database.executeBatch(bc);

        Test.stopTest();                   
    
        System.assert(BatchErrorHelper.getBatchClassErrors(jobId) == '');
        System.assert(BatchErrorHelper.getBatchClassErrors(jobId,dt) == ''); 
        
        BatchErrorHelper.getErrorFromJob([select Id, Status, ApexClass.Name, CompletedDate, NumberOfErrors, ExtendedStatus from AsyncApexJob limit 1][0]);
        
        System.assert(BatchErrorHelper.sendEmail(jobId, new List<String>{'error'}, 'subject test'));

        Database.DeleteResult dr = (Database.DeleteResult)JSON.deserialize('{"success": false, "id": "001000000000000", "errors": [{"message": "error", "fields": []}]}', Database.DeleteResult.class);
        System.assertEquals(1, BatchErrorHelper.getErrors(new List<Database.DeleteResult>{dr}).size());

        Database.SaveResult sr = (Database.SaveResult)JSON.deserialize('{"success": false, "id": "001000000000000", "errors": [{"message": "error", "fields": []}]}', Database.SaveResult.class);
        System.assertEquals(1, BatchErrorHelper.getErrors(new List<Database.SaveResult>{sr}).size());
    }

}