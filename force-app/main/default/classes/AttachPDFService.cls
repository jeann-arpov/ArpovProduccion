@RestResource(urlMapping='/AttachPDF/*')
global class AttachPDFService {
    
    @HttpPost
    global static void AttachPDFtoRecordREST(List<String> recordsId) {
        
        // Revisamos el tipo de id
        if(recordsId.isEmpty()){
            return;
        }        

        String recordId = recordsId[0];

        Schema.SObjectType type = Utils.getObjectTypeById(recordId);

        if(Utils.getObjectTypeByObjectName('Remesa__c') == type){
            atachPDFToRemesas(recordsId);
        }else if(Utils.getObjectTypeByObjectName('Opportunity') == type){
            atachPDFToOpportunities(recordsId);    
        }


    }
  
    // call this method from your Batch Apex
    global static void attachPdfToRecord(List<Id> recordsId ){
        System.debug(LoggingLevel.INFO, 'recordsId: ' + recordsId); 
        
        String serializedObject = '{ "recordsId": [';
        Integer i = 0;
        for(Id recordId : recordsId){
            if(i != 0){
                serializedObject += ',';
            }
            serializedObject += '"' + recordId + '"';
            i++;
        }
        serializedObject += '] }';
        
        Parametros_REST__c param = Parametros_REST__c.getOrgDefaults();
        
        JSONObject oauth = new JSONObject();
        
        if(param != null && param.Instance_URL__c != null && param.client_id__c != null && param.client_secret__c != null && param.username__c != null && param.password__c != null){
            oauth = oauthLogin(param.Instance_URL__c, param.client_id__c, param.client_secret__c, param.username__c, param.password__c);
        } 
        
        String accessToken = oauth.access_token;
        String instanceUrl = oauth.instance_url;
        
        String addr = instanceUrl + '/services/apexrest/AttachPDF/';
        
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http http = new Http();
        
        req.setEndpoint( addr );
        req.setMethod('POST');
        req.setHeader('Authorization', 'OAuth ' + accessToken);
        req.setHeader('Content-Type', 'application/json; charset=utf-8');
        req.setBody(serializedObject);
        req.setTimeout(120000);
        System.debug(LoggingLevel.INFO, 'req: ' + req); 
        System.debug(LoggingLevel.INFO, 'req.getBody: ' + req.getBody()); 
        try {
            System.debug(LoggingLevel.INFO, 'Llamada REST'); 
            if(! Test.IsRunningTest() ){
                res = http.send(req);
                System.debug(LoggingLevel.INFO, 'Response: ' + res); 
            }
        } catch(System.CalloutException e) {
            System.debug(LoggingLevel.INFO, 'Callout error: '+ e); 
            System.debug(LoggingLevel.INFO, res.toString()); 
        }   
    }
    
    private static JSONObject oauthLogin(String loginUri, String clientId,
        String clientSecret, String username, String password) {
        HttpRequest req = new HttpRequest(); 
 
        req.setMethod('POST');
        req.setEndpoint(loginUri+'/services/oauth2/token');
        req.setTimeout(120000);
        req.setBody('grant_type=password' +
            '&client_id=' + clientId +
            '&client_secret=' + clientSecret +
            '&username=' + EncodingUtil.urlEncode(username, 'UTF-8') +
            '&password=' + EncodingUtil.urlEncode(password, 'UTF-8'));
    
        Http http = new Http();
        
        if(! Test.IsRunningTest() ){  
            HTTPResponse res = http.send(req);

            System.debug('BODY: '+res.getBody());
            System.debug('STATUS:'+res.getStatus());
            System.debug('STATUS_CODE:'+res.getStatusCode());
            
            return (JSONObject)JSON.deserialize(res.getBody(), JSONObject.class);
        } else {
            return new JSONObject();
        }
    }
    
    public class JSONObject{
         public String access_token;
         public String instance_url;
         public String id;
         public String issued_at;
         public String signature;
    }

    /**
    * @author Facundo Luna
    * @date 04/02/2016
    * @description Metodo que atachea PDF a Remesas
    */
    private static void atachPDFToRemesas(List<String> recordsId){

        List<Remesa__c> remesas = [SELECT ID, Name FROM Remesa__c WHERE ID IN :recordsId];
        
        Map<String, String> mapRemesaName = new Map<String, String>();
        
        for(Remesa__c r : remesas){
            mapRemesaName.put(r.ID, r.Name);
        }
        
        List<Attachment> attachments = new List<Attachment>();
        
        for(String recordId : recordsId){
        
            PageReference pdfPage = new PageReference('/apex/dupPdf');
            pdfPage.getParameters().put('remesaId',recordId);
            Attachment pdf = new Attachment();
            pdf.Name = mapRemesaName.get(recordId) + '.pdf';
            pdf.ParentId = recordId;
            if(!Test.IsRunningTest() ){            
                pdf.Body = pdfPage.getContent();
            } else {
                pdf.Body = Blob.valueOf('test');
            }
            pdf.ContentType  = 'application/pdf';    
            attachments.add(pdf);
        }

        if(!attachments.isEmpty()){
            Utils.insertList(attachments);
        }

    }

    /**
    * @author Maximo Martinez
    * @date 04/02/2016
    * @description Metodo que atachea PDF a Opportunidades
    */
    private static void atachPDFToOpportunities(List<String> recordsId){

        List<Opportunity> opportunities = [SELECT Id, Name FROM Opportunity WHERE Id IN :recordsId];
        
        Map<String, String> mapOpportunitiesByName = new Map<String, String>();
        
        for(Opportunity o : opportunities){
            // Marcamos las opportunidades como que se genero el PDF
            o.Generar_PDF_Factura_Electronica__c = false;
            o.Nombre_archivo__c = o.Name;
            mapOpportunitiesByName.put(o.Id, o.Name);
        }
        
        List<Attachment> attachments = new List<Attachment>();
        
        for(String recordId : recordsId){
        
            PageReference pdfPage = new PageReference('/apex/printSalesElectronicInvoice');
            pdfPage.getParameters().put('id',recordId);
            Attachment pdf = new Attachment();
            pdf.Name = mapOpportunitiesByName.get(recordId) + '.pdf';
            pdf.ParentId = recordId;
            if(!Test.IsRunningTest() ){            
                pdf.Body = pdfPage.getContent();
            } else {
                pdf.Body = Blob.valueOf('test');
            }
            pdf.ContentType  = 'application/pdf';    
            attachments.add(pdf);
        }
        
        if(!attachments.isEmpty()){
            Utils.insertList(attachments);
        }

        if(!opportunities.isEmpty()){
            Utils.updateList(opportunities);
        }


    }

}