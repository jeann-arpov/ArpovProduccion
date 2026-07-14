@isTest
private class Test_UtilsRemesa {
	
	@isTest static void test_method_one() {
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
                Remesa__c remesa = Test_TestUtils.crearRemesa('Pendiente', 'Correo Electrónico', lote, productor);

                //Insertamos en la DB
                insert remesa;

                // Obtenemos el contacto del productor
                Contact contacto = [SELECT Id, Name FROM Contact WHERE Account.Id = :productor.Id];

                // Creamos el contacto Remesa
                Contacto_Remesa__c contactoRemesa = Test_TestUtils.crearContactoRemesa('Contacto Remesa', remesa, contacto, true);

                
                Attachment a = new Attachment();
                a.ParentId = remesa.Id;
                a.Name = 'Name';
                a.body = Blob.valueOf('test');
                insert a;
                
                Id casoDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');
                
                Case cP = new Case();
                cP.RecordTypeId = casoDUP;
                insert cP;
                
                Case c = new Case();
                c.RecordTypeId = casoDUP;
                c.ParentId = cP.ID;
                insert c;
            
                Task t = new Task();
                
                t.WhatId = contactoRemesa.Id;
                t.Status = 'Cerrada';
                t.Subject = 'Llamada';
                t.ActivityDate = Date.today();
                t.Description = 'Description';
                
                insert t;

                //Llamamos al metodo
                UtilsRemesa.setearContactoRemesaEnviado(new List<Task>{t});

	}
	
}