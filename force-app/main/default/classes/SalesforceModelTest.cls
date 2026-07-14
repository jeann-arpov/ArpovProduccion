@istest
public class SalesforceModelTest {
    
    @istest static void testLayoutDescribeResult() {

        SalesforceModel.LayoutDescribeResult ldr = new SalesforceModel.LayoutDescribeResult();
        ldr.relatedLists = new List<SalesforceModel.RelatedList>();
        ldr.detailLayoutSections = new List<SalesforceModel.LayoutSection>();

        SalesforceModel.RelatedList rl = new SalesforceModel.RelatedList();
        rl.custom = true;
        rl.field = 'Test';
        rl.label = 'Test';
        rl.limitRows = 5;
        rl.name = 'Test';
        rl.columns = new List<SalesforceModel.Column>();
        ldr.relatedLists.add(rl);

        SalesforceModel.LayoutSection ls = new SalesforceModel.LayoutSection();
        ls.columns = 1;
        ls.heading = 'Test';
        ls.layoutRows = new List<SalesforceModel.LayoutRow>();
        ldr.detailLayoutSections.add(ls);

        SalesforceModel.LayoutRow lr = new SalesforceModel.LayoutRow();
        lr.numItems = 1;
        lr.layoutItems = new List<SalesforceModel.LayoutItem>();
        ls.layoutRows.add(lr);

        SalesforceModel.LayoutItem li = new SalesforceModel.LayoutItem();
        li.label = 'Test';
        li.editableForNew = true;
        li.editableForUpdate = true;
        li.label = 'Test';
        li.layoutComponents = new List<SalesforceModel.LayoutComponent>();
        lr.layoutItems.add(li);

        SalesforceModel.LayoutComponent lc = new SalesforceModel.LayoutComponent();
        lc.details = new SalesforceModel.LayoutComponentDetail();
        li.layoutComponents.add(lc);

        SalesforceModel.Column cm = new SalesforceModel.Column();
        cm.field = 'Test';
        cm.fieldApiName = 'Test';
        cm.format = 'Test';
        cm.label = 'Test';
        cm.lookupId = 'Test';
        cm.name = 'Test';
        cm.sortable = true;
        rl.columns.add(cm);


    }

    @istest static void testListViewDescribeResult(){

        SalesforceModel.ListViewDescribeResult lvdr = new SalesforceModel.ListViewDescribeResult();

        lvdr.columns = new  List<Map<String, String>>();
        lvdr.id = UserInfo.getUserId();
        lvdr.query = 'SELECT Id FROM User LIMIT 1';
        lvdr.sobjectType = 'User';

    }

    @istest static void testDescribeFieldResult(){

        SalesforceModel.DescribeFieldResult dfr = new SalesforceModel.DescribeFieldResult();
        dfr.digits = 3;
        dfr.isRequired = true;
        dfr.label = 'label';
        dfr.length = 1;
        dfr.name = 'test';
        dfr.precision = 1;
        dfr.scale = 1;
        dfr.type = 'test';

    }

}