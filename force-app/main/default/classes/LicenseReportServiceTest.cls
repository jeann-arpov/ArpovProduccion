@isTest
public class LicenseReportServiceTest {
    
    private static final String MOCK_JSON_RESPONSE = '{"reportId":"RPT001","status":"completed","licenses":[{"licenseCode":"LIC001","description":"Test License","status":"active","expiryDate":"2025-12-31"}],"generatedDate":"2025-09-10"}';
    
    private static String getValidUserId() {
        return UserInfo.getUserId();
    }
    
    private static String getValidContactId() {
        return '003' + String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(12, '0') + 'AAA';
    }
    
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'Test Account',
            Type = 'Productor'
        );
        insert testAccount;
        
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test@example.com'
        );
        insert testContact;
        
       /* User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        currentUser.ContactId = testContact.Id;
        currentUser.Email = 'testuser@example.com';
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update currentUser;
        }*/
    }

    private static String getRealContactId() {
        Contact testContact = [SELECT Id FROM Contact WHERE FirstName = 'Test' AND LastName = 'Contact' LIMIT 1];
        return testContact.Id;
    }

    @isTest
    static void successTest() {
        String validUserId = getValidUserId();
        String validContactId = getRealContactId();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, MOCK_JSON_RESPONSE));
        
        Test.startTest();
        LicenseReportService.ServiceResponse response = LicenseReportService.getLicensesReport(validUserId, validContactId);
        Test.stopTest();
        
        System.assert(response != null, 'La respuesta no debe ser null');
        System.assert(response.success, 'La operación debe ser exitosa');
        System.assertEquals('Reporte generado exitosamente', response.message);
        System.assertEquals(200, response.statusCode);
        System.assert(response.data != null, 'Los datos no deben ser null');
    }
    
    @isTest
    static void invalidParameters() {
        String validContactId = getValidContactId();
        LicenseReportService.ServiceResponse response = LicenseReportService.getLicensesReport('', validContactId);

        System.assert(response != null, 'La respuesta no debe ser null');
        System.assert(!response.success, 'La operación debe fallar');
        System.assertEquals('Los parámetros userId y contactId son requeridos', response.message);
        System.assertEquals(null, response.statusCode);
        System.assertEquals(null, response.data);
    }
    
    @isTest
    static void invalidParametersContactIdBlank() {
        String validUserId = getValidUserId();
        
        LicenseReportService.ServiceResponse response = LicenseReportService.getLicensesReport(validUserId, '');
        
        System.assert(response != null, 'La respuesta no debe ser null');
        System.assert(!response.success, 'La operación debe fallar');
        System.assertEquals('Los parámetros userId y contactId son requeridos', response.message);
        System.assertEquals(null, response.statusCode);
        System.assertEquals(null, response.data);
    }
    
    @isTest
    static void nullParameters() {
        LicenseReportService.ServiceResponse response = LicenseReportService.getLicensesReport(null, null);
        
        System.assert(response != null, 'La respuesta no debe ser null');
        System.assert(!response.success, 'La operación debe fallar');
        System.assertEquals('Los parámetros userId y contactId son requeridos', response.message);
    }
    
    @isTest
    static void httpStatus401() {
        String validUserId = getValidUserId();
        String validContactId = getRealContactId();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(401, '{"error":"Unauthorized"}'));
        
        Test.startTest();
        LicenseReportService.ServiceResponse response = LicenseReportService.getLicensesReport(validUserId, validContactId);
        Test.stopTest();
        
        System.assert(response != null, 'La respuesta no debe ser null');
        System.assert(!response.success, 'La operación debe fallar');
        System.assertEquals('Token de autenticación inválido o expirado.', response.message);
        System.assertEquals(401, response.statusCode);
    }
    
    @isTest
    static void httpStatus500() {
        String validUserId = getValidUserId();
        String validContactId = getRealContactId();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, '{"error":"Internal Server Error"}'));
        
        Test.startTest();
        LicenseReportService.ServiceResponse response = LicenseReportService.getLicensesReport(validUserId, validContactId);
        Test.stopTest();
        
        System.assert(response != null, 'La respuesta no debe ser null');
        System.assert(!response.success, 'La operación debe fallar');
        System.assertEquals('Error interno del servidor externo.', response.message);
        System.assertEquals(500, response.statusCode);
    }
    
    @isTest
    static void httpStatusUnexpected() {
        String validUserId = getValidUserId();
        String validContactId = getRealContactId();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(418, '{"error":"Codigo de error"}'));
        
        Test.startTest();
        LicenseReportService.ServiceResponse response = LicenseReportService.getLicensesReport(validUserId, validContactId);
        Test.stopTest();
        
        System.assert(response != null, 'La respuesta no debe ser null');
        System.assert(!response.success, 'La operación debe fallar');
        System.assert(response.message.contains('Error inesperado del servicio (Código: 418)'), 'El mensaje debe incluir el código de estado');
        System.assertEquals(418, response.statusCode);
    }
    
    @isTest
    static void calloutException() {
        String validUserId = getValidUserId();
        String validContactId = getRealContactId();
        Test.setMock(HttpCalloutMock.class, new MockHttpCalloutExceptionGenerator());
        Test.startTest();
        LicenseReportService.ServiceResponse response = LicenseReportService.getLicensesReport(validUserId, validContactId);
        Test.stopTest();
        
        System.assert(response != null, 'La respuesta no debe ser null');
        System.assert(!response.success, 'La operación debe fallar');
        System.assert(response.message.contains('Error de conectividad con el servicio externo'), 
                     'El mensaje debe indicar error de conectividad');
    }
    
    @isTest
    static void jsonException() {
        String validUserId = getValidUserId();
        String validContactId = getRealContactId();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, 'Invalid JSON Response'));
        
        Test.startTest();
        LicenseReportService.ServiceResponse response = LicenseReportService.getLicensesReport(validUserId, validContactId);
        Test.stopTest();
        
        System.assert(response != null, 'La respuesta no debe ser null');
        System.assert(response.success, 'La operación debe ser exitosa incluso con JSON inválido');
        System.assertEquals('Reporte generado exitosamente', response.message);
        System.assertEquals('Invalid JSON Response', response.data, 'Debe retornar el string original cuando el JSON es inválido');
        System.assertEquals(200, response.statusCode);
    }
    
    @isTest
    static void serviceResponseConstructor() {
        LicenseReportService.ServiceResponse response = new LicenseReportService.ServiceResponse(
            true, 'Test message', 'Test data', 200
        );
        
        System.assertEquals(true, response.success);
        System.assertEquals('Test message', response.message);
        System.assertEquals('Test data', response.data);
        System.assertEquals(200, response.statusCode);
    }
    
    @isTest
    static void wrapperClass() {
        LicenseReportService.LicenseReportData reportData = new LicenseReportService.LicenseReportData();
        reportData.reportId = 'RPT001';
        reportData.status = 'completed';
        reportData.generatedDate = '2025-09-10';
        reportData.licenses = new List<LicenseReportService.LicenseItem>();
        
        System.assertEquals('RPT001', reportData.reportId);
        System.assertEquals('completed', reportData.status);
        System.assertEquals('2025-09-10', reportData.generatedDate);
        System.assert(reportData.licenses != null);
    }
    
    @isTest
    static void wrapperClassTest() {
        LicenseReportService.LicenseItem license = new LicenseReportService.LicenseItem();
        license.licenseCode = 'LIC001';
        license.description = 'Test License';
        license.status = 'active';
        license.expiryDate = '2025-12-31';
        
        System.assertEquals('LIC001', license.licenseCode);
        System.assertEquals('Test License', license.description);
        System.assertEquals('active', license.status);
        System.assertEquals('2025-12-31', license.expiryDate);
    }
    
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        
        public MockHttpResponseGenerator(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
        
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(this.statusCode);
            response.setBody(this.responseBody);
            return response;
        }
    }
    
    public class MockHttpCalloutExceptionGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            throw new System.CalloutException('Timeout or connection error');
        }
    }
}