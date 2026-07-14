public without sharing class InformarPagoController {
    @AuraEnabled
    public static void sendEmail(Map<String,Object> caseFields, List<Id> versionIds){
        try {
            // String contentVersionId = [SELECT LatestPublishedVersionId FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1].LatestPublishedVersionId;
            OrgWideEmailAddress recipient = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE DisplayName = 'Cobranzas' LIMIT 1];

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { recipient.Address });

            //a consultar desde que email deberia enviarse
            OrgWideEmailAddress owd = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE Address = 'info@sembraevolucion.com.ar'];

            mail.setOrgWideEmailAddressId(owd.Id);

            mail.setSubject((String) caseFields.get('Subject'));

            mail.setPlainTextBody((String) caseFields.get('Description'));

            mail.setEntityAttachments(versionIds);

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createCase(Map<String,Object> caseFields, Id contentDocumentId, Id opportunityId){

        Case c = new Case();
        c.Factura__c = opportunityId;
        c.Reason = 'Informar Pago';

        for(String fields : caseFields.keySet()){
            c.put(fields,caseFields.get(fields));
        }

        insert c;


        ContentDocumentLink cDocumentLink = new ContentDocumentLink();
        cDocumentLink.LinkedEntityId = (c!=null) ? c.Id : null;
        cDocumentLink.ContentDocumentId = contentDocumentId;
        cDocumentLink.Visibility = 'AllUsers';
        cDocumentLink.ShareType = 'V';
        if (!Test.isRunningTest()) insert cDocumentLink;

    }

    @AuraEnabled
    public static void createCasePPH(Map<String,Object> caseFields, Id contentDocumentId, String accountId){
        
        Case c = new Case();
        c.RecordTypeId = Schema.sObjectType.Case.getRecordTypeInfosByDeveloperName().get('Portal').getRecordTypeId();
        c.Reason = 'PPH';
        c.AccountId = accountId;

        for(String fields : caseFields.keySet()){
            c.put(fields,caseFields.get(fields));
        }

        insert c;

        c = [SELECT Subject, CaseNumber FROM Case WHERE Id = :c.Id];
        c.Subject = c.Subject + ' ' + c.CaseNumber;
        update c;

        if(!String.isBlank(contentDocumentId)){
            ContentDocumentLink cDocumentLink = new ContentDocumentLink();
            cDocumentLink.LinkedEntityId = (c!=null) ? c.Id : null;
            cDocumentLink.ContentDocumentId = contentDocumentId;
            cDocumentLink.Visibility = 'AllUsers';
            cDocumentLink.ShareType = 'V';
            if (!Test.isRunningTest()) insert cDocumentLink;
        }
    }

    @AuraEnabled
    public static void deleteDocument(String docId){
        try{                    
            ContentDocument cd = new ContentDocument(Id = docId);
            delete cd;
                  
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}