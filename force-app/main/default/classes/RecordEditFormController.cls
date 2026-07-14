/**
* @author Maximo Martinez
* @date 12/11/2019
* @description Clase controladora de la vista recordEditForm
*/
public with sharing class RecordEditFormController {
    
    /**
    * @author Maximo Martinez
    * @date 12/11/2019
    * @description Obtiene el descriptor de un layout a partir del id de un registro y su recordtype
    */
    @AuraEnabled
    public static SalesforceModel.LayoutDescribeResult getLayoutDescribe(String objectApiName ,Id recordTypeId){
        return new SalesforceRestClient().getDescribeLayout(objectApiName, recordTypeId);
    }

    /**
    * @author Maximo Martinez
    * @date 12/11/2019
    * @description Obtiene los campos de un Field Set a partir del sObject y el nombre del FieldSet
    */
    @AuraEnabled
    public static List<SalesforceModel.DescribeFieldResult> getDescribeFieldResultsByFieldSet(String objectApiName, String fieldSet){

        List<SalesforceModel.DescribeFieldResult> describeFieldResult = new List<SalesforceModel.DescribeFieldResult>();
        
        Schema.DescribeSObjectResult describeSObjectResultObj = getDescribeResultBysObjectApiName(objectApiName);

        Schema.FieldSet fieldSetObj = describeSObjectResultObj.FieldSets.getMap().get(fieldSet);

        for(Schema.FieldSetMember fsm : fieldSetObj.getFields()){
            
            Schema.DescribeFieldResult dfr = getDescribeFieldResultByFieldApiName(describeSObjectResultObj,fsm.getFieldPath());

            SalesforceModel.DescribeFieldResult auxDFR = new SalesforceModel.DescribeFieldResult();
            auxDFR.type = dfr.getType().name();
            auxDFR.name = dfr.getName();
            auxDFR.label = dfr.getLabel();
            auxDFR.length = dfr.getLength();
            auxDFR.isRequired = (dfr.isNillable())?fsm.getRequired():!dfr.isNillable();
            auxDFR.digits = dfr.getDigits();
            auxDFR.precision = dfr.getPrecision();
            auxDFR.scale = dfr.getScale();
            describeFieldResult.add(auxDFR);

        }

        return describeFieldResult;
    }

    /**
    * @author Maximo Martinez
    * @date 02/12/2019
    * @description Obtiene el descriptor de un objecto a partir de su nombre de api
    */
    private static Schema.DescribeSObjectResult getDescribeResultBysObjectApiName(String objectApiName){
        return Schema.getGlobalDescribe().get(objectApiName).getDescribe();
    }

    /**
    * @author Maximo Martinez
    * @date 02/12/2019
    * @description Obtiene el descriptor de un campo a partir de su nombre de api
    */
    private static Schema.DescribeFieldResult getDescribeFieldResultByFieldApiName(Schema.DescribeSObjectResult dsr, String fieldApiName){
        return dsr.fields.getMap().get(fieldApiName).getDescribe();
    }

    

}