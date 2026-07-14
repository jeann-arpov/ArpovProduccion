@IsTest
public with sharing class RestClientTest {

    @isTest
    public static void testPostFormEncoded(){

        Map<String, String> headers = new Map<String,String>{'Content-Type'=>'application/json'};

		Test.setMock(HttpCalloutMock.class, new TestCalloutMock(headers,200,'{"id":"12345678","name":"test"}'));

        String response = new RestClient()
        .setTimeout(120000)
        .setBody('TEST',new Map<String,Object>{'test'=>'test'})
        .setBody('TEST2','Test String')
        .setHeader(RestClient.HTTP_HEADER_CONTENT_LENGTH, '1200')
        .setHeader(RestClient.HTTP_HEADER_AUTHORIZATION, 'TEST')
        .setHeader(RestClient.HTTP_HEADER_ACCEPTS, RestClient.CONTENT_TYPE_WWW_FORM_ENCODED)
        .setHeader(RestClient.HTTP_HEADER_CONTENT_TYPE, RestClient.CONTENT_TYPE_JSON)
        .setEndpoint('https://test.com')
        .post();

        System.assertEquals(response, '{"id":"12345678","name":"test"}');

    }

    @isTest
    public static void testPost(){

        Map<String, String> headers = new Map<String,String>{'Content-Type'=>'application/json'};

		Test.setMock(HttpCalloutMock.class, new TestCalloutMock(headers,200,'{"id":"12345678","name":"test"}'));

        String response = new RestClient()
        .setTimeout(120000)
        .setBody('{"test":"test"}')
        .setHeader(RestClient.HTTP_HEADER_CONTENT_LENGTH, '1200')
        .setHeader(RestClient.HTTP_HEADER_AUTHORIZATION, 'TEST')
        .setHeader(RestClient.HTTP_HEADER_ACCEPTS, RestClient.CONTENT_TYPE_JSON)
        .setHeader(RestClient.HTTP_HEADER_CONTENT_TYPE, RestClient.CONTENT_TYPE_JSON)
        .setEndpoint('https://test.com')
        .post();

        System.assertEquals(response, '{"id":"12345678","name":"test"}');

    }

    @isTest
    public static void testGet(){

        Map<String, String> headers = new Map<String,String>{'Content-Type'=>'application/json'};

		Test.setMock(HttpCalloutMock.class, new TestCalloutMock(headers,200,'{"id":"12345678","name":"test"}'));

        String response = new RestClient()
        .setTimeout(120000)
        .setHeader(RestClient.HTTP_HEADER_CONTENT_LENGTH, '1200')
        .setHeader(RestClient.HTTP_HEADER_AUTHORIZATION, 'TEST')
        .setHeader(RestClient.HTTP_HEADER_ACCEPTS, RestClient.CONTENT_TYPE_JSON)
        .setHeader(RestClient.HTTP_HEADER_CONTENT_TYPE, RestClient.CONTENT_TYPE_JSON)
        .setNamedCredential('TEST')
        .get();

        System.assertEquals(response, '{"id":"12345678","name":"test"}');

    }

    @IsTest
    static void testBuildHttpQuery(){
        RestClient.buildHttpQuery(new Map<String, String>{'Test'=>'Test'});
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