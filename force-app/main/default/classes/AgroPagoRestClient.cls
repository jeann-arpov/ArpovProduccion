/**
* @author Maximo Martinez
* @date 15/11/2019
* @description Clase que contiene acceso a metodos que obtienen informacion de la API REST de AgroPago
*/
public with sharing class AgroPagoRestClient {
    
    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Variable que contiene el token type que usa la clase
    */
    public static String TOKENTYPE = AgroPago__c.getOrgDefaults().Token_Type__c;

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Variable que contiene el apikey (private token) que usa la clase
    */
    public static String APIKEY = AgroPago__c.getOrgDefaults().ApiKey__c;

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Variable que contiene el apikey (public token) que usa la clase
	*/
    public static String PUBLIC_APIKEY = AgroPago__c.getOrgDefaults().Token__c;


    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Variable que contiene el timeout que usa la clase
	*/
    public static Integer TIMEOUT = Integer.valueOf(AgroPago__c.getOrgDefaults().Timeout__c);

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Datos de la Named Credential usada para indicar datos de conexion
	*/
    public static final String NAMED_CREDENTIAL_AGROPAGO = 'AgroPago';

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description URl para obtener los payments methods
	*/
    public static final String URL_PATH_PAYMENT_METHODS = '/api/v2/paymentMethods?customerId=13';

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description URl para obtener los payments methods
	*/
    public static final String URL_PATH_PAYMENTS_AGRO = '/api/v2/payments_agro';

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description URl para obtener el token
	*/
    public static final String URL_PATH_TOKENS = '/api/v2/tokens';

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Header API KEY
	*/
    public static final String HTTP_HEADER_APIKEY = 'x-api-key';

    public static RestClient getJsonClient() {
        return new RestClient()
            .setTimeout(TIMEOUT > 0 ? TIMEOUT : 30000)
            .setHeader(RestClient.HTTP_HEADER_ACCEPTS,RestClient.CONTENT_TYPE_JSON)
            .setHeader(RestClient.HTTP_HEADER_CONTENT_TYPE,RestClient.CONTENT_TYPE_JSON);          
    }

    public static RestClient getClient() {
        return getJsonClient()
            .setHeader(HTTP_HEADER_APIKEY, APIKEY);
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description obtener los payments methods
	*/
    public static List<PaymentMethod> getPaymentMethods(){
        
        return (List<PaymentMethod>)JSON.deserialize(
            getClient()
            .setNamedCredential(NAMED_CREDENTIAL_AGROPAGO+URL_PATH_PAYMENT_METHODS)
            .get(), 
            List<PaymentMethod>.class
        );

    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description obtener los payments methods
    */
    public static TokenResponse getToken(TokenRequest token){

        String jsonString = JSON.serialize(token);

        jsonString = jsonString.replace('number_x', 'number');

        return (TokenResponse)JSON.deserialize(
            getJsonClient()
            .setHeader(HTTP_HEADER_APIKEY, AgroPagoRestClient.PUBLIC_APIKEY)
            .setNamedCredential(NAMED_CREDENTIAL_AGROPAGO+URL_PATH_TOKENS)
            .setBody(jsonString)
            .post(),
            TokenResponse.class
        );

    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description obtener los payments methods
    */
    public static PaymentsAgroResponse paymentsAgro(PaymentsAgroRequest request){

        String jsonString = JSON.serialize(request);

        jsonString = jsonString.replace('date_x', 'date');

        String response = getClient()
        .setNamedCredential(NAMED_CREDENTIAL_AGROPAGO+URL_PATH_PAYMENTS_AGRO)
        .setBody(jsonString)
        .post();

        response = response.replace('date', 'date_x');
        response = response.replace('currency','currency_x');

        return (PaymentsAgroResponse)JSON.deserialize(response,PaymentsAgroResponse.class);
    }
    
    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description obtener los payments methods
    */
    public class TokenResponse{

        @AuraEnabled
        public String id {get;set;}
        
        @AuraEnabled
        public String status {get;set;}

        @AuraEnabled
        public Integer card_number_length {get;set;}

        @AuraEnabled
        public String date_created {get; set;}

        @AuraEnabled
        public String bin {get;set;}
        
        @AuraEnabled
        public String last_four_digits {get;set;}
        
        @AuraEnabled
        public Integer security_code_length {get; set;}
        
        @AuraEnabled
        public Integer expiration_month {get;set;}
        
        @AuraEnabled
        public Integer expiration_year {get;set;}
        
        @AuraEnabled
        public String date_due {get;set;}
        
        @AuraEnabled
        public CardHolder cardholder {get;set;}
    
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Payment Methods
	*/
    public class PaymentMethod{
        @AuraEnabled
        public Integer id {get; set;}

        @AuraEnabled
        public String name {get; set;}

        @AuraEnabled
        public List<PCMEstablishment> pmcEstablishments {get;set;}
    }

    public class PCMEstablishment {
        @AuraEnabled
        public Integer id {get; set;}

        @AuraEnabled
        public String establishReferences {get; set;}
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Token Request
    */
    public class TokenRequest{

        @AuraEnabled
        public String card_number {get; set;}

        @AuraEnabled
        public String card_expiration_month {get; set;}
        
        @AuraEnabled
        public String card_expiration_year {get; set;} 
        
        @AuraEnabled
        public String security_code {get; set;} 
        
        @AuraEnabled
        public String card_holder_name {get; set;}
        
        @AuraEnabled
        public Identification card_holder_identification {get;set;}

        @AuraEnabled
        public Integer payment_method_id {get;set;}
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Identification
    */
    public class Identification{
    
        @AuraEnabled
        public String type {get; set;}
    
        @AuraEnabled
        public String number_x {get; set;}
    
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Identification
    */
    public class CardHolder{

        @AuraEnabled
        public identification identification {get;set;}

        @AuraEnabled
        public String name {get;set;}

    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Payment Agro Request
    */
    public class PaymentsAgroRequest{
        
        @AuraEnabled
        public String payment_detail {get;set;} 
        
        @AuraEnabled
        public String operation_id {get;set;}
        
        @AuraEnabled
        public String token {get;set;} 
        
        @AuraEnabled
        public Integer pmc_establishment_id {get;set;}
        
        @AuraEnabled
        public Decimal amount {get;set;} 
        
        @AuraEnabled
        public String token_agro {get;set;} 
        
        @AuraEnabled
        public String token_type = TOKENTYPE;
        
        @AuraEnabled
        public Integer days_agreement {get;set;}
        
        @AuraEnabled
        public String email {get;set;} 
        
        @AuraEnabled
        public List<Installment> installments {get;set;}

    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Payment Agro Request
    */
    public class Installment{
        public Integer id {get;set;}
        public Date date_x {get;set;}
        public Decimal amount {get; set;}
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Payment Agro Response
    */
    public class PaymentsAgroResponse{

        @AuraEnabled
        public Integer transaction_id {get;set;}
        
        @AuraEnabled
        public String status {get;set;}
        
        @AuraEnabled
        public Integer payment_id {get;set;}
        
        @AuraEnabled
        public String operation_id {get;set;}
        
        @AuraEnabled
        public Integer payment_method_id {get;set;}
        
        @AuraEnabled
        public Decimal amount {get;set;}
        
        @AuraEnabled
        public String currency_x {get;set;}
       
        @AuraEnabled
        public String card_brand {get;set;}
        
        @AuraEnabled
        public String ticket {get;set;}
        
        @AuraEnabled
        public String authorization_code {get;set;}
        
        @AuraEnabled
        public String bin {get;set;}
        
        @AuraEnabled
        public Integer installments {get;set;}
        
        @AuraEnabled
        public String date_x {get;set;}

        @AuraEnabled
        public String email {get;set;}

        @AuraEnabled
        public String status_error {get;set;}
        
        @AuraEnabled
        public Integer reason_error_id {get;set;}

        @AuraEnabled
        public String reason_error_description {get;set;}
    
    }

}