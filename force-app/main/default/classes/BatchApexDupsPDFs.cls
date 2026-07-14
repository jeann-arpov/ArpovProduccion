global with sharing class BatchApexDupsPDFs implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global Lote__c lote;
    public List<String> errors;
    
    global BatchApexDupsPDFs(Lote__c lote){
        this.lote = lote;
        this.errors = new List<String>();
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([SELECT Id, Name FROM Remesa__c WHERE Lote__c = :lote.ID]);
    }
    
    global void execute(Database.BatchableContext BC, List<Remesa__c> scope){

        Map<Id, List<String>> errorsByRemesa = new Map<Id, List<String>>();

        List<Attachment> attachemtsToInsert = new List<Attachment>();

        Set<Id> idsRemesas = new Set<Id>();

        Set<Id> idsAttachment = new Set<Id>();

        // Obtenemos los ids de las remesas
        for(Remesa__c r : scope){
            idsRemesas.add(r.Id);        
        }

        // Verificamos si las mismas tienen adjuntos
        for(Attachment a : [SELECT ParentId FROM Attachment WHERE ParentId IN :idsRemesas]){

            // Si el id esta lo agreguo a la lista
            idsAttachment.add(a.ParentId);

        }
        
        // Recorro las oportunidades
        for(Remesa__c r : scope){

            // Si esta el PDF, no proceso
            if(idsAttachment.contains(r.Id)){
                continue;
            }

            try{
                
                // Generamos la URL
                PageReference pdfPage = Page.dupPdf;
                
                // Seteamos el Id
                pdfPage.getParameters().put('remesaId',r.Id);
                
                // Instanciamos un attachment
                Attachment pdf = new Attachment();

                // Seteamos los atributos
                pdf.Name = r.Name + '.pdf';
                pdf.ParentId = r.Id;
                pdf.Body = (Test.isRunningTest())?Blob.valueOf('test'):pdfPage.getContent();
                pdf.ContentType  = 'application/pdf';    
                
                attachemtsToInsert.add(pdf);
            
            }catch(Exception e){

                errors.add(String.format('Error al intentar generar el PDF para la Remesa Record Id {0}. {1}', new List<String>{r.Id, e.getMessage()}));

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
                        errors.add(String.format('Error al intentar insertar el PDF para la Remesa__c Record Id {0}. {1}', new List<String>{attach.ParentId, e.getMessage()}));
                    }

                }

            }

        }

    }
    
    global void finish(Database.BatchableContext bctx){

        try{
            lote.Lote_Procesado__c = true;
            update lote;
        }catch(Exception e){
            errors.add(String.format('Error al actualizar el Lote Record Id {0}. {1}.', new List<String>{lote.Id,e.getMessage()}));
        }

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
                mail.setSubject('Errores en BatchApexDupsPDFs');
                mail.setPlainTextBody(message);
                mail.setSaveAsActivity(false);
                if(!Test.isRunningTest()){
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }
                  
            }catch(Exception e){}  

        }
    
        
    
    }
    
}