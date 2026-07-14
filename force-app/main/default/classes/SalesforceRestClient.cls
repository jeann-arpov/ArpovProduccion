/**
* @author Maximo Martinez
* @date 27/09/2018
* @description Clase que contiene acceso a metodos que obtienen informacion de la API REST de Salesforce
*/
public with sharing class SalesforceRestClient {

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Variable que contiene el token de acceso a salesforce
	*/
	private LoginResult mLoginResult;

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Variable que contiene el timeout que usa la clase
	*/
	public static Integer TIMEOUT = 60000;

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Variable que contiene los posibles metodos HTTP a usar
	*/
	public enum HTTPMETHOD {GET, POST, PUT}

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description URLS de Acceso Principal a los Servicios de la API REST
	*/
	public static final String URL_API_REST = '/services/data/v42.0';

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Contantes que contienen las URLS de Acceso a los Servicios de la API REST
	*/
	public static final String URL_SERVICES_DESCRIBE_LAYOUT_API = '/sobjects/{0}/describe/layouts/{1}';
	public static final String URL_SERVICES_LIST_VIEW_API = '/sobjects/{0}/listviews/{1}/describe';


	/**
	* @author Maximo Martinez
	* @date 27/11/2019
	* @description Metodo Constructor
	*/
	public SalesforceRestClient(){
		mLoginResult = new LoginResult();
		mLoginResult.instance_url = System.Url.getSalesforceBaseURL().toExternalForm();
		mLoginResult.access_token = (Test.isRunningTest()) ? UserInfo.getUserId() : Helper.getSessionIdFromVFPage(Page.getSessionIdVF);
	}

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Metodo Constructor
	*/
	public SalesforceRestClient(String instanceUrl, String accessToken){
		mLoginResult = new LoginResult();
		mLoginResult.instance_url = instanceUrl;
		mLoginResult.access_token = accessToken;
	}

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Metodo que crea una HttpRequest
	*/
	public static HttpRequest buildRequest(Map<String,String> headers, String url, HTTPMETHOD method, String body){

		System.debug(LoggingLevel.WARN,url);
		System.debug(LoggingLevel.WARN,headers);

		HttpRequest request = new HttpRequest();
		request.setTimeout(TIMEOUT); 
		if (headers != null) {
		    for(String hkey : headers.keySet()){
		    	request.setHeader(hkey, headers.get(hkey)); 
			}   
		}
		request.setEndpoint(url);
		request.setMethod(method.name());
		if (String.isNotEmpty(body)) {
			request.setBody(body);
		}
		return request;
	}

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Metodo que crea una HttpRequest
	*/
	public HttpRequest buildRequest(Map<String,String> headers, String url, HTTPMETHOD method){
		return buildRequest(headers,url,method,null);
	}

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Metodo que hace una Request HTTP
	*/
	private static String sendRequest(HttpRequest req){

		Http http = new Http();
		String sJson;  
        HttpResponse res;      
                        	
    	//Obtiene respuesta
    	res = http.send(req);        	   
    	sJson = res.getBody();

    	System.debug(LoggingLevel.WARN,sJson);

    	if(res.getStatusCode() != 200){
    		throw new SalesforceRestClientException(res.getBody());
    	}
        
        return sJson;

	}

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Obtiene el describe de un layout a partir del objeto y el rt
	*/
	public SalesforceModel.LayoutDescribeResult getDescribeLayout(String sobjectName, String recordTypeId){
		return (SalesforceModel.LayoutDescribeResult) JSON.deserialize(JSON.serialize(getDescribeLayoutByRecordType(sobjectName,recordTypeId)),SalesforceModel.LayoutDescribeResult.class);
	}

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Obtiene el describe de un layout a partir del objeto 
	*/
	public SalesforceModel.LayoutDescribeResult getDescribeLayout(String sobjectName){

		// Obtenemos el RecordType Principal
		Schema.RecordTypeInfo rtInfo = Helper.getMasterRecordType(sobjectName);

		return (SalesforceModel.LayoutDescribeResult) JSON.deserialize(JSON.serialize(getDescribeLayoutByRecordType(sobjectName,rtInfo.getRecordTypeId())),SalesforceModel.LayoutDescribeResult.class);
	
	}


	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Obtiene una Picklist dependiente del recordtype usando la API de UI
	*/
	public Map<String, Object> getDescribeLayoutByRecordType(String sobjectName, String recordTypeId){

		recordTypeId = ((String.isNotEmpty(recordTypeId))?recordTypeId:'');

		String endpoint = this.mLoginResult.instance_url+URL_API_REST+String.format(URL_SERVICES_DESCRIBE_LAYOUT_API,new List<String>{sobjectName,recordTypeId});

        return (Map<String, Object>) JSON.deserializeUntyped(
        	sendRequest(
        		buildRequest(
        			new Map<String,String>{
        				'Accept' => 'application/json; charset=utf-8',
        				'Content-Type' => 'application/json',
        				'Authorization' => 'OAuth ' + this.mLoginResult.access_token
        			}, 
        			endpoint, 
        			HTTPMETHOD.GET)
        		)
        	);

	}

	/**
	* @author Maximo Martinez
	* @date 10/05/2019
	* @description Obtiene el descriptor de una list view
	*/
	public ListViewDescribe getDescribeListViewById(String sobjectName, String listViewId){
		String endpoint = this.mLoginResult.instance_url+URL_API_REST+String.format(URL_SERVICES_LIST_VIEW_API,new List<String>{sobjectName,listViewId});

        return (ListViewDescribe) JSON.deserialize(
			sendRequest(
				buildRequest(
					new Map<String,String>{
						'Accept' => 'application/json; charset=utf-8',
						'Content-Type' => 'application/json',
						'Authorization' => 'OAuth ' + this.mLoginResult.access_token
					}, 
					endpoint, 
					HTTPMETHOD.GET)
			), 
			ListViewDescribe.class
		);

	} 

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Clase auxiliar que representa un resultado de Login
	*/
	public class LoginResult{
		
		public String id {get; set;}
		public String issued_at {get; set;}
		public String refresh_token {get; set;}
		public String instance_url {get; set;}
		public String signature {get; set;}
		public String access_token {get; set;}
	}

	public class ListViewDescribe{
		public List<Column> columns {get; set;}
	}

	public class Column{
		public String fieldNameOrPath {get; set;} 
	}

	/**
	* @author Maximo Martinez
	* @date 27/09/2018
	* @description Custom Exception
	*/
	public class SalesforceRestClientException extends Exception{}

}