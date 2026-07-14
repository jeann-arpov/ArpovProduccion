@istest
public class CustomDataTableControllerTest {
    
    @isTest static void testgetColumns() {

        String fieldSetName = 'ItemsToApproveList';
        String sObjectName = 'ERPvs__Comprobante_Compra__c';

        List<DataTableModel.Column> columns = CustomDataTableController.getColumns(fieldSetName,sObjectName);

        Map<String, Schema.SObjectType> globalDescribeMap = Schema.getGlobalDescribe(); 
        Schema.SObjectType sObjectTypeObj = globalDescribeMap.get(sObjectName);
        Schema.DescribeSObjectResult describeSObjectResultObj = sObjectTypeObj.getDescribe();

        Schema.FieldSet fieldSetObj = describeSObjectResultObj.FieldSets.getMap().get(fieldSetName);


        System.assertEquals(columns.size(),fieldSetObj.getFields().size());


    }

}