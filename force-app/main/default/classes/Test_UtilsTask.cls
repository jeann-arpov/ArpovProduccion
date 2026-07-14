@isTest
private class Test_UtilsTask {
	
	@isTest static void testSetearOperadorRemesa() {
		
		// Creamos los datos de Test

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
        insert remesa;
        
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
        
        t.WhatId = remesa.ID;
        t.Status = 'Cerrada';
        t.Subject = 'Llamada';
        t.ActivityDate = Date.today();
        t.Description = 'Description';
        
        insert t;

        //Llamamos al metodo
        UtilsTask.setearOperadorRemesa(new List<Task>{t});
	}
	
	@isTest static void testAdjuntarAttachment() {

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
        insert remesa;
        
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
        
        t.WhatId = remesa.ID;
        t.Status = 'Cerrada';
        t.Subject = 'Llamada';
        t.ActivityDate = Date.today();
        t.Description = 'Description';
        
        insert t;

        //Llamamos al metodo
        UtilsTask.AdjuntaAttachments(new List<Task>{t});	

	}

	@isTest static void testGestionarCaso() {

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
    
        
        Id casoDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');
        
        Case cP = new Case();
        cP.RecordTypeId = casoDUP;
        insert cP;
        
        Case c = new Case();
        c.RecordTypeId = casoDUP;
        c.ParentId = cP.ID;
        insert c;
    
        Task t = new Task();
        
        t.WhatId = c.ID;
        t.Status = 'Cerrada';
        t.Subject = 'Llamada';
        t.ActivityDate = Date.today();
        t.Description = 'Description';
        
        insert t;

        //Llamamos al metodo
        UtilsTask.gestionarCasos(new List<Task>{t});

	}


    /**
    * @author Maximo Martinez
    * @date 28/08/2014
    * @description Metodo que testea el metodo ValidarFechas de la clase UtilsCasoGestionado
    */
    @isTest static void testValidarFechas() {

        //Creamos los datos de prueba

        //Creamos una cuenta
        Account obtentor = Test_TestUtils.crearObtentor();

        //Creamos un caso Padre
        Case casoPadre = Test_TestUtils.crearCasoGestionCUIT(obtentor);

        //Creamos una interaccion
        Interaccion__c interaccion = Test_TestUtils.crearInteraccion(casoPadre);

        //Creamos un caso de tipo DUP
        Case casoDUP = Test_TestUtils.crearCasoDUP(obtentor,casoPadre);

        //Creamos un caso de tipo Cobranza
        Case casoCobranza = Test_TestUtils.crearCasoCobranza(obtentor,casoPadre);

        //Insertamos los caso en la BD
        insert new List<Case>{casoDUP, casoCobranza};

        //Creamos un comentario Gestionado para el Caso DUP
        Task taskDUP = Test_TestUtils.crearTask(casoDUP, '6 - Promesa de Respuesta');

        //Creamos un comentario Gestionado para el Caso Cobranza
        Task taskCobranza = Test_TestUtils.crearTask(casoCobranza, '9 - Solicita Plazo de pago');

        //Insertamos en la BD
        Database.insert(new List<Task>{taskDUP, taskCobranza},false);

        //Ejecutamos el metodo ValidarFechas, por si el trigger no se ejecuta
        UtilsTask.validarFechas(new List<Task>{taskDUP, taskCobranza});

    }
}