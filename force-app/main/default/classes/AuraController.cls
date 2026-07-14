/**
* @author Maximo Martinez
* @date 03/10/2018
* @description Clase utilitaria que contiene elementos que se reutilizan en controladores Apex de Ligthing
*/
public with sharing class  AuraController {


    /**
      * @description Devuelve una lista de SObjects resultado de la query a ejecutar.
      * @param query Query a ejecutar.
      * @return Lista de SObjects resultantes de la query a ejecutar.
      */
    @AuraEnabled
    public static List<SObject> runQuery(String query) {
        System.debug(LoggingLevel.WARN, query);
        return Database.query(query);
    }

    /**
      * @description Retrieves a list of records from the specified object with the requested fields
      * @param objectType The API name of the object we are saving, for example Account or Invoice__c.
      * @param fields A list of strings which are the API field names for the fields we wish to retrieve.
      * @param filters A map of field names to filter values.
      * @return The list of retrieved records.
      */
    @AuraEnabled
    public static List<SObject> query(String objectType, List<String> fields, Map<String, Object> and_filters, Map<String, Object> or_filters, Map<String, Object> in_filters) {
        
        and_filters = and_filters == null ? new Map<String, Object>() : (Map<String, Object>)and_filters;
        or_filters = or_filters == null ? new Map<String, Object>() : (Map<String, Object>)or_filters;
        in_filters = in_filters == null ? new Map<String, Object>() : (Map<String, Object>)in_filters;

        String query = buildFieldQuery(objectType, fields);

        if(and_filters == null && or_filters == null && in_filters == null) {
            return runQuery(query);
        }

        if(!and_filters.isEmpty() || !or_filters.isEmpty() || !in_filters.isEmpty()) {
            query += ' WHERE ';
        }

        if(!and_filters.isEmpty()) {
            for(String key : and_filters.keySet()) {
                query += buildFilterString(key, and_filters.get(key)) + ' AND ';
            }
            query = query.substring(0, query.length() - 4);
        }

        if(!or_filters.isEmpty()) {
            query += and_filters.isEmpty() ? '' : ' AND '; 
            query += '(';
            for(String key : or_filters.keySet()) {
                query += buildFilterString(key, or_filters.get(key)) + ' OR ';
            }
            query = query.substring(0, query.length() - 4) + ')';
        }

        if(!in_filters.isEmpty()) {
            query += and_filters.isEmpty() && or_filters.isEmpty() ? '' : ' AND ';
            for(String key : in_filters.keySet()) {
                query += buildInFilterString(key, (List<String>)JSON.deserialize(JSON.serialize(in_filters.get(key)),List<String>.class)) + ' AND ';
            }
            query = query.substring(0, query.length() - 4);
        }

        return runQuery(query);
    }

    /**
      * @description Retrieves a list of records from the specified object with the requested fields
      * @param objectType The API name of the object we are saving, for example Account or Invoice__c.
      * @param fields A list of strings which are the API field names for the fields we wish to retrieve.
      * @return The list of retrieved records.
      */
    private static String buildFieldQuery(String objectType, List<String> fields) {
        if(fields == null || fields.size() == 0) {
            throw new AuraHandledException(Label.Empty_Field_List_For_Query);
        }

        String query = 'SELECT ';

        Set<String> usedFields = new Set<String>();

        for(String field : fields) {

            if(usedFields.contains(field.toLowerCase())){
                continue;
            }
            
            usedFields.add(field.toLowerCase());
            
            query += field + ',';

        }

        query = query.substring(0, query.length() - 1) + ' FROM ' + objectType;

        return query;
    }

    /**
      * @description This method takes a field name and value and creates a filter string to use.
      * @param fieldName This name of the field we are filtering on.
      * @param value The value we are trying to equate to.
      * @return A correctly formatted string for use in the query string.
      */
    private static String buildFilterString(String fieldName, Object value) {
        
        String symbol = ' = ';

        if(getType(value) == 'Object' && ((Map<Object,Object>)value).containsKey('symbol') && ((Map<Object,Object>)value).containsKey('value')){
            symbol = (String)((Map<Object,Object>)value).get('symbol');
            value = ((Map<Object,Object>)value).get('value');
        }

        String filter = fieldName + symbol;

        if(value instanceof Boolean || value instanceof Blob || value instanceof Integer || value instanceof Long || value instanceof Decimal){
            filter +=  value;
        } else if(value instanceof Id || value instanceof String) {
            filter +=  '\'' + value + '\'';
        } else if (value instanceof Date || value instanceof Datetime) { 
            filter += ((Datetime)value).format('yyyy-MM-dd\'T\'hh:mm:ss\'Z\'');
        }else {
            throw new AuraHandledException(Label.Invalid_Filter_Type);
        }
        
        return filter;
    }

    /**
      * @description This method takes a field name and value and creates a filter string to use.
      * @param fieldName This name of the field we are filtering on.
      * @param values The list value we are trying to find our value in.
      * @return A correctly formatted string for use in the query string.
      */
    private static String buildInFilterString(String fieldName, List<String> values) {
        String filter = fieldName + ' in ' + '(';
            
        for(String value : values) {
            filter += '\'' + value + '\',';
        }

        filter = filter.substring(0, filter.length() - 1) + ')';

        return filter;
    }

	/**
    * @author Maximo Martinez
    * @date 11/09/2018
    * @description Metodo que nos permite leer un FieldSet y obtener sus campos
    * @param fieldSetName Nombre del FieldSet a leer
    * @param objectName Nombre de objeto al que pertenece el field set
    * @return Devuelve una lista de campos que contiene el fieldset
    */
    public static List<Schema.FieldSetMember> getFieldSet(String sObjectName, String fieldSetName){
    
        Map<String, Schema.SObjectType> globalDescribeMap = Schema.getGlobalDescribe(); 
        Schema.SObjectType sObjectTypeObj = globalDescribeMap.get(sObjectName);
        Schema.DescribeSObjectResult describeSObjectResultObj = sObjectTypeObj.getDescribe();

        Schema.FieldSet fieldSetObj = describeSObjectResultObj.FieldSets.getMap().get(fieldSetName);

        return fieldSetObj.getFields(); 
    
    }

    /**
    * @author Maximo Martinez
    * @date 11/09/2018
    * @description Metodo que nos permite leer un FieldSet y obtener sus campos
    * @param fieldSetName Nombre del FieldSet a leer
    * @param objectName Nombre de objeto al que pertenece el field set
    * @return Devuelve una lista de campos que contiene el fieldset
    */
    @AuraEnabled
    public static String getColumns(String objectApiName, String fieldSet){
    
        List<Schema.DescribeFieldResult> result = new List<Schema.DescribeFieldResult>();
    
        for(Schema.FieldSetMember fsm : getFieldSet(objectApiName,fieldSet)){
            result.add(new Parser(fsm,Schema.getGlobalDescribe().get(objectApiName).getDescribe().getSObjectType()).getDescribe());
        }

        return JSON.serialize(result);
    
    }

    /**
    * @author Maximo Martinez
    * @date 12/09/2018
    * @description Devuelve el nombre del icono del objeto para usar ele el componente lightning
    * @param sObjectName Nombre API del SObject a obtener el icono
    * @return el nombre del icono del objeto 
    */
    @AuraEnabled
    public static String getIconName(String sObjectName){
        String u;
        List<Schema.DescribeTabSetResult> tabSetDesc = Schema.describeTabs();
        List<Schema.DescribeTabResult> tabDesc = new List<Schema.DescribeTabResult>();
        List<Schema.DescribeIconResult> iconDesc = new List<Schema.DescribeIconResult>();

        for(Schema.DescribeTabSetResult tsr : tabSetDesc) { tabDesc.addAll(tsr.getTabs()); }

        for(Schema.DescribeTabResult tr : tabDesc) {
            if( sObjectName == tr.getSobjectName() ) {
                if( tr.isCustom() == true ) {
                    iconDesc.addAll(tr.getIcons());
                } else {
                    u = 'standard:' + sObjectName.toLowerCase();
                }
            }
        }
        for (Schema.DescribeIconResult ir : iconDesc) {
            if (ir.getContentType() == 'image/svg+xml'){
                u = 'custom:' + ir.getUrl().substringBetween('custom/','.svg').substringBefore('_');
                break;
            }
        }
        return u;
    }

    /**
    * @author Maximo Martinez
    * @date 27/09/2018
    * @description Workaround para obtener un Session Id valido para hacer una callout a una API de Salesforce desde Lightning
    * @return Session Id valido para hacer callback en Lightning
    */
    public static String fetchUserSessionId(){
        PageReference reportPage = Page.getSessionIdVF;
        String vfContent = (Test.isRunningTest())?'Start_Of_Session_IdjsqjdoqsqEnd_Of_Session_Id':reportPage.getContent().toString();
        return vfContent.substring((vfContent.indexOf('Start_Of_Session_Id') + 'Start_Of_Session_Id'.length()), vfContent.indexOf('End_Of_Session_Id'));
    }

    /**
    * @author Maximo Martinez
    * @date 12/09/2018
    * @description Devuelve el nombre del icono del objeto para usar ele el componente lightning
    * @param sObjectName Nombre API del SObject a obtener el icono
    * @return el nombre del icono del objeto 
    */
    @AuraEnabled
    public static String getDescribeFieldResult(String objectApiName, String fieldName){

        return JSON.serialize(new Parser(fieldName,Schema.getGlobalDescribe().get(objectApiName).getDescribe().getSObjectType()).getDescribe());

    }

    /**
    * @author Maximo Martinez
    * @date 01/10/2018
    * @description Devuelve informacion sobre el lookup a mostrar en el form
    * @return JSON con el describe result
    */
    @AuraEnabled
    public static Map<String,String> getLookupInformation(Id recordId){

        Map<String,String> result = new Map<String,String>{'name'=>null,'label'=>null};

        Schema.SObjectType sobType = Utils.getObjectTypeById(recordId);

        String sobjName =  sobType.getDescribe().getName();

        String nameField = [SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = :sobjName AND IsNameField = TRUE].QualifiedApiName;

        List<SObject> sobjs = Database.query('SELECT '+nameField+' FROM '+sobjName+' WHERE Id = :recordId');

        if(!sobjs.isEmpty()){
            result.put('value',(String)sobjs[0].get(nameField));
            result.put('label', sobType.getDescribe().getLabel());
        }

        return result;

    } 



    /**
    * @author Maximo Martinez
    * @date 22/11/2018
    * @description Devuelve el nombre del icono del objeto para usar ele el componente lightning
    * @param sObjectName Nombre API del SObject a obtener el icono
    * @return el nombre del icono del objeto 
    */
    @AuraEnabled
    public static DescribeSObjectResult getDescribeSObjectResult(String sObjectName){

        List<Schema.DescribeSObjectResult> describeSobjectsResults = Schema.describeSObjects(new List<String>{sObjectName});
        
        if(describeSobjectsResults.isEmpty()){
            return null;
        }

        return new DescribeSObjectResult(describeSobjectsResults[0]);

    }

    private static string getType(Object o) {
        if(o==null) return '';              // we can't say much about null with our current techniques
        if(o instanceof SObject)            return ((SObject)o).getSObjectType().getDescribe().getName()+''; 
        if(o instanceof Boolean)            return 'Boolean';
        if(o instanceof Id)                 return 'Id';
        if(o instanceof String)             return 'String';
        if(o instanceof Blob)               return 'Blob';
        if(o instanceof Date)               return 'Date';
        if(o instanceof Datetime)           return 'Datetime';
        if(o instanceof Time)               return 'Time';
        if(o instanceof String)             return 'String';
        if(o instanceof Integer)            return 'Integer';
        if(o instanceof Long)               return 'Long';
        if(o instanceof Decimal)            return 'Decimal';  // we can't distinguish between decimal and double
        if(o instanceof Double)             return 'Double';   // we can't distinguish between decimal and double
        if(o instanceof List<object>)       return 'List';
        return 'Object';                    // actually we can't detect maps and sets and maps
    }

    /**
    * @author Maximo Martinez
    * @date 22/11/2018
    * @description Clase utilitaria para obtener datos de campos 
    */
    public class Parser{

        public List<String> path;
        public Schema.SObjectType type;

        public Parser(Schema.FieldSetMember member, Schema.SObjectType type){
            this.path = member.getFieldPath().split('\\.');
            this.type = type;
        }

        public Parser(String fieldPath,Schema.SObjectType type){
            this.path = fieldPath.split('\\.');
            this.type = type;
        }

        public Schema.DescribeFieldResult getDescribe(){
            // could possibly make this recursive
            while (path.size() > 1){
                traverse();
            }
            return describe(path[0]);
        }

        public void traverse(){
            if (path.size() == 1){
                return;
            }
            String lookupName = getLookupName(path.remove(0));
            Schema.DescribeFieldResult describe = describe(lookupName);
            this.type = describe.getReferenceTo()[0];
            // this would get a lot more hairy if we want to deal with polymorphic lookups properly
        }

        public Schema.DescribeFieldResult describe(String field){
            return type.getDescribe().fields.getMap()
                .get(field).getDescribe();
        }

        public String getLookupName(String crossObjectReference){
            // would need to think about this more if there are managed packages
            return crossObjectReference.endsWith('__r') ?
                crossObjectReference.replace('__r', '__c') :
                crossObjectReference + 'Id';
        }
    }

    /**
    * @author Maximo Martinez
    * @date 13/09/2018
    * @description Clase que representa la respuesta a enviar 
    */
    public class DataTableResponse {
     
        @AuraEnabled
        public List<DataTableModel.Column> lstDataTableColumns {get; set;}
     
        @AuraEnabled
        public List<Documento_Gestionado__c> lstDataTableData {get; set;}   

        @AuraEnabled
        public Set<Id> selectedRows {get; set;}             
        
        public DataTableResponse(){
            lstDataTableColumns = new List<DataTableModel.Column>();
            lstDataTableData = new List<sObject>();
            selectedRows = new Set<Id>();
        }    

    }


    /**
    * @author Maximo Martinez
    * @date 08/11/2018
    * @description Clase que representa un DescribeSObjectResult 
    */
    public class DescribeSObjectResult{

        @AuraEnabled
        public String label {get;set;}
        
        @AuraEnabled
        public String name {get;set;} 

        @AuraEnabled
        public String labelPlural {get;set;}

        public DescribeSObjectResult(Schema.DescribeSObjectResult dor){
            this.label = dor.getLabel();
            this.name = dor.getName();
            this.labelPlural = dor.getLabelPlural();
        }

    }
    

}