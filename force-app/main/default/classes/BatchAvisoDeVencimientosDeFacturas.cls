/**
* @author Maximo Martinez
* @date 07/06/2018
* @description Clase Batcheable que Genera Avisos de Vencimientos de Facturas
*/
global class BatchAvisoDeVencimientosDeFacturas implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    //Test_BatchAvisoDeVencimientosDeFacturas
    public List<String> errors;
    private Date startDate;
    private Date endDate;

    /**
    * IMPORTANTE: SI ESTA VARIABLE ESTA EN FALSE EL ENVIO DE EMAIL SE HACE A LOS USUARIOS DEL CAMPO Operador_de_Cobranza__c
    * SI ESTA EN TRUE SE HACE A LOS USUARIOS CARGADOS EN EL CUSTOM SETTINGS Destinatarios_Errores_Batchs__c
    */
    private Boolean isTest;
    private List<String> destinatariosErroresBatchs;
    
    global BatchAvisoDeVencimientosDeFacturas(Boolean isTest, Date startDate, Date endDate) {
        this.errors = new List<String>();
        this.startDate = startDate;
        this.endDate = endDate;
        this.isTest = isTest;
        this.destinatariosErroresBatchs = BatchErrorHelper.getDestinatariosErroresBatchs();
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id, Operador_de_Cobranza__c, Operador_de_Cobranza__r.Email, (SELECT Id FROM Contacts WHERE Email != null and id not in (select contacto__c from funcion_de_contacto__c where sembra_evolucion__c = true or Contacto__r.Contacto_Sembra__c = true)), (SELECT Id, Obtentor__r.Factura_por_Cuenta_y_Orden__c, Tipo_de_Comprobante__c, Saldo_a_Cobrar_Comprobante__c, Total_Comprobante__c, Fecha_Vencimiento_Comprobante__c, Cultivo__c FROM Opportunities WHERE Saldo_a_Cobrar_Comprobante__c > 0 AND ( Tipo_de_Comprobante__c = 'FC' OR Tipo_de_Comprobante__c = 'ND') AND ( Fecha_Vencimiento_Comprobante__c =:startDate OR Fecha_Vencimiento_Comprobante__c =:endDate ) ) FROM Account WHERE Operador_de_Cobranza__c != null]);
    }

    global void execute(Database.BatchableContext BC, List<Account> scope) {

        Map<String,List<Opportunity>> oppsByKey = new Map<String,List<Opportunity>>();

        Map<Id,Account> accountsByIds = new Map<Id,Account>(scope);

        // Ids Opportunities
        Set<Id> idsOpportunities = new Set<Id>();

        // Map de PDFs de Comprovantes de Ventas por Id de Opportunities
        Map<Id,Id> pdfsIdsByOppsIds = new Map<Id,Id>();

        Map<Id,Attachment> attachamentsByIds = new Map<Id,Attachment>();

        Set<String> emailOperadores = new Set<String>();

        // Lista con los emails a enviar en este lote
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Coleccionamos los ids de los cultivos, porque de ahi vamos a buscar la campaña activa y de la campaña sacaremos
        // el template para enviar los emails
        Set<String> namesCultivos = new Set<String>();

        // Templates by cultivo
        Map<String,String> emailTemplateByCultivoName = new Map<String,String>();

        // Recorremos los registros y nos quedamos con los registros que cumplen las condiciones
        for(Account a : scope){

            for(Opportunity o : a.Opportunities){

                // Solo nos quedamos con las Opportunidades que cumplen con Saldo_a_Cobrar_Comprobante__c  =  Total_Comprobante__c 
                if(o.Saldo_a_Cobrar_Comprobante__c  !=  o.Total_Comprobante__c){
                    continue;
                }

                if(a.Operador_de_Cobranza__r != null){
                    emailOperadores.add(a.Operador_de_Cobranza__r.Email);
                }    

                String key = String.valueOf(a.Id) + '_' + String.valueOf(o.Fecha_Vencimiento_Comprobante__c) + '_' + o.Cultivo__c;

                if(!oppsByKey.containsKey(key)){
                    oppsByKey.put(key,new List<Opportunity>());
                }

                oppsByKey.get(key).add(o);

                // Coleccionamos el Id de las Opportunidades, para ir a buscar los comprobantes de Venta y obtener sus PDFs
                idsOpportunities.add(o.Id);

                namesCultivos.add(o.Cultivo__c);

            }

        }

        // Obtenemos el wide address para cada direccion del operador
        Map<String, OrgWideEmailAddress> orgWideEmails = new Map<String,OrgWideEmailAddress>(); 

        for(OrgWideEmailAddress orgWideEmail : [SELECT Id,Address FROM OrgWideEmailAddress WHERE Address IN :emailOperadores]){

            orgWideEmails.put(orgWideEmail.Address, orgWideEmail);

        }

        System.debug(LoggingLevel.WARN, oppsByKey);
        System.debug(LoggingLevel.WARN, namesCultivos);

        for(Cultivo__c c : [SELECT Name, (SELECT Id, Fecha_de_Fin__c, Template_Aviso_de_Vencimientos__c  FROM Campanas_Agricolas__r WHERE Template_Aviso_de_Vencimientos__c != null ORDER BY Fecha_de_Fin__c DESC LIMIT 1) FROM Cultivo__c WHERE Name IN :namesCultivos]){

            if(!c.Campanas_Agricolas__r.isEmpty()){

                emailTemplateByCultivoName.put(c.Name,c.Campanas_Agricolas__r[0].Template_Aviso_de_Vencimientos__c);

            }

        }

        System.debug(LoggingLevel.WARN, emailTemplateByCultivoName);

        // Obtenemos los Ids de los Comprobantes de Venta, ya que necesitamos obtener sus PDFs Adjuntos
        // Como una Opportunity puede tener mas de un Comprobante, nos quedamos 
        for(ERPvs__Comprobante_Venta__c cv : [SELECT Id, Oportunidad__c, (SELECT Id FROM Attachments WHERE ContentType = 'application/pdf' LIMIT 1) FROM ERPvs__Comprobante_Venta__c WHERE Oportunidad__c IN :idsOpportunities AND Tipo_de_Movimiento__c  = 'FC']){

            if(cv.Attachments.isEmpty()){
                continue;
            }

            pdfsIdsByOppsIds.put(cv.Oportunidad__c,cv.Attachments[0].Id);

        }

        
        for(Attachment attch : [SELECT Id, Name, Body FROM Attachment WHERE Id IN :pdfsIdsByOppsIds.values()]){
            
            attachamentsByIds.put(attch.Id,attch);

        }

        // Recorremos los ids de las cuentas
        for(String key : oppsByKey.keySet()){

            String[] keyParts = key.split('_');

            if(keyParts.size() != 3){
                continue;
            }

            Id idAccount =  Id.valueOf(keyParts[0]);
            String dueDate = keyParts[1];
            String nameCultivo = String.valueOf(keyParts[2]);

            // Revisamos si esta la cuenta
            if(!accountsByIds.containsKey(idAccount)){
                continue;
            }

            // Revisamos si esta el template para el envio 
            if(!emailTemplateByCultivoName.containsKey(nameCultivo)){
                continue;
            }

            Account a = accountsByIds.get(idAccount);

            // Generamos la URL
            PageReference pdfPage = new PageReference(emailTemplateByCultivoName.get(nameCultivo));
            
            // Seteamos el Id de la cuenta
            pdfPage.getParameters().put('accountId',a.Id);

            // Seteamos la fecha de vencimiento asi solo mostramos las opps que nos importan
            pdfPage.getParameters().put('dueDate',dueDate);

            // Seteamos el cultivo asi solo mostramos las opps que nos importan
            pdfPage.getParameters().put('nameCultivo',nameCultivo);

            Blob htmlBody;

            System.debug(LoggingLevel.WARN, htmlBody);

            // Intentamos obtener el contenido, puede dar error
            try{
                htmlBody = (Test.isRunningTest())?Blob.valueOf('test'):pdfPage.getContent();
            }catch(Exception e){
                errors.add(String.format('Error al generar el email template {0} para la Cuenta Record Id {1} y fecha de vencimiento {2}. Detalle del Error {3}.', new List<String>{'emailTemplateFacturasProximasAVencer',a.Id,dueDate, e.getMessage()}));
            } 

            // Si no pudimos obtener el contenido, procesamos la otra fecha
            if(htmlBody==null){
                continue;
            } 

            //Adjuntamos al Email los archivos
            List<Messaging.Emailfileattachment> fileAttachments = new List<Messaging.Emailfileattachment>();

            for(Opportunity o : oppsByKey.get(key)){

                // Verificamos si el obtentos tiene Obtentor__r.Factura_por_Cuenta_y_Orden__c en true
                // si es asi adjuntamos pdf
                if(o.Obtentor__r.Factura_por_Cuenta_y_Orden__c == false){
                    continue;
                }

                if(!pdfsIdsByOppsIds.containsKey(o.Id)){
                    continue;
                }

                Id idAttch = pdfsIdsByOppsIds.get(o.Id);

                if(!attachamentsByIds.containsKey(idAttch)){
                    continue;
                }

                Attachment attch = attachamentsByIds.get(idAttch);

                Messaging.Emailfileattachment efa = new Messaging.Emailfileattachment();
                efa.setFileName(attch.Name);
                efa.setBody(attch.Body);
                fileAttachments.add(efa);

            }

            
            // Una vez que tengo los pds que van adjuntos, tengo que mandar una copia a cada contacto de la cuenta
            for(Contact c : a.Contacts){
            
                // Creamos un MassEmailMessage
                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();

                // Si estamos en Test, no enviamos a los contactos
                if(!isTest){
                    msg.setUseSignature(false);
                    msg.setTargetObjectId(c.Id);
                    msg.setWhatId(a.Id);
                    msg.setSaveAsActivity(true);
                }else{
                    msg.setToAddresses(destinatariosErroresBatchs);
                }


                //Verificamos si es que no se va a a usar la direccion default de la org
                if(orgWideEmails.containsKey(a.Operador_de_Cobranza__r.Email)){
                    msg.setOrgWideEmailAddressId(orgWideEmails.get(a.Operador_de_Cobranza__r.Email).Id);
                }

                // Renderizamos la Visualforce
                msg.setHtmlBody(htmlBody.toString());
                
                msg.setSubject('Facturas próximas a vencer');

                if (!fileAttachments.isEmpty()) {
                    msg.setFileAttachments(fileAttachments);
                }

                msg.setReplyTo('cobranzas@arpov.org.ar');
                

                emailsToSend.add(msg);

            }


        }

        System.debug(LoggingLevel.WARN,emailsToSend);

        
        if(!emailsToSend.isEmpty()){

            List<Messaging.SendEmailResult> emailsResult = (Test.isRunningTest()) ? new List<Messaging.SendEmailResult>() : Messaging.sendEmail(emailsToSend, false);

            // Verificamos si ocurrio un error
            for (Messaging.SendEmailResult ser: emailsResult) {

                if(!ser.isSuccess()){

                    errors.add(String.format('Error al enviar Email. Error {0}.',new List<String>{ser.getErrors()[0].getMessage()}));

                }

            }

        }

    }
    
    global void finish(Database.BatchableContext BC) {
        BatchErrorHelper.sendEmail(BC.getJobId(), errors, 'Arpov: Errores en BatchAvisoDeVencimientosDeFacturas');
    }   
}