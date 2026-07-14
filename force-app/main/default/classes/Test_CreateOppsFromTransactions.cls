/**
* @author Maximo Martinez
* @date 8/8/2014
* @description Clase de Test del Trigger tg_Account
*/
@isTest
private class Test_CreateOppsFromTransactions {

     @TestSetup 
    static void setup(){
        Test_TestUtils.disableFlows();

        Variedad__c var = new Variedad__c();
        insert var; 
        
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

    }
	
	@isTest static void testCrearOppsFromDUPS() {
		//Creamos los datos necesarios
        
        Test.StartTest();

        //RecordType que usamos en el Test
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
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

        //Creamos un cultivo
        Cultivo__c cultivo1 = Test_TestUtils.crearCultivo('Cultivo Test 1',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        Campana_Agricola__c campanaAgricola2 = Test_TestUtils.crearCampanaAgricola('2015', cultivo, hoy, manana, '2015 - Test');
        
        Variedad__c var = [select id from Variedad__c];
        
        //Creamos un par de productos
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);
        
        Product2 producto2= Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);
              
        Product2 producto3= Test_TestUtils.crearProducto(true,'Producto Test3',moneda2.Codigo_Univoco__c, 'Variedad Test 3', cultivo1,  'Regalía Extendida', 2, obtentor, var.id, true);   
        
        Product2 producto4= Test_TestUtils.crearProducto(true,'Producto Test4',moneda2.Codigo_Univoco__c, 'Variedad Test 4', cultivo1,  'Regalía Extendida', 2, obtentor, var.id, true);
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = False
        Transaccion__c t2 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000002', obtentor, cultivo1, campanaAgricola2, productor, 'Creada', hoy);
        
        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();

        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        items.add(Test_TestUtils.crearItemDeDUP(producto1, t1, 100, 'Uso Propio',1,false));
        items.add(Test_TestUtils.crearItemDeDUP(producto2, t1, 100, 'Uso Propio',1,false));
        
        //Creamos dos Item_de_Dup con estado No Informada
        items.add(Test_TestUtils.crearItemDeDUP(producto3, t2, null, 'No Informada',1,false));
        items.add(Test_TestUtils.crearItemDeDUP(producto4, t2, null, 'No Informada',1,false));   

        insert items;

        new CreateOppsFromTransactions().createDups(new Set<Id>{t1.Id,t2.Id});

        Test.stopTest();
     
	}
	
	@isTest static void testCrearOppsFromAuditorias() {
		//Creamos los datos necesarios
        Variedad__c var = [select id from Variedad__c];

        //RecordType que usamos en el Test
        Id rtAuditorias = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');
        
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
        
        //Creamos un par de productos
        List<Product2> productos = new List<Product2>();
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);
        
        producto1.Unidad_de_Medida__c = '50';

        Product2 producto2= Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);
        
        producto2.Unidad_de_Medida__c = '50';

        //update producto1;
        //update producto2;	

        productos.add(producto1);
        
        productos.add(producto2);

        //Creamos una transaccion de tipo Auditoria 
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtAuditorias),'00000001', obtentor, cultivo, null, productor, 'Creada', hoy);
        
        //Creamos una transaccion de tipo Auditoria 
        Transaccion__c t2 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtAuditorias),'00000002', obtentor, cultivo, null, productor, 'Creada', hoy);
        
        List<Item_Auditoria__c> items = new List<Item_Auditoria__c>();

        //Creamos un par de items de auditoria para la Transaccion t1
        items.add(Test_TestUtils.crearItemAuditoria(productos.get(0), t1, campanaAgricola, 'Irregular', 'Granel', 1,1, false));
        items.add(Test_TestUtils.crearItemAuditoria(productos.get(1), t1, campanaAgricola, 'Irregular', 'Granel', 1,1, false));
        
        //Creamos un par de item de auditoria para la Transaccion t2
        items.add(Test_TestUtils.crearItemAuditoria(productos.get(0), t2, campanaAgricola, 'Irregular', 'Granel', 1,1, false));
        items.add(Test_TestUtils.crearItemAuditoria(productos.get(1), t2, campanaAgricola, 'Irregular', 'Granel', 1,1, false));
        
        Provincia__c prov = new Provincia__c();

        prov.Name = 'Test';

        insert prov;

        items.get(0).Lugar_de_Siembra__c = prov.Id;
        items.get(1).Lugar_de_Siembra__c = prov.Id;
        items.get(2).Lugar_de_Siembra__c = prov.Id;
        items.get(3).Lugar_de_Siembra__c = prov.Id;

        insert items;

        new CreateOppsFromTransactions().createAuds(new Set<Id>{t1.Id,t2.Id});

	}
	
}