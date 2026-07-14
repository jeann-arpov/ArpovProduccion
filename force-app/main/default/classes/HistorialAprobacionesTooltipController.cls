/**
* @author Maximo Martinez
* @date 11/0/2020
* @description Controlador del Componente Lightning historialAprobacinesTooltip
*/
public with sharing class HistorialAprobacionesTooltipController {

    /**
    * @author Maximo Martinez
    * @date 11/0/2020
    * @description Clase auxiliar que actua como interfaz entre el componente y el controlador
    */
    @AuraEnabled
    public static Response getData(Id recordId, String relatedListApiName){
        
        Response r = new Response();

        SalesforceModel.RelatedList rList = getRelatedListByName(recordId,relatedListApiName);

        r.records = queryRecordsFromRelatedList(recordId, rList)[0].getSObjects(rList.name);
        r.columns = rList.columns;

        return r;

    }

    /**
    * @author Maximo Martinez
    * @date 11/0/2020
    * @description Metodo que devuelve la Salesforce's RelatedList a partir de su nombre 
    */
    private static SalesforceModel.RelatedList getRelatedListByName(Id recordId, String relatedListApiName){

        SalesforceModel.LayoutDescribeResult lDescribeResult = new SalesforceRestClient().getDescribeLayout(Utils.getObjectTypeById(recordId).getDescribe().getName());

        System.debug(lDescribeResult);

        SalesforceModel.RelatedList rListResult;

        for(SalesforceModel.RelatedList rList : lDescribeResult.relatedLists){

            if(rList.name == relatedListApiName){
                rListResult = rList;
                break;
            }

        }

        return rListResult;

    }

    /**
    * @author Maximo Martinez
    * @date 11/0/2020
    * @description Metodo que obtiene los registros de la misma forma en que figuran en una ListaRelacionada
    */
    private static List<SObject> queryRecordsFromRelatedList(Id recordId, SalesforceModel.RelatedList rList){
        return Database.query(String.format('SELECT ({0}) FROM {1} WHERE Id = :recordId', new List<String>{buildQueryFromRelatedList(recordId,rList),Utils.getObjectTypeById(recordId).getDescribe().name}));
    }

    /**
    * @author Maximo Martinez
    * @date 11/0/2020
    * @description Metodo que obtiene los registros de la misma forma en que figuran en una ListaRelacionada
    */
    private static String buildQueryFromRelatedList(Id recordId, SalesforceModel.RelatedList rList){

        List<String> fieldNames = new List<String>();

        for(SalesforceModel.Column clm : rList.columns){
            fieldNames.add(clm.name);
        }

        return String.format('SELECT ProcessNode.Name, {0} FROM {1} ORDER BY IsPending DESC, CreatedDate DESC', new List<String>{String.join(fieldNames,','),rList.name});

    }

    
    /**
    * @author Maximo Martinez
    * @date 11/0/2020
    * @description Clase auxiliar que actua como interfaz entre el componente y el controlador
    */
    public class Response{
        @AuraEnabled
        public List<SObject> records {get; set;}
        @AuraEnabled
        public List<SalesforceModel.Column> columns {get; set;}
    }

}