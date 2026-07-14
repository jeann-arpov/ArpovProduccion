@isTest
private class Test_BatchApexDupsPDFs {
	
	@testSetup static void setDatosGenerales() {
        //Creamos un productor
        Account productor = Test_TestUtils.crearProductor();
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
    
        Lote__c lote = Test_TestUtils.crearLote();
        lote.Campana__c = campanaAgricola.Id;
        lote.Cultivo__c = cultivo.Id;
        lote.Tipo__c = 'Basico';
        insert lote;
        
        //Creamos una remesa
        Remesa__c remesa = new Remesa__c();
        
        //Seteamos algunos datos
        remesa.Estado__c = 'Pendiente';
        remesa.Modo_de_Envio__c = 'Correo Electrónico';
        remesa.Lote__c = lote.Id;
        remesa.Productor__c = productor.Id;
        remesa.Name = 'Test';
        insert remesa;

        Destinatarios_Errores_Batchs__c deb = new Destinatarios_Errores_Batchs__c();
        deb.Name = 'Test';
        deb.Email__c = 'test@email.com';
        insert deb;

    }
	
	@isTest static void test() {

		Test.startTest();

		BatchApexDupsPDFs b = new BatchApexDupsPDFs([SELECT Id FROM Lote__c]);
		
		// Se da cobertura al finish
		b.errors.add('Test');

		Database.executeBatch(b, 200);

		Test.stopTest();

		//Revisamos los resultados
		System.assertEquals([SELECT COUNT() FROM Attachment],1);
		System.assertEquals([SELECT COUNT() FROM Lote__c WHERE Lote_Procesado__c = true],1);

	}
	
}