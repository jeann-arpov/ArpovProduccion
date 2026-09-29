public without sharing class InformarPagoController extends ApexErrorHandler {
  private static final Integer MAX_FILE_SIZE_BYTES = 26214400; // 25 MB

  @AuraEnabled
  public static void sendEmail(
    Map<String, Object> caseFields,
    List<Id> versionIds
  ) {
    try {
      // String contentVersionId = [SELECT LatestPublishedVersionId FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1].LatestPublishedVersionId;
      OrgWideEmailAddress recipient = [
        SELECT Id, Address, DisplayName
        FROM OrgWideEmailAddress
        WHERE DisplayName = 'Cobranzas'
        LIMIT 1
      ];

      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      mail.setToAddresses(new List<String>{ recipient.Address });

      //a consultar desde que email deberia enviarse
      OrgWideEmailAddress owd = [
        SELECT Id, Address, DisplayName
        FROM OrgWideEmailAddress
        WHERE Address = 'info@sembraevolucion.com.ar'
      ];

      mail.setOrgWideEmailAddressId(owd.Id);

      mail.setSubject((String) caseFields.get('Subject'));

      mail.setPlainTextBody((String) caseFields.get('Description'));

      mail.setEntityAttachments(versionIds);

      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    } catch (Exception e) {
      throw handleException(e, 'ERR-FAC-001', 'InformarPago');
    }
  }

  @AuraEnabled
  public static void informarPagoFactura(
    Id opportunityId,
    List<Id> contentDocumentIds,
    List<Id> contentVersionIds,
    String comentarios
  ) {
    try {
      Opportunity opp = [
        SELECT Id, N_de_Comprobante__c, CUIT__c, Account.Name, Account.N_CUIT__c
        FROM Opportunity
        WHERE Id = :opportunityId
        LIMIT 1
      ];

      if (contentVersionIds != null && !contentVersionIds.isEmpty()) {
        for (ContentVersion cv : [
          SELECT Id, ContentSize
          FROM ContentVersion
          WHERE Id IN :contentVersionIds
        ]) {
          if (cv.ContentSize > MAX_FILE_SIZE_BYTES) {
            throw new AuraHandledException(
              'Uno o más archivos superan el tamaño máximo permitido (25 MB).'
            );
          }
        }
      }

      if (contentDocumentIds != null && !contentDocumentIds.isEmpty()) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id docId : contentDocumentIds) {
          links.add(
            new ContentDocumentLink(
              LinkedEntityId = opportunityId,
              ContentDocumentId = docId,
              Visibility = 'AllUsers',
              ShareType = 'V'
            )
          );
        }
        insert links;
      }

      opp.Pago_Informado__c = true;
      opp.Fecha_Pago_Informado__c = System.now();
      update opp;

      sendEmailToCobranzas(opp, contentVersionIds, comentarios);
    } catch (Exception e) {
      throw handleException(e, 'ERR-FAC-001', 'InformarPago');
    }
  }

  private static void sendEmailToCobranzas(
    Opportunity opp,
    List<Id> versionIds,
    String comentarios
  ) {
    String cuit = (opp.Account != null &&
      opp.Account.N_CUIT__c != null)
      ? opp.Account.N_CUIT__c
      : opp.CUIT__c;
    String razonSocial = opp.Account != null ? opp.Account.Name : '';
    String numeroFactura = opp.N_de_Comprobante__c;

    String body =
      'Se informó el pago de la siguiente factura:\n' +
      'CUIT: ' +
      cuit +
      '\n' +
      'Razón Social / Cuenta: ' +
      razonSocial +
      '\n' +
      'N° de Factura: ' +
      numeroFactura +
      '\n' +
      (String.isNotBlank(comentarios) ? '\nComentarios: ' + comentarios : '');

    OrgWideEmailAddress recipient = [
      SELECT Id, Address
      FROM OrgWideEmailAddress
      WHERE DisplayName = 'Cobranzas'
      LIMIT 1
    ];
    OrgWideEmailAddress owd = [
      SELECT Id
      FROM OrgWideEmailAddress
      WHERE Address = 'info@sembraevolucion.com.ar'
    ];

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new List<String>{ recipient.Address });
    mail.setOrgWideEmailAddressId(owd.Id);
    mail.setSubject('Informar Pago - ' + razonSocial + ' - ' + numeroFactura);
    mail.setPlainTextBody(body);
    if (versionIds != null && !versionIds.isEmpty()) {
      mail.setEntityAttachments(versionIds);
    }
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
  }

  @AuraEnabled
  public static void createCase(
    Map<String, Object> caseFields,
    Id contentDocumentId,
    Id opportunityId
  ) {
    Case c = new Case();
    c.Factura__c = opportunityId;
    c.Reason = 'Informar Pago';

    for (String fields : caseFields.keySet()) {
      c.put(fields, caseFields.get(fields));
    }

    insert c;

    ContentDocumentLink cDocumentLink = new ContentDocumentLink();
    cDocumentLink.LinkedEntityId = (c != null) ? c.Id : null;
    cDocumentLink.ContentDocumentId = contentDocumentId;
    cDocumentLink.Visibility = 'AllUsers';
    cDocumentLink.ShareType = 'V';
    if (!Test.isRunningTest())
      insert cDocumentLink;
  }

  @AuraEnabled
  public static void createCasePPH(
    Map<String, Object> caseFields,
    Id contentDocumentId,
    String accountId
  ) {
    Case c = new Case();
    c.RecordTypeId = Schema.sObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('Portal')
      .getRecordTypeId();
    c.Reason = 'PPH';
    c.AccountId = accountId;

    for (String fields : caseFields.keySet()) {
      c.put(fields, caseFields.get(fields));
    }

    insert c;

    c = [SELECT Subject, CaseNumber FROM Case WHERE Id = :c.Id];
    c.Subject = c.Subject + ' ' + c.CaseNumber;
    update c;

    if (!String.isBlank(contentDocumentId)) {
      ContentDocumentLink cDocumentLink = new ContentDocumentLink();
      cDocumentLink.LinkedEntityId = (c != null) ? c.Id : null;
      cDocumentLink.ContentDocumentId = contentDocumentId;
      cDocumentLink.Visibility = 'AllUsers';
      cDocumentLink.ShareType = 'V';
      if (!Test.isRunningTest())
        insert cDocumentLink;
    }
  }

  @AuraEnabled
  public static void deleteDocument(String docId) {
    try {
      ContentDocument cd = new ContentDocument(Id = docId);
      delete cd;
    } catch (Exception e) {
      throw handleException(e, 'ERR-FAC-001', 'InformarPago');
    }
  }
}
