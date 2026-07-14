/**
* @author Maximo Martinez
* @date 1710/2014
* @description Clase de Test de la Clase Utils
*/
@isTest
private class Test_Utils {
	
	@isTest static void testStringToDate() {
		
		String dt = '08/10/1988';

		Utils.stringToDate(dt);	

	}
	
	@isTest static void testStringToDouble() {
		
		String db = '1.67';

		Utils.stringToDouble(db);
	
	}


	@isTest static void testGetRandomLong() {
		
		Utils.getRandomLong(10);
	
	}


	@isTest static void testSelectByName() {
		
		Utils.selectByName('Account', '');
	
	}


	@isTest static void testCreateToken() {
		
		Account productor = Test_TestUtils.crearProductor();

		Utils.createToken(productor.Id);
	
	}


	@isTest static void testDecryptToken() {
		
		Account productor = Test_TestUtils.crearProductor();

		String url = Utils.createToken(productor.Id);
		
		Utils.decryptToken(url);	

	}

	@isTest static void testSetearTokenProductores() {
		
		Account productor = Test_TestUtils.crearProductor();

		//Utils.setearTokenProductores(new List<Account>{productor});

	}


	@isTest static void testGetGroupId() {
		
		Utils.getGroupId('Legales', 'Case');

	}

	@isTest static void testDeleteList() {
		
		Account productor = Test_TestUtils.crearProductor();

		Utils.deleteList(new List<Account>{productor}, false);

	}

	@isTest static void testInsertList() {
		
		Account productor = Test_TestUtils.crearDistribuidor(false);

		Utils.insertList(new List<Account>{productor}, false);

	}

	@isTest static void testInsertListNoSkip() {
		
		Account productor = Test_TestUtils.crearDistribuidor(false);

		Utils.insertList(new List<Account>{productor});

	}
	
	@isTest static void testGetObjectTypeById() {

		Account productor = Test_TestUtils.crearProductor();

		Utils.getObjectTypeById(productor.Id);

	}


	@isTest static void testGetObjectTypeByName() {

		Utils.getObjectTypeByObjectName('Account');

	}
	
	@isTest static void testGetPricebook2Id() {

		Utils.getPricebook2Id();

	}

	@isTest static void testCheckStringInToSplit() {

		Utils.checkStringInToSplit('/test/test','test');

	}

	@isTest static void testUpdateList(){
		
		Account productor = Test_TestUtils.crearProductor();

		Utils.updateList(new List<Account>{productor});
		Utils.updateList(new List<Account>{productor},false);

	}

	@isTest static void testGetFieldLength(){
		Utils.getFieldLength('Account','Name');
	}

	@isTest static void testConvertirTotalAPalabras(){
		Utils.convertirTotalAPalabras(Decimal.valueOf(10000.12d));
	}

	@isTest static void testFifteenToEighteen(){
		Utils.fifteenToEighteen(UserInfo.getUserId().substring(0,15));
	}

	@isTest static void testNumberFormat(){
		Utils.numberFormat(String.valueOf(10000));
	}

	@isTest static void testFormatNumber(){
		Utils.formatNumber(Decimal.valueOf(10000.12d));
	}

	@isTest static void testupsertList(){
		Utils.upsertList(new List<Documento_Gestionado__c>{new Documento_Gestionado__c()}, false);
		Utils.upsertList(new List<Interaccion__c>{new Interaccion__c()}, false);
		Utils.upsertList(new List<Interaccion_Nueva__c>{new Interaccion_Nueva__c()}, false);
	}

	@isTest static void testDoFormatting(){
		Utils.doFormatting(221189,2,',','.');
	}

}