@isTest
private class Test_GestionController {

	@TestSetup static void setup(){
		
		ERPvs.TestUtils.insertDatosGenerales();

		List <ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

		//Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);

     	//Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA',75);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test',false);
		campanaAgricola.Estado__c = 'Activa';
        insert campanaAgricola;
        
        System.debug(LoggingLevel.WARN,JSON.serialize([SELECT Estado__c, Cultivo__r.Name FROM Campana_Agricola__c]));
        System.debug(LoggingLevel.WARN,[SELECT Name FROM Cultivo__c]);
        
        Localidad__c localidad = new Localidad__c();
        localidad.Zona_Bolsa_Cereales__c = 'Test';
        insert localidad;

     	ERPvs__Categoria_IVA__c categoria = new ERPvs__Categoria_IVA__c ();
        categoria.Name = '1';
        categoria.ERPvs__Nombre__c = 'uno';
        categoria.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        categoria.ERPvs__Letra_Comprobante_Venta__c = 'A';
        insert categoria;

        Account productor = new Account();
        productor.Name = 'Productor';
        productor.Es_Socio__c = true;
        productor.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Productor');
        productor.Clave_Unica__c = 'productor';
        productor.N_CUIT__c = '30641405554';
        productor.Condicion_Impositiva__c = 'No Aplica';
        productor.Localidad_Envio__c = localidad.Id;
        productor.Type = 'Productor';
        productor.ERPvs__Categoria_IVA__c = categoria.Id;
        productor.Cuenta_Activa__c = true;
        insert productor;

	}

	
	@isTest static void testGetCampanaAgricola() {
		GestionController.getCampanaAgricola();
	}
	
	@isTest static void testSave() {
		
		Case caso = new Case();
        insert caso;

		Interaccion_Nueva__c it = new Interaccion_Nueva__c();
		it.Cuenta__c = [SELECT Id FROM Account WHERE Name = 'Productor' LIMIT 1].Id;

		List<Documento_Gestionado__c> documentosGestionados = new List<Documento_Gestionado__c>();

		Documento_Gestionado__c doc1 = new Documento_Gestionado__c();
		doc1.Fecha_Comprometida_Respuesta__c = Date.today().addDays(1);

		documentosGestionados.add(doc1);

		Integer cantTask = [SELECT COUNT() FROM Task WHERE WhatId = :it.Cuenta__c];

		
		it = GestionController.save(it,documentosGestionados,null,null,null,null,null,null,null,null,null);

		System.assertNotEquals(it.Id,null);
		System.assertEquals([SELECT COUNT() FROM Task WHERE WhatId = :it.Cuenta__c],1);
		System.assertNotEquals(doc1.Id,null);

		

	}

	@isTest static void testGetConfig(){
		GestionController.getConfig();
	}

	@isTest static void testGetCampanasAgricolas(){
		GestionController.getCampanasAgricolas();
	}

	@isTest static void testGetInteraccion(){

		Interaccion_Nueva__c it = new Interaccion_Nueva__c();
		it.Cuenta__c = [SELECT Id FROM Account WHERE Name = 'Productor' LIMIT 1].Id;
		insert it;

		GestionController.getInteraccion(it.Id);

	}
	
}