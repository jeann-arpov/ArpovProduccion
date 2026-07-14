/**
* @author Maximo Martinez
* @date 15/11/2019
* @description Clase que contiene logica para consumir servicios REST
*/
public with sharing class RestClient {

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Almacena las partes de un body cuando se usa application/x-www-form-urlencoded
	*/
    private Map<String,String> bodyKeys = new Map<String,String>();

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Almacena la HttpRequest a usar
	*/
    private HttpRequest request = new HttpRequest();

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Variables estaticas con los posibles metodos HTTP a usar
	*/
	public static final String REQUEST_METHOD_DELETE = 'DELETE';
	public static final String REQUEST_METHOD_GET = 'GET';
	public static final String REQUEST_METHOD_POST = 'POST';
	public static final String REQUEST_METHOD_PUT = 'PUT';
    public static final String REQUEST_METHOD_PATCH = 'PATCH';

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Nombres de Headers
	*/
    public static final String HTTP_HEADER_AUTHORIZATION = 'Authorization';
	public static final String HTTP_HEADER_CONTENT_DISPOSITION = 'Content-Disposition';
	public static final String HTTP_HEADER_CONTENT_LENGTH = 'Content-Length';
	public static final String HTTP_HEADER_CONTENT_TYPE = 'Content-Type';
	public static final String HTTP_HEADER_ACCEPTS = 'Accepts';

    
    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Datos de la Named Credential usada para indicar datos de conexion
	*/
    public static final String NAMED_CREDENTIALS_URL_PREFIX = 'callout:';

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Separadores
	*/
    public static final String HTTP_REQUEST_ENDPOINT_SEPARATOR = '&';
	public static final String HTTP_REQUEST_PARAMETER_SEPARATOR = '=';
	public static final String HTTP_REQUEST_PARAMETER_PREFIX = '?';
	public static final String HTTP_REQUEST_COOKIE_SEPARATOR = ';';

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Charsets
	*/
    public static final String CHARSET_UTF8 = 'UTF-8';

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Content Types
	*/
	public static final String CONTENT_TYPE_JSON = 'application/json; charset=UTF-8';
    public static final String CONTENT_TYPE_WWW_FORM_ENCODED = 'application/x-www-form-urlencoded';

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Setea la named credential a utilizar
	*/
    public RestClient setNamedCredential(String namedCredential){
        request.setEndpoint(NAMED_CREDENTIALS_URL_PREFIX + namedCredential);
        return this;            
    }

	/**
	* @author Maximo Martinez
	* @date 27/11/2019
	* @description Set endpoint
	*/
    public RestClient setEndpoint(String endpoint){
        request.setEndpoint(endpoint);
        return this;            
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Setea timeout
	*/
    public RestClient setTimeout(Integer timeout){
        request.setTimeout(timeout);
        return this;
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Setea body cuando es un form-urlencoded
	*/
    public RestClient setBody(String key, Object value){
        bodyKeys.put(key,JSON.serialize(value));
        return this;
    }

	/**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Setea body cuando es un form-urlencoded
	*/
    public RestClient setBody(String key, String value){
        bodyKeys.put(key,EncodingUtil.urlEncode(value,CHARSET_UTF8));
        return this;
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Setea header de la request
	*/
    public RestClient setHeader(String key, String value){
		System.debug(LoggingLevel.WARN,key);
		System.debug(LoggingLevel.WARN,value);
        request.setHeader(key,value);
        return this;
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Setea body cuando el content type sera un JSON
	*/
    public RestClient setBody(Object body){
        request.setBody(JSON.serialize(body));
        return this;
	}
	
	/**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Setea body cuando el content type sera un JSON
	*/
	public RestClient setBody(String body){
		request.setBody(body);
		return this;
	}

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Hace una llamada post y devuelve el contenido en un string
	*/
    public String post(){

        // Verificamos el tipo de content type
        if(request.getHeader(HTTP_HEADER_CONTENT_TYPE) == CONTENT_TYPE_WWW_FORM_ENCODED){
			request.setBody(buildHttpQuery(bodyKeys));
        }

        request.setMethod(REQUEST_METHOD_POST);
        
        return sendRequest(request);
    }

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Hace una llamada GET y devuelve un string
	*/
    public String get(){
        request.setMethod(REQUEST_METHOD_GET);
        return sendRequest(request);
    }

	public String doDelete(){
		request.setMethod(REQUEST_METHOD_DELETE);
		return sendRequest(request);
	}

	public String patch(){
		request.setMethod(REQUEST_METHOD_PATCH);
		return sendRequest(request);
	}

	/**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Metodo auxiliar que genera un formulario POST
	*/
	@TestVisible
	private static String buildHttpQuery(Map<String, String> queryParams) {
        
		if(queryParams == null || queryParams.isEmpty()){
			return '';
		}

		List<String> parameters = new List<String>();

		for(String key : queryParams.keySet()){
			parameters.add(key + HTTP_REQUEST_PARAMETER_SEPARATOR + queryParams.get(key));
		}

		return String.join(parameters,HTTP_REQUEST_ENDPOINT_SEPARATOR);

    }

	/**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Metodo que hace una Request HTTP
	*/
	private static String sendRequest(HttpRequest req){

		System.debug(LoggingLevel.WARN, req.getEndpoint());
		System.debug(LoggingLevel.WARN, req.getBody());

		Http http = new Http();
		String sJson;  
        HttpResponse res;      
                        	
    	//Obtiene respuesta
    	res = http.send(req);        	   
    	sJson = res.getBody();

    	System.debug(LoggingLevel.WARN,sJson);

    	if(res.getStatusCode() >= 300 || res.getStatusCode()<200){
    		throw new RestClientException(res.getBody(),res.getStatusCode());
    	}
        
        return sJson;

	}

    /**
	* @author Maximo Martinez
	* @date 15/11/2019
	* @description Custom Exception
	*/
    public class RestClientException extends Exception{

		public Integer statusCode {get;set;}
    
		public RestClientException( String msg, Integer statusCode){
			this.setMessage(msg);
			this.statusCode = statusCode;
		}

	}


}