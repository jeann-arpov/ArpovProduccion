public without sharing class ViewPDFController {

    public Id documentId;

    public String contentType {get;set;}

    public ViewPDFController(){
        contentType = 'application/pdf';
        documentId = ApexPages.currentPage().getParameters().get('documentId');
    }

    public Blob getBody() {
       
        List<Attachment> atts = [SELECT Body, ContentType, Name FROM Attachment WHERE Id = :documentId];

        if(!atts.isEmpty()){
            return atts[0].Body;
        }

        List<ContentVersion> objVersions = [SELECT Id, VersionData FROM ContentVersion WHERE ContentDocumentId = :documentId];

        if(!objVersions.isEmpty()){
            return objVersions[0].VersionData;
        }

        return null;
    
    }
    public String pdf {
        get {
            return  EncodingUtil.Base64Encode(getBody());
        }
    }
}