@IsTest
public with sharing class InformarPagoControllerTest {
    @isTest
    static void testemail(){
        ContentVersion content = new ContentVersion(); 
        content.Title='test'; 
        content.VersionData = Blob.valueOf('test');
        content.PathOnClient = 'test';
        insert content;

        // String contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :content.Id].ContentDocumentId;

        Test.startTest();
        InformarPagoController.sendEmail(new Map<String,String>{'Description'=>'Test'}, new List<Id>{content.Id});
        Test.stopTest();
    }
    
    @IsTest
    static void test(){
        
        Test.startTest();
        InformarPagoController.createCase(new Map<String,String>{'Description'=>'Test'},null,null);
        Test.stopTest();

    }
    
    @isTest
    static void test2(){
        
        Account productor = Test_TestUtils.crearProductor();
        
        Test.startTest();
        InformarPagoController.createCasePPH(new Map<String, String>{'Description' => 'Test2'}, null, productor.Id);
        Test.stopTest();
    }

    @isTest
    static void testdelete(){
        
        ContentVersion content = new ContentVersion(); 
        content.Title='test'; 
        content.VersionData = Blob.valueOf('test');
        content.PathOnClient = 'test';
        insert content;

        String contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :content.Id].ContentDocumentId;

        Test.startTest();
        InformarPagoController.deleteDocument(contentDocumentId);
        Test.stopTest();
    }

}