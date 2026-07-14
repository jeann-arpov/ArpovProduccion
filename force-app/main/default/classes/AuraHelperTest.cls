@IsTest
public with sharing class AuraHelperTest {
    
    @IsTest
    static void testGetFieldSetFieldsByFieldSetName(){
        
        Test.startTest();
        AuraHelper.getFieldSetFieldsByFieldSetName('Case','Informar_Pago');
        Test.stopTest();
        
    }

}