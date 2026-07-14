@isTest
private class Test_AuraController {
	
	@isTest static void testRunQuery() {
		AuraController.runQuery('SELECT Id FROM User');
	}

	@isTest static void testGetFieldSet() {
		AuraController.getFieldSet('Opportunity','Gestion_Caso_Factura');
	}


	@isTest static void testGetIconName(){
		AuraController.getIconName('Opportunity');
	}

	@isTest static void testInnerClasses(){

		AuraController.DataTableResponse dtr = new AuraController.DataTableResponse();

	}

	@isTest static void testQuery() {
		AuraController.query('Account', new List<String>{'Id','Name'}, new Map<String, Object>{'Name'=>'Probando'},null,null);
		AuraController.query('Account', new List<String>{'Id','Name'},null,new Map<String, Object>{'Name'=>'Probando'},null);
	}

	@isTest static void testGetColumns(){
		AuraController.getColumns('Transaccion__c','Gestion_Auditorias');
	}

	@isTest static void testFetchUserSessionId(){
		AuraController.fetchUserSessionId();
	}

	@isTest static void testGetDescribeFieldResult(){
		AuraController.getDescribeFieldResult('Account','Owner.Name');
	}

	@isTest static void testGetLookupInformation(){
		AuraController.getLookupInformation(UserInfo.getUserId());
	}

	@isTest static void testGetDescribeSObjectResult(){
		AuraController.getDescribeSObjectResult('Account');
	}

}