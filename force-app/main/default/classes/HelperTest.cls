/**
* @author Maximo Martinez
* @date 22/06/2020
* @description Clase con metodos unitarios de la clase Helper
*/
@isTest 
public with sharing class HelperTest {
    
	@isTest static void testGetSessionIdFromVFPage(){
		Helper.getSessionIdFromVFPage(Page.getSessionIdVF);
    }

    @isTest static void testGetMasterRecordType(){
        Helper.getMasterRecordType('Account');
    }

    @isTest static void testGetExchangeRate(){
        System.assertEquals(1,Helper.getExchangeRate('USD'));
    }

}