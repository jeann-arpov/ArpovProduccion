@IsTest
public with sharing class ViewPDFControllerTest {
    
    @IsTest
    static void test(){

        PageReference myVfPage = Page.viewPdf;
        Test.setCurrentPage(myVfPage);
        
        Case cse=new Case();
        insert cse;
 
        Attachment attach=new Attachment();   	
    	attach.Name='Unit Test Attachment';
    	Blob bodyBlob=Blob.valueOf('Unit Test Attachment Body');
    	attach.body=bodyBlob;
        attach.parentId=cse.id;
        insert attach;

        ApexPages.currentPage().getParameters().put('documentId',attach.Id);

        ViewPDFController ctrl = new ViewPDFController();
        System.assertNotEquals(ctrl.pdf,null);
        
    }

    @IsTest
    static void methodName(){

        PageReference myVfPage = Page.viewPdf;
        Test.setCurrentPage(myVfPage);
        
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Penguins',
            PathOnClient = 'Penguins.jpg',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert contentVersion;

        ApexPages.currentPage().getParameters().put('documentId',[SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1].ContentDocumentId);

        ViewPDFController ctrl = new ViewPDFController();
        System.assertNotEquals(ctrl.pdf,null);
        
    }

}