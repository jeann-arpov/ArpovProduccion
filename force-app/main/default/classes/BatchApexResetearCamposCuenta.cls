/**
* @author Maximo Martinez
* @date 16/09/2018
* @description Clase Batcheable que Genera Avisos de Vencimientos de Facturas
*/
public with sharing class BatchApexResetearCamposCuenta implements Database.Batchable<sObject>, Database.Stateful{
    
    public List<String> errors = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id FROM Account');
    }

    public void execute(Database.BatchableContext BC, List<Account> scope) {

        for(Account acc : scope){
            acc.DUPs_Lote_Caidos_Verano__c = 0;
            acc.DUPs_Lote_Caidos_Invierno__c = 0;
            acc.DUPs_creadas_camp_Verano__c = 0;
            acc.DUPs_creadas_camp_Invierno__c = 0;
        }

        List<Database.SaveResult> svsrs = Database.update(scope,false);

        for(Database.SaveResult svr : svsrs){

            if(!svr.isSuccess()){
                this.errors.add(svr.getErrors()[0].getMessage());
            }
                
        }

    }

    public void finish(Database.BatchableContext BC) {

        List<String> destinatariosErroresBatchs = BatchErrorHelper.getDestinatariosErroresBatchs();

        String systemErrors = BatchErrorHelper.getBatchClassErrors(BC);
        
        if(systemErrors != ''){
            errors.add(systemErrors);
        }
    
        if(!errors.isEmpty()){ // Si ocurrio un error se notifica via email
        
            String message = String.join(errors, '\n');

            System.debug(LoggingLevel.INFO,message);

            try{

                if(destinatariosErroresBatchs.isEmpty()){
                    return;
                }

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(destinatariosErroresBatchs);
                mail.setSubject('Arpov: Errores en BatchApexResetearCamposCuenta');
                mail.setPlainTextBody(message);
                mail.setSaveAsActivity(false);
                if(!Test.isRunningTest()){
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }
                  
            }catch(Exception e){}  


        }

        Database.executeBatch(new BatchApexSetCamposTransEnCuenta(),1000);

    }

}