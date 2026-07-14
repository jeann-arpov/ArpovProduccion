global with sharing class BatchApexEnvioEmails implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    
    global Database.QueryLocator start(Database.BatchableContext BC){

        //Armamos una Query para Obtener todas las remesas programadas para la fecha de hoy cuyo modo de envio sea
        //el email
        
        //Obtenemos la fecha de hoy
        Date today = Date.today();

        //Variable que contendra el estado de las remesas que debemos considerar
        String estado = 'Programado';
        
        //Variable que contendra el modo de envio de las remesas que debemos considerar    
        String modoEnvio = 'Correo_Electronico';
        
        //Armamos la Query
        String qry = 'SELECT Contacto__c, Id, Fecha_programada_de_envio__c, Remesa__r.Id, Remesa__r.Lote__r.ID_Plantilla_Email__c, Fecha_de_envio__c, Remesa__r.Productor__r.Operador__r.Email FROM Contacto_Remesa__c WHERE Fecha_programada_de_envio__c = :today AND Estado__c = :estado AND Remesa__r.RecordType.DeveloperName = :modoEnvio';
        
        //Retornamos el resultado de la consulta
        return Database.getQueryLocator(qry);
    }
    
    global void execute(Database.BatchableContext BC, List<Contacto_Remesa__c> scope){
        
        //Recorremos los contactos de remesa y coleccionamos los Email de los operadores en caso que existan

        //Map para almacenar el email de los operadores y a que remesa pertenecen
        Map<Id,String> emailOperadores = new Map<Id,String>();

        for(Contacto_Remesa__c contacto : scope){

            //Verificamos si tenemos un productor
            if(contacto.Remesa__r.Productor__r != null){

                //Verificamos si tenemos un Operador seteado
                if(contacto.Remesa__r.Productor__r.Operador__r != null){

                    //Si el email no es nulo, lo agregamos al Set
                    if(contacto.Remesa__r.Productor__r.Operador__r.Email != null){
                        
                        emailOperadores.put(contacto.Remesa__r.Id, contacto.Remesa__r.Productor__r.Operador__r.Email);

                    }

                }

            }

        }

        //Obtengo los registros del objeto OrgWideEmailAddress cuyos campos Address se corresponda con 
        //las direcciones que estan en el Set

        //Creamos un map que nos ayude a asociar el email con el registro OrgWideEmailAddress rapidamente
        Map<String, OrgWideEmailAddress> orgWideEmails = new Map<String,OrgWideEmailAddress>(); 

        for(OrgWideEmailAddress orgWideEmail : [SELECT Id,Address FROM OrgWideEmailAddress WHERE Address IN :emailOperadores.values()]){

            orgWideEmails.put(orgWideEmail.Address, orgWideEmail);

        }

        //Recorremos nuevamente las remesas y enviamos los email
        for(Contacto_Remesa__c contacto : scope){

            //Variable que contendra la OrgWideEmailAddress
            OrgWideEmailAddress orgWideEmail = null;

            //Verificamos si la remesa esta en el map
            if(emailOperadores.containsKey(contacto.Remesa__r.Id)){

                //Obtenemos el email del operador
                String emailOperador = emailOperadores.get(contacto.Remesa__r.Id);

                //Verificamos si esta en el map el id
                if(orgWideEmails.containsKey(emailOperador)){

                    //Obtenemos la ORG
                    orgWideEmail = orgWideEmails.get(emailOperador);

                }   

            }

            //remesa.Fecha_de_envio__c = Datetime.now();
            
            try{
                
                //Hacemos el intento de enviar el email
                sendMail(contacto,orgWideEmail);

                //Si el email se envia, seteamos el estado a enviado
                //remesa.Estado__c = 'Enviado';
            
            } catch (Exception e) {
                
                //Si ocurre un error al intenter enviar el email, seteamos el estado de la remesa como error
                contacto.Estado__c = 'Error';
                
                //Agregamos el detalle de error en la remesa
                contacto.Detalle_de_error__c = e.getMessage();
            
            }

        }    
        update scope;
    
    }
    
    global void finish(Database.BatchableContext BC){
    
    }
    
    private void sendMail(Contacto_Remesa__c c, OrgWideEmailAddress orgWideEmail){
        
        //Obtenemos el lote de la remesa
        Lote__c lote = c.Remesa__r.Lote__r;
            
        //Obtenemos el Email Template
        EmailTemplate emailTemplate = [Select Subject, Body From EmailTemplate Where Id = :lote.ID_Plantilla_Email__c];
        
        //Obtenemos los Attachments
        
        //Lista que contendra los attachaments
        List<Attachment> attachments = new List<Attachment>();
        
        for(Attachment a : [SELECT Name, ContentType, Body FROM Attachment WHERE ParentId = :c.Remesa__r.Id]){
            attachments.add(a);
        }
        
        //Creamos el Email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        //Seteamos algunos datos
        mail.setUseSignature(false);
        mail.setSaveAsActivity(true);          
        mail.setTemplateId(emailTemplate.ID);
        mail.setTargetObjectId(c.Contacto__c);
        mail.setWhatId(c.Id);

        //Verificamos si es que no se va a a usar la direccion default de la org
        if(orgWideEmail != null){
            mail.setOrgWideEmailAddressId(orgWideEmail.Id);
        }
        
        //Adjuntamos los attachments al email
        List<Messaging.Emailfileattachment> fileAttachments = new List<Messaging.Emailfileattachment>();
        
        for (Attachment adjunto : attachments){
            //Instanciamos un EmailFileAttachment
            Messaging.Emailfileattachment efa = new Messaging.Emailfileattachment();
            efa.setFileName(adjunto.Name);
            efa.setBody(adjunto.Body);
            fileAttachments.add(efa);
        }
        
        mail.setFileAttachments(fileAttachments);
        
        if(! Test.IsRunningTest() ){      
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
        
        //generateTracking(r, emailTemplate, attachments);
                
    }
    
    
}