@isTest
public class Test_tg_Item_de_DUP{
    
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
    public static void testAgregaTipoCambioBeforeInsert(){
        //Creamos los datos de prueba
        
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
       obtentor.Name = 'HZPC AMERICA LATINA S.A.';
       obtentor.Nombre_Obtentor__c = 'HZPC AMERICA';
       obtentor.Id_Obtentor__c = '73';
       insert obtentor;
        
        Account distribuidor = Test_TestUtils.crearDistribuidor();
        
        
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
        
        //Creamos dos productos
        
        //Creamos un par de productos
        Product2 producto1 = Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor, var.Id, true);
        
        Product2 producto2 = Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor, var.Id, true);
        
        List<PricebookEntry> pbsEntrys = [SELECT Id FROM PricebookEntry WHERE (Product2Id = :producto1.Id) OR (Product2Id = :producto2.Id)];
        
        if(pbsEntrys.size() == 0){
        
            List<Product2> productos = new List<Product2>(); 
            
            productos.add(producto1);
            
            productos.add(producto2);
            
            //Creamos un pricebook entry para cada producto
            List<PricebookEntry> pbes = Test_TestUtils.crearPricebookEntry( productos, listaPrecios);
        
        }

        Test.setMock(HttpCalloutMock.class, new Test_tg_Transaccion.TestCalloutMock(new Map<String, String>(), 200, Test_tg_Transaccion.getTestResponseBody()));
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(rtDUP,'12345678', obtentor, cultivo, campanaAgricola, distribuidor, 'Creada', hoy);
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = False
        Transaccion__c t2 = Test_TestUtils.crearTransaccion(rtDUP,'87654321', obtentor, cultivo, campanaAgricola, distribuidor, 'Creada', hoy);
        
        //Creamos algunos items para las transacciones  
        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
        items.add(Test_TestUtils.crearItemDeDUP(producto1, t1, 0, 'Uso Propio',null));
        items.add(Test_TestUtils.crearItemDeDUP(producto2, t1, 0, 'Uso Propio',null));

        Item_de_DUP__c item = [SELECT HZPCId__c FROM Item_de_DUP__c LIMIT 1];
        
        ItemDeDupTriggerHelper.getHzpcIds(new List<Item_de_DUP__c>{item});
    }

    @isTest
    static void testSyncDelete(){
        Set<String> hzpcIds = new Set<String>{'a000FGtwCMAJ'};

        Test.setMock(HttpCalloutMock.class, new Test_tg_Transaccion.TestCalloutMock(new Map<String, String>(), 200, Test_tg_Transaccion.getTestResponseBody()));

        Test.startTest();

        HzpcSync.doSyncDeleteItemsDup(JSON.serialize(hzpcIds));

        Test.stopTest();
    }
    
    // @isTest
    // public static  void testAgregaTipoCambioBeforeUpdate(){
    //      //Creamos los datos de prueba
        
    //     //Obtenemos la lista de precios standard del sitio
    //     Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());
        
    //     //Seteamos variables para almacenar los recordtypes que necesitaremos
    //     RecordType rtDUP = null;
    //     RecordType rtObtentor = null;
        
    //     //Obtenemos los RecordType que necesitamos
    //     for( RecordType recordType : [SELECT DeveloperName FROM RecordType WHERE SObjectType IN ('Transaccion__c','Account')]){
    //         if(recordType.DeveloperName == 'DUP'){
    //             rtDUP = recordType;
    //         }else if(recordType.DeveloperName == 'Obtentor'){
    //             rtObtentor = recordType;
    //         }
    //     }
        
    //     //Variable que contendra la moneda de la compania
    //     Moneda__c moneda1 = null;
    //     Moneda__c moneda2 = null;
        
    //     for(Moneda__c moneda : [SELECT Codigo_Univoco__c,Moneda_de_la_compania__c FROM Moneda__c]){
    //         if(moneda.Moneda_de_la_compania__c == true){
    //             moneda1 = moneda;
    //         }else{
    //             moneda2 = moneda;
    //         }
    //     }
        
    //     //Obtenemos la fechaActual
    //     Date fechaActual = Date.today();
    
    //     //Creamos un tipo de cambio para la moneda extranjera
    //     Tipo_de_Cambio__c tipoCambio = Test_TestUtils.crearTipodeCambio(moneda2,2,fechaActual);
        
    //    Account obtentor = Test_TestUtils.crearObtentor();
        
    //     Account distribuidor = Test_TestUtils.crearDistribuidor();
        
        
    //     //Creamos un cultivo
    //     Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
    //     //Fecha Inicio
    //     Date hoy = Date.today();
        
    //     //Fecha Fin
    //     Date manana = hoy.addDays(1);
        
    //     //Creamos una campaña agricola
    //     Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
    //     //Creamos dos productos
        
    //     //Creamos un par de productos
    //     Product2 producto1 = Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor);
        
    //     Product2 producto2 = Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor);
        
    //     List<PricebookEntry> pbsEntrys = [SELECT Id FROM PricebookEntry WHERE (Product2Id = :producto1.Id) OR (Product2Id = :producto2.Id)];
        
    //     if(pbsEntrys.size() == 0){
        
    //         List<Product2> productos = new List<Product2>(); 
            
    //         productos.add(producto1);
            
    //         productos.add(producto2);
            
    //         //Creamos un pricebook entry para cada producto
    //         List<PricebookEntry> pbes = Test_TestUtils.crearPricebookEntry( productos, listaPrecios);
        
    //     }
        
    //     //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
    //     Transaccion__c t1 = Test_TestUtils.crearTransaccion(rtDUP,'12345678', obtentor, cultivo, campanaAgricola, distribuidor, 'Creada', hoy);
        
    //     //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = False
    //     Transaccion__c t2 = Test_TestUtils.crearTransaccion(rtDUP,'87654321', obtentor, cultivo, campanaAgricola, distribuidor, 'Creada', hoy);
        
    //     //Creamos algunos items para las transacciones  
    //     List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
    //     items.add(Test_TestUtils.crearItemDeDUP(producto1, t1, 0, 'Uso Propio',null));
    //     items.add(Test_TestUtils.crearItemDeDUP(producto2, t1, 0, 'Uso Propio',null));
    
        
    //     //Recorremos los items de la listay actualizamos la cantidad
    //     //27/03/2014 - JL.IUDICA: cambio Cantidad__c por Cantidad_Declarada__c
    //     for(Item_de_DUP__c item : items){
    //         item.Cantidad_Declarada__c = 1;
    //     }
        
    //     //Actualizamos los items
    //     update items;
    
        
    // }
}