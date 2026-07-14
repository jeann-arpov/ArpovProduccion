@isTest
private class Test_UtilsOpportunity {
	
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

    }

	@isTest static void testAsociaNCToFCByNC() {

		//Creamos los datos de Test
		//Obtenemos la lista de precios standard del sitio
        Id idPricebook2 = Utils.getPricebook2Id();

        Pricebook2 listaPrecios = new Pricebook2(Id = idPricebook2);
        
        //Creamos datos de Test
        
        Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account productor = Test_TestUtils.crearProductor();
        
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
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor));
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor));
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),null,obtentor , cultivo, campanaAgricola, productor, 'Respondida', hoy, false);
      
        //Creamos una Opportunidad para la Transaccion 1
        Opportunity oportunidad = Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', t, 'FC');
        
        //Agregamos el Número de Comprobante
        oportunidad.N_de_Comprobante__c = '123456';
        
        update oportunidad;

        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy, false);
        
       	t1.Factura__c = oportunidad.Id;

        t1.Estado__c = 'Facturada';

        t1.Nro_Comprobante__c = oportunidad.N_de_Comprobante__c;

        insert t1;

        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
        
        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        Item_de_DUP__c item = Test_TestUtils.crearItemDeDUP(productos.get(0), t1, 100, 'Uso Propio',1);

        t.Subestado__c = 'Negativa';

        t.DUP_Original__c = t1.Id;

        insert t;
        
        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(0), t, -100, 'Uso Propio',-1, false));
        
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(1), t, -100, 'Uso Propio',-1, false));

        insert items;
        
        new CreateOppsFromTransactions().createDups(new Set<Id>{t.Id});

        List<Transaccion__c> ts = [SELECT Factura__c FROM Transaccion__c WHERE Id = :t.Id LIMIT 1];

        if(ts.size() > 0){
        	UtilsOpportunity.asociaNCToFC(new Set<Id>{ts.get(0).Factura__c});
        }


	}
	
	@isTest static void testAsociaNCToFCByFC() {
		

		//Creamos los datos de Test
		//Obtenemos la lista de precios standard del sitio
        Id idPricebook2 = Utils.getPricebook2Id();

        Pricebook2 listaPrecios = new Pricebook2(Id = idPricebook2);
        
        //Creamos datos de Test
        
        Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account productor = Test_TestUtils.crearProductor();
        
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
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor));
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor));
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),null,obtentor , cultivo, campanaAgricola, productor, 'Respondida', hoy, false);
      
        //Creamos una Opportunidad para la Transaccion 1
        Opportunity oportunidad = Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', t, 'FC');
        
        //Agregamos el Número de Comprobante
        oportunidad.N_de_Comprobante__c = '123456';
        
        update oportunidad;

        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy, false);

       	t1.Factura__c = oportunidad.Id;

        t1.Estado__c = 'Facturada';

        t1.Nro_Comprobante__c = oportunidad.N_de_Comprobante__c;

        insert t1;

        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
        
        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        Item_de_DUP__c item = Test_TestUtils.crearItemDeDUP(productos.get(0), t1, 100, 'Uso Propio',1);

        t.Subestado__c = 'Negativa';

        t.DUP_Original__c = t1.Id;

        insert t;
        
        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(0), t, -100, 'Uso Propio',-1, false));
        
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(1), t, -100, 'Uso Propio',-1, false));
        
        new CreateOppsFromTransactions().createDups(new Set<Id>{t.Id});

        UtilsOpportunity.asociaNCToFC(new Set<Id>{t1.Factura__c});


	}
	
}