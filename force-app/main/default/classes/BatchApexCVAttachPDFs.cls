global with sharing class BatchApexCVAttachPDFs implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global List<String> cvIds;
    public List<String> errors;
    
    global BatchApexCVAttachPDFs (List<String> cvIds){
        this.cvIds = cvIds;
        this.errors = new List<String>();
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([SELECT Id, Name FROM ERPvs__Comprobante_Venta__c WHERE Id IN :cvIds]);
    }
    
    global void execute(Database.BatchableContext BC, List<ERPvs__Comprobante_Venta__c> scope){

        Map<Id, List<String>> errorsByCV = new Map<Id, List<String>>();

        List<Attachment> attachemtsToInsert = new List<Attachment>();

        Set<Id> idsCVs = new Set<Id>();

        Set<Id> idsAttachment = new Set<Id>();

        // Obtenemos los ids de las remesas
        for(ERPvs__Comprobante_Venta__c cv : scope){
            idsCVs.add(cv.Id);        
        }

        // Verificamos si las mismas tienen adjuntos
        for(Attachment a : [SELECT ParentId FROM Attachment WHERE ParentId IN :idsCVs]){

            // Si el id esta lo agreguo a la lista
            idsAttachment.add(a.ParentId);

        }
        
        System.debug(LoggingLevel.WARN, 'idsAttachment: ' + idsAttachment);
        System.debug(LoggingLevel.WARN, 'idsCVs: ' + idsCVs);
        
        // Recorro las oportunidades
        for(ERPvs__Comprobante_Venta__c cv : scope){

            // Si esta el PDF, no proceso
            if(idsAttachment.contains(cv.Id)){
                continue;
            }

            try{
                
                // Generamos la URL
                PageReference pdfPage = Page.ERPvs__printSalesElectronicInvoice;
                
                // Seteamos el Id
                pdfPage.getParameters().put('id', cv.Id);
                
                // Instanciamos un attachment
                Attachment pdf = new Attachment();

                // Seteamos los atributos
                pdf.Name = cv.Name + '.pdf';
                pdf.ParentId = cv.Id;
                pdf.Body = (Test.isRunningTest())?Blob.valueOf('test'):pdfPage.getContent();
                pdf.ContentType  = 'application/pdf';    
                
                attachemtsToInsert.add(pdf);
            
            }catch(Exception e){

                System.debug(LoggingLevel.WARN, String.format('Error al intentar generar el PDF para el CV Record Id {0}. {1}', new List<String>{cv.Id, e.getMessage()}));
                errors.add(String.format('Error al intentar generar el PDF para el CV Record Id {0}. {1}', new List<String>{cv.Id, e.getMessage()}));

            }
        }

        // Intentamos crear los PDFS
        if(!attachemtsToInsert.isEmpty()){
            
            List<Database.SaveResult> svrs = Utils.insertList(attachemtsToInsert, false);

            // Recorremos los resultados
            for(Integer i = 0; i < svrs.size(); i++){

                Database.SaveResult svr = svrs[i];
                Attachment attach = attachemtsToInsert[i];

                // Si hay error, lo marcamos
                if(!svr.isSuccess()){

                    for(Database.Error e : svr.getErrors()){
                        System.debug(LoggingLevel.WARN, String.format('Error al intentar insertar el PDF para el CV Record Id {0}. {1}', new List<String>{attach.ParentId, e.getMessage()}));
                        errors.add(String.format('Error al intentar insertar el PDF para el CV Record Id {0}. {1}', new List<String>{attach.ParentId, e.getMessage()}));
                    }

                }

            }

        }

    }
    
    global void finish(Database.BatchableContext bctx){

        String systemErrors = BatchErrorHelper.getBatchClassErrors(bctx);
        
        if(systemErrors != ''){
            errors.add(systemErrors);
        }
    
        if(!errors.isEmpty()){ // Si ocurrio un error se notifica via email
        
            String message = String.join(errors, '\n');

            System.debug(LoggingLevel.WARN, message);

            try{

                List<String> destinatariosErroresBatchs = BatchErrorHelper.getDestinatariosErroresBatchs();

                if(destinatariosErroresBatchs.isEmpty()){
                    return;
                }

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(destinatariosErroresBatchs);
                mail.setSubject('Errores en BatchApexCVAttachPDFs');
                mail.setPlainTextBody(message);
                mail.setSaveAsActivity(false);
                if(!Test.isRunningTest()){
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }
                  
            }catch(Exception e){}  

        }
    
        
    
    }
    
}