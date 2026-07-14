global without sharing class BatchApexCVsEnviarEmails implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    //Test_CVsEnviarMails
    private Set<String> cvIds;
    private Date fecha;

    private static Map<String, String> templateToEmail = new Map<String, String> {
        'FE Productores SE' => 'facturacion@sembraevolucion.com.ar',
        'FE Productores SE a vencer' => 'facturacion@sembraevolucion.com.ar',
        'FE Productores' => 'facturacion@arpov.org.ar',
        'Cesión Tns - Falta Licencia' => 'gestion@sembraevolucion.com.ar',
        'Cesión Tns - Finalización Destinatario / Originante' => 'gestion@sembraevolucion.com.ar',
        'Cesión Tns - Finalización Destinatario' => 'gestion@sembraevolucion.com.ar'
    };

    private static transient List<OrgWideEmailAddress> orgWideEmails = [SELECT Id,Address FROM OrgWideEmailAddress WHERE Address in: templateToEmail.values()];
    
    global BatchApexCVsEnviarEmails(Date fecha){
        this.fecha = fecha;
    }
    
    global BatchApexCVsEnviarEmails(Set<String> cvIds){
        this.cvIds = cvIds;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        String qry = 'SELECT Id, Name, ERPvs__Cliente__c, ERPvs__Empresa_Sucursal__c FROM ERPvs__Comprobante_Venta__c WHERE ERPvs__Contabilizar__c = true';
        
        if(cvIds != null){
            qry += ' AND Id IN :cvIds';
        }

        if(fecha != null){
            qry += ' AND ERPvs__Fecha__c = :fecha';
        }
        //Retornamos el resultado de la consulta
        return Database.getQueryLocator(qry);
    }
    
    global void execute(Database.BatchableContext BC, List<ERPvs__Comprobante_Venta__c> scope){
        envioMails(scope, true);
    }

    @InvocableMethod(label='Envio de Emails a Comprobantes' description='Envia emails con la plantilla y attachment de la factura a los cvs correspondientes' category='ERPvs__Comprobante_Venta__c')
    public static void envioMails(List<Id> scope) {
        envioMails([SELECT Name, ERPvs__Cliente__c, ERPvs__Empresa_Sucursal__c FROM ERPvs__Comprobante_Venta__c WHERE id in: scope], true);
    }

    public static Map<Id, List<Contact>> cvsToEmailContacts(List<ERPvs__Comprobante_Venta__c> cvs) {
        Map<Id, Set<Id>> cvsToAccounts = new Map<Id, Set<Id>>();

        Set<Id> allAccounts = new Set<Id>();
        Set<ID> SEIds = new Set<Id>();

        for(ERPvs__Comprobante_Venta__c cv : cvs) {
            cvsToAccounts.put(cv.Id, new Set<Id>{cv.ERPvs__Cliente__c});
            allAccounts.add(cv.ERPvs__Cliente__c);
            
            if (cv.ERPvs__Empresa_Sucursal__c == UtilsMovimientoFondo.parametro.Punto_de_Venta_cyo_SE__c) {
                SEIds.add(cv.id);
            }
        }

        //si es de SE, tiene que tener funcion de contacto con sembra_evolucion en true. Si es de SRE, no tiene que tener funcion de contacto con sembra_evolucion en true
        Map<Id, List<Contact>> accountContactsSRE = getAccountContactsSRE(allAccounts);
        Map<Id, List<Contact>> accountContactsSE = getAccountContactsSE(allAccounts);

        Map<Id, List<Contact>> cvToContacts = new Map<Id, List<Contact>>();

        for(ERPvs__Comprobante_Venta__c cv : cvs) {
            cvToContacts.put(cv.Id, new List<Contact>());
            for (Id accountId: cvsToAccounts.get(cv.Id)) {
                Map<Id, List<Contact>> accountContacts = SEIds.contains(cv.id) ? accountContactsSE : accountContactsSRE;
                
                if (accountContacts.containsKey(accountId)) {
                    cvToContacts.get(cv.Id).addAll(accountContacts.get(accountId));
                }
            }
        }

        Map<Id, List<Id>> userCvs = new Map<Id, List<Id>>();

        //agrego tmb el comercio
        for(ERPvs__Comprobante_Venta__c cv : [select Oportunidad__r.Compra_HT__r.Venta_HT__r.CreatedById from ERPvs__Comprobante_Venta__c where id in: SEIds and Oportunidad__r.Compra_HT__r.Venta_HT__c != null]) {
            Id userId = cv.Oportunidad__r.Compra_HT__r.Venta_HT__r.CreatedById;
            
            if (userCvs.containsKey(userId) == false) {
                userCvs.put(userId, new List<Id>());
            }

            userCvs.get(userId).add(cv.id);
        }

        for (User u: [SELECT Contact.Id, Contact.Name, Contact.AccountId, Contact.Email FROM User WHERE id in: userCvs.keySet() and contact.email != null]) {
            for (Id cvId: userCvs.get(u.id)) {
                cvToContacts.get(cvId).add(u.Contact);
            }
        }

        return cvToContacts;
    }

    private static Map<Id, List<Contact>> getAccountContacts(Set<Id> accountIds) {
        return groupByAccount([SELECT Id, Name, AccountId, Email FROM Contact WHERE AccountId IN :accountIds AND Email != null AND IsEmailBounced = false AND Activo__c = True]);
    }

    public static Map<Id, List<Contact>> getAccountContactsSE(Set<Id> accountIds) {
        return Test.isRunningTest() ? getAccountContacts(accountIds) : groupByAccount([SELECT Id, Name, AccountId, Email FROM Contact WHERE AccountId IN :accountIds AND Email != null AND IsEmailBounced = false AND Activo__c = True and id in (select contacto__c from funcion_de_contacto__c where sembra_evolucion__c = true or Contacto__r.Contacto_Sembra__c = true)]);
    }

    public static Map<Id, List<Contact>> getAccountContactsSRE(Set<Id> accountIds) {
        return Test.isRunningTest() ? getAccountContacts(accountIds) : groupByAccount([SELECT Id, Name, AccountId, Email FROM Contact WHERE AccountId IN :accountIds AND Email != null AND IsEmailBounced = false AND Activo__c = True AND Contacto_SRE__c = true and id not in (select contacto__c from funcion_de_contacto__c where sembra_evolucion__c = true or Contacto__r.Contacto_Sembra__c = true)]);
    }


    /*private static Map<Id, Funcion_de_Contacto__c> getFuncionesContacto(Map<Id, List<Contact>> accountContacts) {
        List<Contact> contacts = new List<Contact>();

        for (List<Contact> conts: accountContacts.values()) {
            contacts.addAll(conts);
        }

        Map<Id, Funcion_de_Contacto__c> funcionesContacto = new Map<Id, Funcion_de_Contacto__c>();

        for (Funcion_de_Contacto__c funcion: [select Contacto__c, Sembra_Evolucion__c from Funcion_de_Contacto__c where contacto__c in: contacts]) {
            funcionesContacto.put(funcion.Contacto__c, funcion);
        }

        return funcionesContacto;
    }*/

    private static Map<Id, List<Contact>> groupByAccount(List<Contact> contacts) {
        Map<Id, List<Contact>> accountContacts = new Map<Id, List<Contact>>();

        for(Contact c : contacts) {
            if (!accountContacts.containsKey(c.AccountId)) accountContacts.put(c.AccountId, new List<Contact>());
            accountContacts.get(c.AccountId).add(c);
        }

        return accountContacts;
    }

    private static void envioMails(List<ERPvs__Comprobante_Venta__c> scope, Boolean saveFecha) {
        envioMails(scope, saveFecha, null);
    }

    public static void envioMails(List<ERPvs__Comprobante_Venta__c> scope, Boolean saveFecha, String templateOverride) {
        Map<Id, List<Contact>> cvToContacts = cvsToEmailContacts(scope);

        List<MailConfig> mailConfigs = new List<MailConfig>();

        for(ERPvs__Comprobante_Venta__c cv : scope) {
            MailConfig conf = new MailConfig(cv, cvToContacts.get(cv.Id), templateOverride);

            if (conf.contacts.isEmpty() == false) {
                mailConfigs.add(conf);
            }
        }

        sendEmails(mailConfigs, saveFecha);
    }
    
    global void finish(Database.BatchableContext BC){
    
    }

    static void sendEmails(List<MailConfig> mailConfigs, Boolean saveFecha) {
        if (mailConfigs.isEmpty()) return;

        Map<String, EmailTemplate> templates = getTemplates(mailConfigs);
        Map<Id, List<Attachment>> attachmentsMap = getAttachments(mailConfigs);
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();

        for (MailConfig conf: mailConfigs) {
            OrgWideEmailAddress orgWideEmail = getEmailForTemplate(conf.template);
            EmailTemplate emailTemplate = templates.get(conf.template);
            List<Attachment> attachments = attachmentsMap.get(conf.cv.Id);

            //Creamos el mail y le agregamos los attachments
            for(Contact c : conf.contacts){
                Messaging.SingleEmailMessage mail = makeEmail(orgWideEmail, emailTemplate, attachments, c.Id, conf.cv.Id);
                mails.add(mail);
            }
        }


        if(! Test.IsRunningTest() ){    
            try {
                Map<Id, Boolean> hadError = new Map<Id, Boolean>();
                Messaging.SendEmailResult[] mailResult = Messaging.sendEmail(mails, false);

                for (Integer i = 0; i < mailResult.size(); i++) {
                    Messaging.SendEmailResult res = mailResult[i];
                    Messaging.SingleEmailMessage mail = mails[i];

                    if (res.isSuccess() == false) {
                        System.debug(LoggingLevel.INFO, 'ser: ' + res.getErrors()[0].getMessage());
                        hadError.put(mail.getWhatId(), true);
                    }
                }

                List<ERPvs__Comprobante_Venta__c> cvToUpdate = new List<ERPvs__Comprobante_Venta__c>();

                for (MailConfig conf: mailConfigs) {
                    if (hadError.containsKey(conf.cv.Id) == false && saveFecha) {
                        conf.cv.ERPvs__No_controlar__c = true;
                        conf.cv.Fecha_envio_mail__c = Date.today();
                        cvToUpdate.add(conf.cv);
                    }
                }

                update cvToUpdate;

                for(ERPvs__Comprobante_Venta__c cv : cvToUpdate) cv.ERPvs__No_controlar__c = false;
                
                update cvToUpdate;
            } catch(System.EmailException emlEx) {
                System.debug(LoggingLevel.INFO, 'emlEx: ' + emlEx.getMessage()); 
            }
        }
    }

    public static Messaging.SingleEmailMessage makeEmail(OrgWideEmailAddress orgWideEmail, EmailTemplate emailTemplate, List<Attachment> attachments, Id targetId, Id whatId) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        //Seteamos algunos datos
        mail.setUseSignature(false);
        mail.setSaveAsActivity(false);          
        mail.setTemplateId(emailTemplate.ID);
        mail.setTargetObjectId(targetId);
        mail.setWhatId(whatId); 

        if(orgWideEmail != null){
            mail.setOrgWideEmailAddressId(orgWideEmail.Id);
        }
        
        if (attachments != null) {
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
        }

        return mail;
    }

    static Map<String, EmailTemplate> getTemplates(List<MailConfig> mailConfigs) {
        Map<String, EmailTemplate> templates = new Map<String, EmailTemplate>();

        for (MailConfig conf: mailConfigs) {
            templates.put(conf.template, null);
        }

        for (EmailTemplate emailTemplate: [Select Subject, Body, Name From EmailTemplate Where Name in: templates.keySet()]) {
            templates.put(emailTemplate.Name, emailTemplate);
        }

        return templates;
    }

    static Map<Id, List<Attachment>> getAttachments(List<MailConfig> mailConfigs) {
        Map<Id, List<Attachment>> attachments = new Map<Id, List<Attachment>>();

        for (MailConfig conf: mailConfigs) {
            attachments.put(conf.cv.Id, new List<Attachment>());
        }

        for(Attachment a : [SELECT ParentId, Name, ContentType, Body FROM Attachment WHERE ParentId in: attachments.keySet() and ContentType = 'application/pdf']){
            attachments.get(a.ParentId).add(a);
        }

        return attachments;
    }

    class MailConfig {
        ERPvs__Comprobante_Venta__c cv;
        Boolean isSE;
        String template;
        List<Contact> contacts;
        
        public MailConfig(ERPvs__Comprobante_Venta__c cv, List<Contact> contacts, String templateOverride) {
            this.cv = cv;
            this.isSE = cv.ERPvs__Empresa_Sucursal__c == UtilsMovimientoFondo.parametro.Punto_de_Venta_cyo_SE__c;
            this.template = String.isBlank(templateOverride) ? (isSE ? 'FE Productores SE' : 'FE Productores') : templateOverride;
            this.contacts = contacts;
        }
    }


    public static OrgWideEmailAddress getEmailForTemplate(String template) {
        for (OrgWideEmailAddress email: orgWideEmails) {
            if (templateToEmail.get(template) == email.Address) return email;
        }

        return null;
    }
}