/**
* @author Maximo Martinez
* @date 02/06/2020
* @description Clase controladora de la Vista CustomLookup
*/
public with sharing class CustomDataTableController {
    
    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Metodo que devuleve las columnas a mostrar por el componente
    */
    @AuraEnabled
    public static List<DataTableModel.Column> getColumns(String fieldSetApiName, String objectApiName){

        List<DataTableModel.Column> columns = new List<DataTableModel.Column>();

        // Obtenemos los campos del field set y generemos columnas
        for(Schema.FieldSetMember fsm : AuraController.getFieldSet(objectApiName,fieldSetApiName)){

            Schema.DescribeFieldResult dFieldResult = new AuraController.Parser(fsm,Schema.getGlobalDescribe().get(objectApiName).getDescribe().getSObjectType()).getDescribe();

            columns.add(new DataTableModel.Column(dFieldResult));

        }

        return columns;
    
    }

}