@isTest
public class Test_tg_Transaccion{
    
    @TestSetup 
    static void setup(){
        List <ERPvs__Datos_Generales__c> dg_insertar = new List<ERPvs__Datos_Generales__c> ();
        
        for (RecordType rtID :[select id, name from RecordType where SobjectType = 'ERPvs__Datos_Generales__c' order by name]) {
            if (rtID.Name == 'General') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'Común a todas las aplicaciones', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Compras') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Compras', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Contabilidad') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Contabilidad', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Ventas') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Facturación', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Fondos') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Fondos', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Stock') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Inventarios', RecordTypeId = rtID.id));
            }
        }
        insert dg_insertar;

        //Una moneda sera de la compania
        List<Moneda__c> monedas = new List<Moneda__c>();

        monedas.add(Test_TestUtils.crearMoneda('TEST1','TEST1',true, false));
        monedas.add(Test_TestUtils.crearMoneda('TEST2','TEST2',false, false));

        List <ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

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

        Hzpc_Integracion__c cs = new Hzpc_Integracion__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Sync_Active__c = true
        );
        insert cs;

        Test_TestUtils.disableFlows();
    }

    @isTest
    public static void testDUP(){
        
        //Creamos los datos necesarios
        
        //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());
        
        //Seteamos variables para almacenar los recordtypes que necesitaremos
        RecordType rtDUP = null;
        RecordType rtObtentor = null;
        
        //Obtenemos los RecordType que necesitamos
        for( RecordType recordType : [SELECT DeveloperName FROM RecordType WHERE SObjectType IN ('Transaccion__c','Account')]){
            if(recordType.DeveloperName == 'DUP'){
                rtDUP = recordType;
            }else if(recordType.DeveloperName == 'Obtentor'){
                rtObtentor = recordType;
            }
        }
        
        
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
        
        Account obtentor = Test_TestUtils.crearObtentor(false);
        obtentor.Name = 'HZPC AMERICA LATINA S.A';
        obtentor.Nombre_Obtentor__c = 'HZPC AMERICA';
        obtentor.Id_Obtentor__c = '73';
        insert obtentor;
        
        Account productor = Test_TestUtils.crearProductor();
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');

        Variedad__c var = new Variedad__c(Name = 'Test');
        insert var;
        
        //Creamos un par de productos
        List<Product2> productos = new List<Product2>();
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.Id, false);
        producto1.RecordTypeId = Product2.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('Regalia_Extendida').getRecordTypeId();
        
        Product2 producto2= Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.Id, false);
        producto2.RecordTypeId = Product2.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('Regalia_Extendida').getRecordTypeId();

        productos.add(producto1);
        
        productos.add(producto2);
        insert productos;
        
        List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE (Product2Id = :producto1.Id) OR (Product2Id = :producto2.Id)];
        
        if(pbes.size() == 0){
        
            //Creamos un pricebook entry para cada producto
            pbes = Test_TestUtils.crearPricebookEntry( productos, listaPrecios);
        
        }

        Test.setMock(HttpCalloutMock.class, new TestCalloutMock(new Map<String, String>(), 200, getTestResponseBody()));
        
        Test.startTest();
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(rtDUP,'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        
        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        Item_de_DUP__c item1 = Test_TestUtils.crearItemDeDUP(productos.get(0), t1, 2, 'Uso Propio',1);
        Item_de_DUP__c item2 = Test_TestUtils.crearItemDeDUP(productos.get(1), t1, 2, 'Uso Propio',1);

        Test.stopTest();

        t1 = [SELECT HZPCId__c FROM Transaccion__c LIMIT 1];

        TransaccionTriggerHelper.getHzpcIds(new List<Transaccion__c>{t1});
        
        //Assert.isTrue(t1.HZPCId__c != null);
    }

    @isTest
    public static void testAuditoria(){
        //Creamos los datos necesarios
        
        //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());
        
        //Seteamos variables para almacenar los recordtypes que necesitaremos
        RecordType rtAud = null;
        RecordType rtObtentor = null;
        
        //Obtenemos los RecordType que necesitamos
        for( RecordType recordType : [SELECT DeveloperName FROM RecordType WHERE SObjectType IN ('Transaccion__c','Account')]){
            if(recordType.DeveloperName == 'Auditorias'){
                rtAud = recordType;
            }else if(recordType.DeveloperName == 'Obtentor'){
                rtObtentor = recordType;
            }
        }
        
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
        
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account productor = Test_TestUtils.crearProductor();
        
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');

        Variedad__c var = new Variedad__c(Name = 'Test');
        insert var;
        
        //Creamos un par de productos
        List<Product2> productos = new List<Product2>();
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.Id, true);
        
        Product2 producto2= Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.Id, true);
        
        productos.add(producto1);
        
        productos.add(producto2);
        
        List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE (Product2Id = :producto1.Id) OR (Product2Id = :producto2.Id)];
        
        if(pbes.size() == 0){
        
            //Creamos un pricebook entry para cada producto
            pbes = Test_TestUtils.crearPricebookEntry( productos, listaPrecios);
        
        }
        
        Test.startTest();
        
        //Creamos una transaccion de tipo Auditoria 
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(rtAud,'00000001', obtentor, cultivo, null, productor, 'Creada', hoy);
        
        //Creamos una transaccion de tipo Auditoria 
        Transaccion__c t2 = Test_TestUtils.crearTransaccion(rtAud,'00000002', obtentor, cultivo, null, productor, 'Creada', hoy);
        
        //Creamos un par de items de auditoria para la Transaccion t1
        Item_Auditoria__c item1 = Test_TestUtils.crearItemAuditoria(productos.get(0), t1, campanaAgricola, 'Irregular', 'Granel', 1,1, false);
        Item_Auditoria__c item2 = Test_TestUtils.crearItemAuditoria(productos.get(1), t1, campanaAgricola, 'Irregular', 'Granel', 1,1, false);
        
        //Creamos un par de item de auditoria para la Transaccion t2
        Item_Auditoria__c item3 = Test_TestUtils.crearItemAuditoria(productos.get(0), t2, campanaAgricola, 'Irregular', 'Granel', 1,1, false);
        Item_Auditoria__c item4 = Test_TestUtils.crearItemAuditoria(productos.get(1), t2, campanaAgricola, 'Irregular', 'Granel', 1,1, false);
        
        Provincia__c prov = new Provincia__c();

        prov.Name = 'Test';

        insert prov;

        item1.Lugar_de_Siembra__c = prov.Id;
        item2.Lugar_de_Siembra__c = prov.Id;
        item3.Lugar_de_Siembra__c = prov.Id;
        item4.Lugar_de_Siembra__c = prov.Id;

        List<Item_Auditoria__c> items = new  List<Item_Auditoria__c>{item1, item2,item3, item4};  

        insert items;
        
        //Cambiamos el estado de las transacciones a 'Completa'
        t1.Estado__c = 'Completa';
        t2.Estado__c = 'Completa';
        
        //Actualizamos
        //update t1;
        //update t2;
        
        Test.stopTest();
    }

    @isTest
    static void testDUPSyncDelete(){
        Set<String> hzpcIds = new Set<String>{'a000FGtwCMAJ'};

        Test.setMock(HttpCalloutMock.class, new TestCalloutMock(new Map<String, String>(), 200, getTestResponseBody()));

        Test.startTest();

        HzpcSync.doSyncDeleteTransacciones(JSON.serialize(hzpcIds));

        Test.stopTest();
    }

    public static String getTestResponseBody(){
        return '[{"success": true, "id": "a000FGtwCMAJ", "errors": []}]';
    }

    public class TestCalloutMock implements HttpCalloutMock {

		public Map<String,String> headers;
		public Integer statusCode;
		public String body;	

		public TestCalloutMock(Map<String,String> headers, Integer statusCode, String body){
			this.headers = headers;
			this.statusCode = statusCode;
			this.body = body;
		}

        public HTTPResponse respond(HTTPRequest req) {
        
            HttpResponse res = new HttpResponse();
            
            for(String key : headers.keySet()){
            	res.setHeader(key,headers.get(key));
            }

            if(String.isNotEmpty(body)){
            	res.setBody(body);
        	}
        
            res.setStatusCode(statusCode);
        
            return res;

        }

    }
}