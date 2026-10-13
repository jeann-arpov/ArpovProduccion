@IsTest
public with sharing class InformarPagoControllerTest {
  @isTest
  static void testemail() {
    ContentVersion content = new ContentVersion();
    content.Title = 'test';
    content.VersionData = Blob.valueOf('test');
    content.PathOnClient = 'test';
    insert content;

    // String contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :content.Id].ContentDocumentId;

    Test.startTest();
    InformarPagoController.sendEmail(
      new Map<String, String>{ 'Description' => 'Test' },
      new List<Id>{ content.Id }
    );
    Test.stopTest();
  }

  @IsTest
  static void test() {
    Test.startTest();
    InformarPagoController.createCase(
      new Map<String, String>{ 'Description' => 'Test' },
      null,
      null
    );
    Test.stopTest();
  }

  @isTest
  static void test2() {
    Account productor = Test_TestUtils.crearProductor();

    Test.startTest();
    InformarPagoController.createCasePPH(
      new Map<String, String>{ 'Description' => 'Test2' },
      null,
      productor.Id
    );
    Test.stopTest();
  }

  @isTest
  static void testdelete() {
    ContentVersion content = new ContentVersion();
    content.Title = 'test';
    content.VersionData = Blob.valueOf('test');
    content.PathOnClient = 'test';
    insert content;

    String contentDocumentId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :content.Id
    ]
    .ContentDocumentId;

    Test.startTest();
    InformarPagoController.deleteDocument(contentDocumentId);
    Test.stopTest();
  }

  @isTest
  static void informarPagoFactura_actualizaEstadoYAsociaDocs() {
    Account productor = Test_TestUtils.crearProductor();

    Opportunity opp = new Opportunity(
      Name = 'Factura Test',
      StageName = 'Facturada',
      CloseDate = Date.today(),
      AccountId = productor.Id,
      N_de_Comprobante__c = 'A-0001-00000001',
      Fecha_Emision_Comprobante__c = Date.today()
    );
    insert opp;

    ContentVersion cv = new ContentVersion(
      Title = 'comprobante',
      VersionData = Blob.valueOf('test'),
      PathOnClient = 'comprobante.pdf'
    );
    insert cv;
    Id contentDocumentId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
    ]
    .ContentDocumentId;

    Test.startTest();
    InformarPagoController.informarPagoFactura(
      opp.Id,
      new List<Id>{ contentDocumentId },
      new List<Id>{ cv.Id },
      'Comentario de prueba'
    );
    System.assertEquals(1, Limits.getEmailInvocations());
    Test.stopTest();

    Opportunity result = [
      SELECT Pago_Informado__c, Fecha_Pago_Informado__c
      FROM Opportunity
      WHERE Id = :opp.Id
    ];
    System.assertEquals(true, result.Pago_Informado__c);
    System.assertNotEquals(null, result.Fecha_Pago_Informado__c);

    List<ContentDocumentLink> links = [
      SELECT Id
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :opp.Id AND ContentDocumentId = :contentDocumentId
    ];
    System.assertEquals(1, links.size());
  }
}
