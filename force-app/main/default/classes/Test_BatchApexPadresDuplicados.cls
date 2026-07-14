@isTest
private class Test_BatchApexPadresDuplicados {
	
	@isTest static void test_method_one() {
		
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account distribuidor = Test_TestUtils.crearDistribuidor();

        //Obtenemos el RecordType de un Padre
        Id rtPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');

        //Creamos un caso
        Case caso = new Case();
                
        //Seteamos la cuenta a la que esta asociada el caso
        caso.AccountId = distribuidor.Id;
        
        //Seteamos el asunto
        caso.Subject = 'Test';

        caso.Status = 'Abierto';

        insert caso;


        //Creamos un caso
        Case caso1 = new Case();
                
        //Seteamos la cuenta a la que esta asociada el caso
        caso1.AccountId = distribuidor.Id;
        
        //Seteamos el asunto
        caso1.Subject = 'Test';

        caso1.Status = 'Abierto';

        insert caso1;
        
        //Seteamos el RecordType Id del Record Type DUP
        caso.RecordTypeId = rtPId;

        Test.startTest();

        BatchApexDeletePadresDuplicados b = new BatchApexDeletePadresDuplicados();

        Database.executeBatch(b);

        Test.stopTest();

	}
	
}