public class SGL_RedirectController {
    public String jwtToken { get; set; }
    public String targetUrl { get; set; }

    public String userId { get; set; }
    public String contactId { get; set; }
    public String licenseId { get; set; }

    public SGL_RedirectController() {
        // obtener los parámetros desde la URL
        userId = ApexPages.currentPage().getParameters().get('userId');
        contactId = ApexPages.currentPage().getParameters().get('contactId');
        licenseId = ApexPages.currentPage().getParameters().get('licenseId');
        targetUrl = getUrl();
   
    }

    @AuraEnabled (cacheable=true)
    public static String getUrl(){
        Organization org = [SELECT IsSandbox FROM Organization];
        String entorno;
        if (org.IsSandbox) {
            entorno = 'Sandbox';
        } else {
            entorno = 'Prod';
        }

        Parametro_Portal_Licencias__mdt licParam = Parametro_Portal_Licencias__mdt.getInstance(entorno);

        return licParam.url__c;
    }


    public void init() {
        jwtToken = singleLicenseJWTSigner(userId, contactId, licenseId);
    }

    private static String createHMACSignature(String data, String secretKey) {
        Blob key = Blob.valueOf(secretKey);
        Blob dataBlob = Blob.valueOf(data);
        
        Blob signedBlob = Crypto.generateMac('HMACSHA256', dataBlob, key);
        
        return base64URLencode(signedBlob);
    }
    
    public static String base64URLencode(Blob input){ 
        String output = encodingUtil.base64Encode(input);
        output = output.replace('+', '-');
        output = output.replace('/', '_');
        while ( output.endsWith('=')){
            output = output.subString(0,output.length()-1);
        }
        return output;
    }


    @AuraEnabled
    public static String singleLicenseJWTSigner(String userId, String contactId, String licenseId) {
        User usr = [SELECT Id, Email, ContactId, CUIT__c, Razon_Social__c from User WHERE Id =: userId];
      
        Contact ctc = [SELECT Id, AccountId, FirstName, LastName from Contact WHERE Id =:contactId];
        Account acc = [SELECT Type FROM Account WHERE Id =: ctc.AccountId];

        Licencia__c license = [SELECT Id, Name FROM Licencia__c WHERE Id = :licenseId];
        Map<String, Object> header = new Map<String, Object>();
        header.put('typ', 'JWT');
        header.put('alg', 'HS256');
       
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('sub', 'user@example.com');
        payload.put('email', usr.Email);
       
        payload.put('cuit', usr.CUIT__c);
        payload.put('razonSocial', usr.Razon_Social__c);
        payload.put('accType', acc.Type);
        payload.put('firstName', ctc.FirstName);
        payload.put('lastName', ctc.LastName);
        payload.put('LicenseCode', license.Name);
       
        payload.put('admin', true);
        payload.put('roles', new List<String>{'Admin', 'Editor'});
        payload.put('permissions', new List<String>{'read', 'write', 'delete'});
       
        payload.put('iat', DateTime.now().getTime() / 1000);
        payload.put('exp', DateTime.now().addHours(1).getTime() / 1000);
       
        String encodedHeader = base64URLencode(Blob.valueOf(JSON.serialize(header)));
        String encodedPayload = base64URLencode(Blob.valueOf(JSON.serialize(payload)));
        
        String unsignedJWT = encodedHeader + '.' + encodedPayload;
       
        String signature = createHMACSignature(unsignedJWT, '518C1F10-6106-4E09-9B4A-7FBF245308F9');
       
        String signedJWT = unsignedJWT + '.' + signature;
 
        return signedJWT;
    }
}