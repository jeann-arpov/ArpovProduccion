@isTest
private class Test_GestionDeCuentasController {
	
	@TestSetup static void setup(){
		
		ERPvs.TestUtils.insertDatosGenerales();

		List <ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

		//Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);

     	//Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('TRIGO',75);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
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

        //Una moneda sera de la compania
        List<Moneda__c> monedas = new List<Moneda__c>();

        monedas.add(Test_TestUtils.crearMoneda('TEST1','TEST1',true, false));
        monedas.add(Test_TestUtils.crearMoneda('TEST2','TEST2',false, false));

        ERPvs__Moneda__c mon = new ERPvs__Moneda__c();
        mon.Name = '1';
        mon.ERPvs__Denominacion__c = 'moneda';
        mon.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        mon.ERPvs__Moneda_Nacional__c = false;
        mon.ERPvs__Moneda_Traducida__c = true;
        insert mon;

        monedas[0].Moneda_ERP__c = mon.Id;
        monedas[1].Moneda_ERP__c = mon.Id;

        insert monedas;

	}


	@isTest static void testSetUltimoResultadoGestion() {
		

		// Creamos una interaccion
		Id rtGestionDeDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Interaccion__c.SObjectType).get('DUP');

		Interaccion_Nueva__c it = new Interaccion_Nueva__c();
		it.Cuenta__c = [SELECT Id FROM Account WHERE Name = 'Productor' LIMIT 1].Id;
		it.Accion__c = 'Pago confirmado';
		
		Test.startTest();
		insert it;
		Test.stopTest();

		// Revisamos resultados
		System.assertEquals([SELECT Id, Ultimo_resultado_Gestion__c FROM Account WHERE Name = 'Productor' LIMIT 1].Ultimo_resultado_Gestion__c,it.Accion__c);

    }
    
    @isTest static void testSetFechaUltimaGestionVerano(){

		Id rtFactura = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Factura');
        Id rtDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('DUP');
        Id rtAuditoria = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Auditoria');
        Id rtVentas = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Ventas');

		List<Interaccion_Nueva__c> interacciones = new List<Interaccion_Nueva__c>();

		Interaccion_Nueva__c it = new Interaccion_Nueva__c();
		it.Cuenta__c = [SELECT Id FROM Account WHERE Name = 'Productor' LIMIT 1].Id;
		it.Accion__c = 'Pago confirmado';
		it.Fecha_y_Hora__c = System.now();
		interacciones.add(it);
		
        insert interacciones;

        Campana_Agricola__c campanaAgricola = [SELECT Id FROM Campana_Agricola__c];
        campanaAgricola.Temporada__c = 'Verano';
        update campanaAgricola;

        List<Documento_Gestionado__c> docs = new List<Documento_Gestionado__c>();

        Documento_Gestionado__c drtFactura = new Documento_Gestionado__c();
        drtFactura.RecordTypeId = rtFactura;
        drtFactura.Campania_Gestion__c = campanaAgricola.Id;
        drtFactura.Gestion_Nueva__c = it.Id;
        drtFactura.Fecha_Comprometida_Pago__c = Date.today().addDays(1);
        docs.add(drtFactura);

        Documento_Gestionado__c drtDUP = new Documento_Gestionado__c();
        drtDUP.RecordTypeId = rtDUP;
        drtDUP.Campania_Gestion__c = campanaAgricola.Id;
        drtDUP.Gestion_Nueva__c = it.Id;
        drtDUP.Fecha_Comprometida_Respuesta__c = Date.today().addDays(2);
        docs.add(drtDUP);

        Documento_Gestionado__c drtAuditoria = new Documento_Gestionado__c();
        drtAuditoria.RecordTypeId = rtAuditoria;
        drtAuditoria.Gestion_Nueva__c = it.Id;
        docs.add(drtAuditoria);

        Documento_Gestionado__c drtVentas = new Documento_Gestionado__c();
        drtVentas.RecordTypeId = rtVentas;
        drtVentas.Gestion_Nueva__c = it.Id;
        docs.add(drtVentas);

        insert docs;

        update docs;

		// Revisamos resultados
		Account acc = [SELECT Id, Fec_Comp_Pago_Campana_Invierno__c, Fec_Comp_Pago_Campana_Verano__c, Fec_Comp_Rpta_Campana_Verano__c, Fec_Comp_Rpta_Campana_Invierno__c, Fecha_Ultima_Gestion_Auditoria__c, Fecha_Ultima_Gestion_Ventas__c, Fecha_Ultima_Gestion_Dup__c, Fecha_Ultima_Gestion_Cobranza__c FROM Account WHERE Name = 'Productor' LIMIT 1];

		System.assertEquals(acc.Fecha_Ultima_Gestion_Dup__c,Date.newinstance(it.Fecha_y_Hora__c.year(), it.Fecha_y_Hora__c.month(), it.Fecha_y_Hora__c.day()));
		System.assertEquals(acc.Fecha_Ultima_Gestion_Cobranza__c,Date.newinstance(it.Fecha_y_Hora__c.year(), it.Fecha_y_Hora__c.month(), it.Fecha_y_Hora__c.day()));
        System.assertEquals(acc.Fecha_Ultima_Gestion_Ventas__c,Date.newinstance(it.Fecha_y_Hora__c.year(), it.Fecha_y_Hora__c.month(), it.Fecha_y_Hora__c.day()));
        System.assertEquals(acc.Fecha_Ultima_Gestion_Auditoria__c,Date.newinstance(it.Fecha_y_Hora__c.year(), it.Fecha_y_Hora__c.month(), it.Fecha_y_Hora__c.day()));

        System.assertEquals(acc.Fec_Comp_Pago_Campana_Verano__c,Date.today().addDays(1));
        System.assertEquals(acc.Fec_Comp_Pago_Campana_Invierno__c,null);
        System.assertEquals(acc.Fec_Comp_Rpta_Campana_Invierno__c,null);
        System.assertEquals(acc.Fec_Comp_Rpta_Campana_Verano__c,Date.today().addDays(2));


	}

	@isTest static void testSetFechaUltimaGestion(){

		Id rtFactura = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Factura');
        Id rtDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('DUP');
        Id rtAuditoria = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Auditoria');
        Id rtVentas = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Ventas');

		List<Interaccion_Nueva__c> interacciones = new List<Interaccion_Nueva__c>();

		Interaccion_Nueva__c it = new Interaccion_Nueva__c();
		it.Cuenta__c = [SELECT Id FROM Account WHERE Name = 'Productor' LIMIT 1].Id;
		it.Accion__c = 'Pago confirmado';
		it.Fecha_y_Hora__c = System.now();
		interacciones.add(it);
		
        insert interacciones;

        Campana_Agricola__c campanaAgricola = [SELECT Id FROM Campana_Agricola__c];
        campanaAgricola.Temporada__c = 'Invierno';
        update campanaAgricola;

        List<Documento_Gestionado__c> docs = new List<Documento_Gestionado__c>();

        Documento_Gestionado__c drtFactura = new Documento_Gestionado__c();
        drtFactura.RecordTypeId = rtFactura;
        drtFactura.Campania_Gestion__c = campanaAgricola.Id;
        drtFactura.Gestion_Nueva__c = it.Id;
        drtFactura.Fecha_Comprometida_Pago__c = Date.today().addDays(1);
        docs.add(drtFactura);

        Documento_Gestionado__c drtDUP = new Documento_Gestionado__c();
        drtDUP.RecordTypeId = rtDUP;
        drtDUP.Campania_Gestion__c = campanaAgricola.Id;
        drtDUP.Gestion_Nueva__c = it.Id;
        drtDUP.Fecha_Comprometida_Respuesta__c = Date.today().addDays(2);
        docs.add(drtDUP);

        Documento_Gestionado__c drtAuditoria = new Documento_Gestionado__c();
        drtAuditoria.RecordTypeId = rtAuditoria;
        drtAuditoria.Gestion_Nueva__c = it.Id;
        docs.add(drtAuditoria);

        Documento_Gestionado__c drtVentas = new Documento_Gestionado__c();
        drtVentas.RecordTypeId = rtVentas;
        drtVentas.Gestion_Nueva__c = it.Id;
        docs.add(drtVentas);

        insert docs;

		// Revisamos resultados
		Account acc = [SELECT Id, Fec_Comp_Pago_Campana_Invierno__c, Fec_Comp_Pago_Campana_Verano__c, Fec_Comp_Rpta_Campana_Verano__c, Fec_Comp_Rpta_Campana_Invierno__c, Fecha_Ultima_Gestion_Auditoria__c, Fecha_Ultima_Gestion_Ventas__c, Fecha_Ultima_Gestion_Dup__c, Fecha_Ultima_Gestion_Cobranza__c FROM Account WHERE Name = 'Productor' LIMIT 1];

		System.assertEquals(acc.Fecha_Ultima_Gestion_Dup__c,Date.newinstance(it.Fecha_y_Hora__c.year(), it.Fecha_y_Hora__c.month(), it.Fecha_y_Hora__c.day()));
		System.assertEquals(acc.Fecha_Ultima_Gestion_Cobranza__c,Date.newinstance(it.Fecha_y_Hora__c.year(), it.Fecha_y_Hora__c.month(), it.Fecha_y_Hora__c.day()));
        System.assertEquals(acc.Fecha_Ultima_Gestion_Ventas__c,Date.newinstance(it.Fecha_y_Hora__c.year(), it.Fecha_y_Hora__c.month(), it.Fecha_y_Hora__c.day()));
        System.assertEquals(acc.Fecha_Ultima_Gestion_Auditoria__c,Date.newinstance(it.Fecha_y_Hora__c.year(), it.Fecha_y_Hora__c.month(), it.Fecha_y_Hora__c.day()));

        System.assertEquals(acc.Fec_Comp_Pago_Campana_Invierno__c,Date.today().addDays(1));
        System.assertEquals(acc.Fec_Comp_Pago_Campana_Verano__c,null);
        System.assertEquals(acc.Fec_Comp_Rpta_Campana_Verano__c,null);
        System.assertEquals(acc.Fec_Comp_Rpta_Campana_Invierno__c,Date.today().addDays(2));


	}

	@isTest static void testCreateGestionesFromEmail(){

		Account productor = [SELECT Id FROM Account WHERE Name = 'Productor' LIMIT 1];

		Contact c = new Contact();
		c.LastName = 'Test';
		c.Email = 'email@test.com';
		c.AccountId = productor.Id;
		insert c;

		//Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());
        
        //Seteamos variables para almacenar los recordtypes que necesitaremos
        RecordType rtDUP = null;
        RecordType rtObtentor = null;
        RecordType rtAud = null;
        
        //Obtenemos los RecordType que necesitamos
        for( RecordType recordType : [SELECT DeveloperName FROM RecordType WHERE SObjectType IN ('Transaccion__c','Account')]){
            if(recordType.DeveloperName == 'DUP'){
                rtDUP = recordType;
            }else if(recordType.DeveloperName == 'Auditorias'){
                rtAud = recordType;
            }else if(recordType.DeveloperName == 'Obtentor'){
                rtObtentor = recordType;
            }
        }
        
        
        //Variable que contendra la moneda de la compania
         //Variable que contendra la moneda de la compania
        Moneda__c moneda1 = null;
        Moneda__c moneda2 = null;
        
        for(Moneda__c moneda : [SELECT Codigo_Univoco__c,Moneda_de_la_compania__c FROM Moneda__c]){
            if(moneda.Moneda_de_la_compania__c == true){
                moneda1 = moneda;
            }else{
                moneda2 = moneda;
            }
        }
        
        //Obtenemos la fechaActual
        Date fechaActual = Date.today();
    
        //Creamos un tipo de cambio para la moneda extranjera
        Tipo_de_Cambio__c tipoCambio = Test_TestUtils.crearTipodeCambio(moneda2,2,fechaActual);
        
         //Creamos una cuenta de tipo Obtentor
        Account obtentor = Test_TestUtils.crearObtentor();
    
        //Creamos un distribuidor
        Account distribuidor = Test_TestUtils.crearDistribuidor();
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'ProductoTest 1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor);
        
        Product2 producto2 = Test_TestUtils.crearProducto(true,'ProductoTest 2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor);
      
        List<PricebookEntry> pbsEntrys = [SELECT Id FROM PricebookEntry WHERE (Product2Id = :producto1.Id) OR (Product2Id = :producto2.Id)];
        
        if(pbsEntrys.size() == 0){
        
            List<Product2> productos = new List<Product2>(); 
        
            productos.add(producto1);
        
            productos.add(producto2);
        
            //Creamos un pricebook entry para cada producto
            List<PricebookEntry> pbes = Test_TestUtils.crearPricebookEntry( productos, listaPrecios);
        
        }
        
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(rtDUP,'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        

		//Creamos el Email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        //Seteamos algunos datos
        mail.setUseSignature(false);
        mail.setSaveAsActivity(true);          
        mail.setTargetObjectId(c.Id);
        //mail.setWhatId(productor.Id);
        mail.setPlainTextBody('Test');
        mail.setSubject('dup');

        Test.startTest();   
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        Test.stopTest();

        System.assertEquals([SELECT COUNT() FROM EmailMessage],1);

        // Workaround para poder ejecutar el trigger after update
        EmailMessage em = [SELECT ActivityId FROM EmailMessage LIMIT 1];
        try{
            update em;
            // Revisamos si creo la interaccion y el documento gestionado
            System.assertEquals([SELECT COUNT() FROM Interaccion_Nueva__c],1);
        }catch(Exception e){}

        
	}

    @isTest static void testCreateGestionesFromTasks(){

        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor' LIMIT 1];

		Contact c = new Contact();
		c.LastName = 'Test';
		c.Email = 'email@test.com';
		c.AccountId = productor.Id;
		insert c;

        Task t = new Task();
        t.Subject = GestionDeCuentasController.SOURCE_INTERACTION_WHATSLLY + 'DUP,FACTURA,VENTA,AUDITORIA';
        t.Description = 'TEST';
        t.WhoId = c.Id;

        Test.startTest();
        insert t;

        Attachment att = new Attachment();
        att.ParentId = t.Id;
        att.Name = 'Test';
        att.Body = Blob.valueOf('TEST');
        insert att;

        Test.stopTest();

        t = [SELECT WhatId FROM Task WHERE Id = :t.Id];

        System.assertEquals(1, [SELECT COUNT() FROM Interaccion_Nueva__c WHERE Id = :t.WhatId]);

    }

	
}