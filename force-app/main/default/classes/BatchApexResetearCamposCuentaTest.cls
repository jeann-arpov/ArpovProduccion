@IsTest
public with sharing class BatchApexResetearCamposCuentaTest {
    
    @TestSetup 
    static void setup(){

        Destinatarios_Errores_Batchs__c deb = new Destinatarios_Errores_Batchs__c();
        deb.Name = 'Test';
        deb.Email__c = 'test@email.com';
        insert deb;
		
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
    
    @IsTest
    static void test(){
        
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
        
        Test.startTest();
        Database.executeBatch(new BatchApexResetearCamposCuenta());
        Test.stopTest();

        new SchedulableResetearCamposCuenta().execute(null);

    }

    @IsTest
    static void testResetearCuentaError(){
        
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

        BatchApexResetearCamposCuenta batch = new BatchApexResetearCamposCuenta();

        batch.errors.add('Test');

        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

    }

    @IsTest
    static void testTransaccionesError(){
        
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

        BatchApexSetCamposTransEnCuenta batch = new BatchApexSetCamposTransEnCuenta();
        batch.errors.add('Test');

        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

    }

}