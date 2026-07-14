@isTest
public class lookupfieldController_Test {
    //This test class just ensures that there is enough code coverage
    //to get the component into production from your sandbox
    //it does not perform any validations.
    static testMethod void testLookupField() {
        List<string> returnFields = new List<string> {'Name'};
        Account a = new Account(Name = 'test');
        insert a;
        
        lookupfieldController.getObjectDetails('Account');
        lookupfieldController.GetRecentRecords('Account', returnFields, 5, 'CreatedDate > 2001-01-01T00:00:01Z');
        lookupfieldController.SearchRecords('Account', returnFields, returnFields, '', 'Name', 'ASC', 5, 'CreatedDate > 2001-01-01T00:00:01Z');
        lookupfieldController.GetRecord('Account', returnFields, a.Id);
    }
}