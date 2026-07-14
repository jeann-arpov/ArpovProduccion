@isTest
public class ContentDocumentLinkTriggerTest {
    public static testmethod void main() {
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'Condiciones_Comerciales_03';
        docVersion.PathOnClient = docVersion.Title + '.pdf';
        docVersion.VersionData = Blob.valueOf('Test Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';
        insert docVersion;

        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Title =: docVersion.Title LIMIT 1];
        List<ContentDocumentLink> links = [select visibility from ContentDocumentLink where ContentDocumentId =: docQuery.ContentDocumentId limit 1];

        System.assertEquals(1, links.size(), 'Trigger should have made it all users');
        System.assertEquals(links[0].visibility, 'AllUsers', 'Trigger should have made it all users');
    }
    
    
    @isTest
    static void beforeInsertTyCDocuments() {
        Test.startTest();
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp TyC',
            StageName = 'Prospecting',
            Fecha_Emision_Comprobante__c = Date.today().addDays(30),
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'TyC_TestDocument';
        docVersion.PathOnClient = docVersion.Title + '.pdf';
        docVersion.VersionData = Blob.valueOf('Test TyC Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';

        insert docVersion;
        
        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :docVersion.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docQuery.ContentDocumentId;
        cdl.LinkedEntityId = opp.Id;
        cdl.ShareType = 'V';

        insert cdl;
        Test.stopTest();
        
        ContentDocumentLink insertedLink = [SELECT Visibility FROM ContentDocumentLink WHERE Id = :cdl.Id];
        System.assertEquals('AllUsers', insertedLink.Visibility, 'TyC document visibility should be AllUsers');
    }
    
    @isTest
    static void beforeInsertWithOpportunity() {
        Test.startTest();
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp FileName',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Tipo_de_Comprobante__c = 'FC',
            Fecha_Emision_Comprobante__c = Date.today().addDays(30),
            N_de_Comprobante__c = '001-001-0000123'
        );

        insert opp;
        
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'FC001-001-0000123';
        docVersion.PathOnClient = docVersion.Title + '.pdf';
        docVersion.VersionData = Blob.valueOf('Test FileName Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';

        insert docVersion;
        
        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :docVersion.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docQuery.ContentDocumentId;
        cdl.LinkedEntityId = opp.Id;
        cdl.ShareType = 'V';

        insert cdl;
        Test.stopTest();
        
        ContentDocumentLink insertedLink = [SELECT Visibility FROM ContentDocumentLink WHERE Id = :cdl.Id];
        System.assertEquals('AllUsers', insertedLink.Visibility, 'Document matching opportunity filename should have AllUsers visibility');
    }
    
    @isTest
    static void beforeInsertNoPdfDocument() {
        Test.startTest();
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp sin PDF',
            StageName = 'Prospecting',
            Fecha_Emision_Comprobante__c = Date.today().addDays(30),
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'Condiciones_Comerciales_NonPDF';
        docVersion.PathOnClient = docVersion.Title + '.docx';
        docVersion.VersionData = Blob.valueOf('Test Non PDF Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';

        insert docVersion;
        
        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :docVersion.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docQuery.ContentDocumentId;
        cdl.LinkedEntityId = opp.Id;
        cdl.ShareType = 'V';

        insert cdl;
        Test.stopTest();
        
        ContentDocumentLink insertedLink = [SELECT Visibility FROM ContentDocumentLink WHERE Id = :cdl.Id];
        System.assertNotEquals('AllUsers', insertedLink.Visibility, 'Non-PDF document should not have AllUsers visibility');
    }
    
    @isTest
    static void beforeInsertNoOpportunityEntity() {
        Test.startTest();
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'Condiciones_Comerciales_Account';
        docVersion.PathOnClient = docVersion.Title + '.pdf';
        docVersion.VersionData = Blob.valueOf('Test Account Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';

        insert docVersion;
        
        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :docVersion.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docQuery.ContentDocumentId;
        cdl.LinkedEntityId = acc.Id;
        cdl.ShareType = 'V';
        insert cdl;
        
        Test.stopTest();
        
        ContentDocumentLink insertedLink = [SELECT Visibility FROM ContentDocumentLink WHERE Id = :cdl.Id];
        System.assertNotEquals('AllUsers', insertedLink.Visibility, 'Non-Opportunity entity should not trigger visibility change');
    }
    
    @isTest
    static void afterInsertWithOpportunity() {
        Test.startTest();
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp After Insert',
            StageName = 'Prospecting',
            Fecha_Emision_Comprobante__c = Date.today().addDays(30),
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'TestDocument';
        docVersion.PathOnClient = docVersion.Title + '.pdf';
        docVersion.VersionData = Blob.valueOf('Test After Insert Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';
        insert docVersion;
        
        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :docVersion.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docQuery.ContentDocumentId;
        cdl.LinkedEntityId = opp.Id;
        cdl.ShareType = 'V';
        insert cdl;
        
        Test.stopTest();
        
        ContentDocumentLink insertedLink = [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE Id = :cdl.Id];
        System.assertEquals(opp.Id, insertedLink.LinkedEntityId, 'ContentDocumentLink should be linked to Opportunity');
    }
    
    @isTest 
    static void afterInsertWithVentaHT() {
        Test.startTest();
        
        Venta_HT__c venta = new Venta_HT__c(
            Name = 'Test Venta'
        );
        insert venta;
        
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'TestVentaDocument';
        docVersion.PathOnClient = docVersion.Title + '.pdf';
        docVersion.VersionData = Blob.valueOf('Test Venta Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';
        insert docVersion;
        
        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :docVersion.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docQuery.ContentDocumentId;
        cdl.LinkedEntityId = venta.Id;
        cdl.ShareType = 'V';
        insert cdl;
        
        Test.stopTest();
        
        ContentDocumentLink insertedLink = [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE Id = :cdl.Id];
        System.assertEquals(venta.Id, insertedLink.LinkedEntityId, 'ContentDocumentLink should be linked to Venta_HT__c');
    }
    
    @isTest
    static void beforeDelete() {
        Test.startTest();
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp Delete',
            StageName = 'Prospecting',
            Fecha_Emision_Comprobante__c = Date.today().addDays(30),
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'Condiciones_Comerciales_Delete';
        docVersion.PathOnClient = docVersion.Title + '.pdf';
        docVersion.VersionData = Blob.valueOf('Test Delete Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';
        insert docVersion;
        
        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :docVersion.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docQuery.ContentDocumentId;
        cdl.LinkedEntityId = opp.Id;
        cdl.ShareType = 'V';
        insert cdl;
        delete cdl;
        
        Test.stopTest();
        
        List<ContentDocumentLink> deletedLinks = [SELECT Id FROM ContentDocumentLink WHERE Id = :cdl.Id];
        System.assertEquals(0, deletedLinks.size(), 'ContentDocumentLink should be deleted');
    }
    
    @isTest
    static void afterUpdateAndDelete() {
        Test.startTest();
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp Update Delete',
            StageName = 'Prospecting',
            Fecha_Emision_Comprobante__c = Date.today().addDays(30),
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'TestUpdateDelete';
        docVersion.PathOnClient = docVersion.Title + '.pdf';
        docVersion.VersionData = Blob.valueOf('Test Update Delete Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';
        insert docVersion;
        
        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :docVersion.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docQuery.ContentDocumentId;
        cdl.LinkedEntityId = opp.Id;
        cdl.ShareType = 'V';
        insert cdl;
        
        delete cdl;
        
        Test.stopTest();
        
        List<ContentDocumentLink> deletedLinks = [SELECT Id FROM ContentDocumentLink WHERE Id = :cdl.Id];
        System.assertEquals(0, deletedLinks.size(), 'ContentDocumentLink should be deleted after delete');
    }
    
    @isTest
    static void afterUpdate() {
        Test.startTest();
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opp After Update',
            StageName = 'Prospecting',
            Fecha_Emision_Comprobante__c = Date.today().addDays(30),
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        ContentVersion docVersion = new ContentVersion();
        docVersion.Title = 'TestAfterUpdate';
        docVersion.PathOnClient = docVersion.Title + '.pdf';
        docVersion.VersionData = Blob.valueOf('Test After Update Content');
        docVersion.IsMajorVersion = true;
        docVersion.ContentLocation = 'S';
        insert docVersion;
        
        ContentVersion docQuery = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :docVersion.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docQuery.ContentDocumentId;
        cdl.LinkedEntityId = opp.Id;
        cdl.ShareType = 'V';
        insert cdl;
        
        opp.Name = 'Updated Test Opp';
        update opp;
        
        Test.stopTest();
        
        List<ContentDocumentLink> existingLinks = [SELECT Id FROM ContentDocumentLink WHERE Id = :cdl.Id];
        System.assertEquals(1, existingLinks.size(), 'ContentDocumentLink should still exist after opportunity update');
    }
    
    @isTest
    static void bulkOperations() {
        Test.startTest();
        
        List<Opportunity> opps = new List<Opportunity>();
        for(Integer i = 0; i < 5; i++) {
            opps.add(new Opportunity(
                Name = 'Bulk Test Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Fecha_Emision_Comprobante__c = Date.today().addDays(30),
                Tipo_de_Comprobante__c = 'FC',
                N_de_Comprobante__c = '001-001-000000' + i
            ));
        }
        insert opps;
        
        List<ContentVersion> docVersions = new List<ContentVersion>();
        for(Integer i = 0; i < 5; i++) {
            ContentVersion docVersion = new ContentVersion();
            docVersion.Title = 'Condiciones_Comerciales_Bulk_' + i;
            docVersion.PathOnClient = docVersion.Title + '.pdf';
            docVersion.VersionData = Blob.valueOf('Test Bulk Content ' + i);
            docVersion.IsMajorVersion = true;
            docVersion.ContentLocation = 'S';
            docVersions.add(docVersion);
        }
        insert docVersions;
        
        Map<Id, Id> versionToDocId = new Map<Id, Id>();
        for(ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :docVersions]) {
            versionToDocId.put(cv.Id, cv.ContentDocumentId);
        }
        
        List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
        for(Integer i = 0; i < 5; i++) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = versionToDocId.get(docVersions[i].Id);
            cdl.LinkedEntityId = opps[i].Id;
            cdl.ShareType = 'V';
            cdls.add(cdl);
        }
        insert cdls;
        
        Test.stopTest();
        
        Integer linksWithAllUsersVisibility = 0;
        for(ContentDocumentLink cdl : cdls) {
            List<ContentDocumentLink> insertedLinks = [SELECT Visibility FROM ContentDocumentLink WHERE Id = :cdl.Id];
            if(!insertedLinks.isEmpty() && insertedLinks[0].Visibility == 'AllUsers') {
                linksWithAllUsersVisibility++;
            }
        }
        System.assertEquals(5, linksWithAllUsersVisibility, 'All bulk documents should have AllUsers visibility');
    }
}