@isTest
private class Test_CustomMultiSelectLookupController {
	
	@isTest static void testFetchLookUpValues() {
		CustomMultiSelectLookupController.fetchLookUpValues('VCS','User', [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]);
	}
	
}