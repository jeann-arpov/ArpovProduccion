@istest
public class DataTableModelTest {
    
    @istest static void test() {

        DataTableModel.Column cm = new DataTableModel.Column();
        cm.label = 'Test';
        cm.fieldName = 'test';
        cm.type = 'boolean';
        cm.editable = true;
        cm.cellAttributes = new DataTableModel.CellAttributes();
        cm.cellAttributes.iconName = new DataTableModel.IconName();
        cm.cellAttributes.iconName.fieldName = 'test';
        cm.cellAttributes.iconPosition = 'test';
        cm.typeAttributes = new DataTableModel.TypeAttributes();
        cm.typeAttributes.day = 'test';
        cm.typeAttributes.month = 'test';
        cm.typeAttributes.target = 'test';
        cm.typeAttributes.year = 'test';

    }

    @istest static void testFromFieldDescribeResult() {


        DataTableModel.Column cm = new DataTableModel.Column(Account.Name.getDescribe());

        System.assertEquals(cm.fieldName, Account.Name.getDescribe().getName());

    }

}