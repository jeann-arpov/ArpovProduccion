/**
* @description: helper para saber si un batch o una serie de batch de mismo class name tuvieron algun system error
* @createdDate: 16/6/2016
* @author: Julian
*/
public class BatchErrorHelper{
    
    /**
    * @param batchJobId: id del batch para obtener la class name
    * @param desde: fecha desde la cual mirar
    * @param resultado: string con los errores de los batch con esa class name a partir de la fecha dada. De no haber, se retorna ''
    * @return
    */
    public static String getBatchClassErrors(Id batchJobId, DateTime desde){
        String body = '';
        
        List<AsyncApexJob> myJobs = [select id, ApexClass.Name from AsyncApexJob where id =: batchJobId limit 1];
        
        if(myJobs.size() > 0 ){
            AsyncApexJob myJob = myJobs[0];
            for(AsyncApexJob job: [select Id, Status, ApexClass.Name, CompletedDate, NumberOfErrors, ExtendedStatus from AsyncApexJob where ApexClass.Name =: myJob.ApexClass.Name and CompletedDate >=: desde and ((Status = 'Completed' and NumberOfErrors > 0) or Status = 'Failed' )]){

               body+= getErrorFromJob(job);

            }    
        }
        
        return body;
        
    }

    /**
    * @param batchJobId: id del batch para ver si tiro error
    * @param resultado: string con los errores de ese batch. De no haber, se retorna ''
    */
    public static String getBatchClassErrors(Id batchJobId){
        
        List<AsyncApexJob> jobs = [select Id, ApexClass.Name, Status, CompletedDate, NumberOfErrors, ExtendedStatus from AsyncApexJob where id =: batchJobId  and ((Status = 'Completed' and NumberOfErrors > 0) or Status = 'Failed') limit 1];

        if(jobs.size() == 1){
            return getErrorFromJob(jobs[0]);
        }
        
        return '';

    }   
    
    public static String getBatchClassErrors(Database.BatchableContext BC){
        return getBatchClassErrors(BC.getJobId());
    }
    
    public static String getBatchClassErrors(Database.BatchableContext BC, DateTime desde){
        return getBatchClassErrors(BC.getJobId(), desde);
    } 

    public static String getErrorFromJob(AsyncApexJob job){
        if(job == null) return '';
        return String.format('The batch Apex job {0} with id {1} {2} with {3} errors : {4} \n', new List<String>{job.ApexClass.Name, job.Id, job.Status, String.valueOf(job.NumberOfErrors), job.ExtendedStatus});
    }
    
    /**
    * @author Maximo Martinez
    * @date 05/07/2016
    * @description Devuelve la lista de destinatarios de emails, que recibiran los errores del batchs
    */
    public static List<String> getDestinatariosErroresBatchs(){

    	// Coleccionamos la lista de emails
        Set<String> toAddress = new Set<String>();

    	// Obtenemos la lista de emails a enviar los errores
        List<Destinatarios_Errores_Batchs__c> destinatarios = [SELECT Name, Email__c FROM Destinatarios_Errores_Batchs__c];

        if(destinatarios.isEmpty()){
            return new List<String>(toAddress);
        }

        for(Destinatarios_Errores_Batchs__c d : destinatarios){
        	toAddress.add(d.Email__c);    
        }

        return new List<String>(toAddress);

    }

    public static String getError(List<String> str) {
        String error = '';
        
        for (String s: str) {
            if (String.isBlank(s) == false) error += s + '\n';
        }

        return error;
    }

    public static Boolean sendEmail(Id batchJobId, List<String> errors, String subject) {
        String systemErrors = BatchErrorHelper.getBatchClassErrors(batchJobId);
        errors.add(systemErrors);
        return sendEmail(getError(errors), subject);
    }


    public static Boolean sendEmail(String body, String subject) {
        return sendEmail(body, subject, BatchErrorHelper.getDestinatariosErroresBatchs());
    }


    public static Boolean sendEmail(String body, String subject, List<String> recipients) {
        try {
            System.debug(body);
            if (recipients.isEmpty() || String.isBlank(body)) return false;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(recipients);
            mail.setSubject(subject);
            mail.setPlainTextBody(body);
            mail.setSaveAsActivity(false);
            if(!Test.isRunningTest()){
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
        } catch (Exception e) {
            System.debug(e);
        }      
        
        sentEmails++;
        return true;
    }

    public static List<String> getErrors(List<Database.DeleteResult> results, List<Sobject> records) {
        List<String> errors = new List<String>();

        for (Integer i = 0; i < results.size(); i++) {
            Database.DeleteResult res = results[i];
            Sobject sobj = records != null && records.size() > i ? records[i] : null;
            if (res.success == false) errors.addAll(getErrors(res.getErrors(), sobj));
        }

        return errors;
    }

    private static List<String> getErrors(List<Database.Error> databaseErrors, Sobject sobj) {
        List<String> errors = new List<String>();
        
        if (sobj != null) errors.add('Error en el objeto: ' + JSON.serializePretty(sobj));

        for (Database.Error err: databaseErrors) {
            errors.add(err.getMessage() + ' ' + err.getFields());
        }

        return errors;
    }

    public static List<String> getErrors(List<Database.SaveResult> results, List<Sobject> records) {
        List<String> errors = new List<String>();

        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult res = results[i];
            Sobject sobj = records != null && records.size() > i ? records[i] : null;
            if (res.success == false) errors.addAll(getErrors(res.getErrors(), sobj));
        }

        return errors;
    }

    public static List<String> getErrors(List<Database.DeleteResult> results) {
        return getErrors(results, null);
    }

    public static List<String> getErrors(List<Database.SaveResult> results) {
        return getErrors(results, null);
    }

    public static Integer sentEmails = 0;

}