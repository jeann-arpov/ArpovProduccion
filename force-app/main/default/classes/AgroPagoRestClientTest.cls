@IsTest
public with sharing class AgroPagoRestClientTest {
    
    @TestSetup
    static void makeData(){
        
        AgroPago__c aPago = AgroPago__c.getOrgDefaults();
        aPago.Token_Type__c = 'test';
        aPago.ApiKey__c = 'test';
        aPago.Timeout__c = 6000;
        aPago.Token_Type__c = 'T';
        insert aPago;

    }

    @IsTest
    static void testGetPaymentMethods(){

        List<AgroPagoRestClient.PaymentMethod> payments = new List<AgroPagoRestClient.PaymentMethod>();

        AgroPagoRestClient.PaymentMethod payment = new AgroPagoRestClient.PaymentMethod();
        payment.name = '';
        payment.id = 1;
        
        Map<String, String> headers = new Map<String,String>{'Content-Type'=>'application/json'};

        Test.setMock(HttpCalloutMock.class, new TestCalloutMock(headers,200,JSON.serialize(payments)));

        Test.startTest();
        AgroPagoRestClient.getPaymentMethods();
        Test.stopTest();
    
    }

    @IsTest
    static void testGetToken(){
        AgroPagoRestClient.PUBLIC_APIKEY = '123';

        AgroPagoRestClient.TokenResponse token = new AgroPagoRestClient.TokenResponse();
        token.bin = '';
        token.card_number_length = 1;
        token.cardholder = new AgroPagoRestClient.CardHolder();
        token.cardholder.name = '';
        token.date_created = '';
        token.date_due = '';
        token.expiration_month = 1;
        token.expiration_year = 1;
        token.id = '';
        token.last_four_digits = '';
        token.security_code_length = 1;
        token.status = '';

        Map<String, String> headers = new Map<String,String>{'Content-Type'=>'application/json'};

        Test.setMock(HttpCalloutMock.class, new TestCalloutMock(headers,200,JSON.serialize(token)));

        AgroPagoRestClient.TokenRequest tRequest = new AgroPagoRestClient.TokenRequest();
        tRequest.card_number = '';
        tRequest.card_expiration_month = '';
        tRequest.card_expiration_year = '';
        tRequest.security_code = '';
        tRequest.card_holder_name = '';
        tRequest.card_holder_identification = null;

        Test.startTest();
        AgroPagoRestClient.getToken(tRequest);
        Test.stopTest();
    
    }

    @IsTest
    static void testPaymentsAgro(){

        AgroPagoRestClient.PaymentsAgroResponse pAgroResponse = new AgroPagoRestClient.PaymentsAgroResponse();
        pAgroResponse.bin = '';
        pAgroResponse.card_brand = '';
        pAgroResponse.currency_x = '';
        pAgroResponse.date_x = '';
        pAgroResponse.email = '';
        pAgroResponse.installments = 1;
        pAgroResponse.operation_id = '';
        pAgroResponse.payment_id = 1;
        pAgroResponse.payment_method_id = 1;
        pAgroResponse.reason_error_description = '';
        pAgroResponse.reason_error_id = 1;
        pAgroResponse.status = '';
        pAgroResponse.status_error = '';
        pAgroResponse.ticket = '';
        pAgroResponse.transaction_id = 1;

        AgroPagoRestClient.PaymentsAgroRequest pAgroRequest = new AgroPagoRestClient.PaymentsAgroRequest();
        pAgroRequest.payment_detail = '';
        pAgroRequest.operation_id = '';
        pAgroRequest.token = '';
        pAgroRequest.amount = 10;
        pAgroRequest.token_agro = '';
        pAgroRequest.days_agreement = 10;
        pAgroRequest.email = '';
        pAgroRequest.installments = new List<AgroPagoRestClient.Installment>();
        pAgroRequest.installments.add(new AgroPagoRestClient.Installment());
        pAgroRequest.installments[0].id = 1;
        pAgroRequest.installments[0].amount = 10;
        pAgroRequest.installments[0].date_x = System.today();

        Map<String, String> headers = new Map<String,String>{'Content-Type'=>'application/json'};

        Test.setMock(HttpCalloutMock.class, new TestCalloutMock(headers,200,JSON.serialize(pAgroResponse)));

        Test.startTest();
        AgroPagoRestClient.paymentsAgro(pAgroRequest);
        Test.stopTest();
    
    }

    public class TestCalloutMock implements HttpCalloutMock {

		public Map<String,String> headers;
		public Integer statusCode;
		public String body;	

		public TestCalloutMock(Map<String,String> headers, Integer statusCode, String body){
			this.headers = headers;
			this.statusCode = statusCode;
			this.body = body;
		}

        public HTTPResponse respond(HTTPRequest req) {
        
            HttpResponse res = new HttpResponse();
            
            for(String key : headers.keySet()){
            	res.setHeader(key,headers.get(key));
            }

            if(String.isNotEmpty(body)){
            	res.setBody(body);
        	}
        
            res.setStatusCode(statusCode);
        
            return res;

        }

    }

}