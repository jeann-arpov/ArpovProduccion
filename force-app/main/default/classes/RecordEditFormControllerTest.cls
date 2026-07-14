@isTest
public class RecordEditFormControllerTest {
    
    @TestSetup 
    public static void setup(){

    }

    @isTest
    public static void testGetDescribeFieldResultsByFieldSet(){

        Test.startTest();
        RecordEditFormController.getDescribeFieldResultsByFieldSet('Aplicacion__c','WizardAplicacionForm');
        Test.stopTest();

    }

}