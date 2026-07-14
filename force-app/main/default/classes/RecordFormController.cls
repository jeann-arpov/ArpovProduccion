/**
* @author Maximo Martinez
* @date 27/09/2018
* @description Controlador del Componente Lightning recordForm
*/
public class RecordFormController {

    /**
    * @author Maximo Martinez
    * @date 27/09/2018
    * @description Devuelve el resultado de hacer un callout a la API de Salesforce de Describe Layout by RecordType
    * @return JSON con el describe result
    */
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getDescribeLayoutByRecordType(String sobjectName, String recordTypeId){

        SalesforceRestClient sf = new SalesforceRestClient(System.Url.getSalesforceBaseURL().toExternalForm(),AuraController.fetchUserSessionId());

        return sf.getDescribeLayoutByRecordType(sobjectName,recordTypeId);

    } 

}