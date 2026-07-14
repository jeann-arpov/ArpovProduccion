/**
* @author Maximo Martinez
* @date 04/06/2014
* @description Clase encargada de testear la logica de casos
*/
@isTest
public class Test_UtilsCasos{

    @TestSetup 
    static void setup(){
        Test_TestUtils.disableFlows();
        insert new Variedad__c (Name = 'Test');

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
    
    /**
    * @author Maximo Martinez
    * @date 04/06/2014
    * @description Metodo encargado de testear la creacion de casos de venta
    */
    public static testmethod void testGeneracionCasosVenta(){
        
        //Creamos datos de Test
        
        //Creamos los datos de prueba
         
        Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account distribuidor = Test_TestUtils.crearDistribuidor();
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Agregamos un nombre
        cultivo.Name = 'Cultivo Test';
        
        //Actualizamos la Base de Datos
        update cultivo;
        
         //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        Variedad__C var = [select id from Variedad__c];

        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest',null, 'NIDERA A 5509RG', cultivo,  'Regalía Comercial', 2, obtentor, var.id, true);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor, var.id, true);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');
        
        //Esto deberia generar un caso, asi que ahora buscaremos en la BD si es que se creo un caso aosciado a esa venta
        Integer count = [SELECT COUNT() FROM Case WHERE Venta__c = :venta.Id];
        
        //System.AssertEquals(count,1);
                
    } 

    /**
    * @author Maximo Martinez
    * @date 04/06/2014
    * @description Metodo encargado de testear la creacion de casos de DUP
    */
    public static testmethod void testEliminacionCasosDUP(){
        
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

        Variedad__C var = [select id from Variedad__c];
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        
        //Creamos un item de DUP    
        Item_de_DUP__c item = Test_TestUtils.crearItemDeDUP(productos.get(0), t, 2, 'Uso Propio',1);
        
        //Llamamos al metodo que crea casos
        UtilsCasos.crearCasosDups(new List<Item_de_DUP__c>{item});

        //Llamamos al caso que elimina item 
        UtilsCasos.eliminarCasosDUPS(new List<Item_de_DUP__c>{item});

        
    }
    
    /**
    * @author Maximo Martinez
    * @date 04/06/2014
    * @description Metodo encargado de testear la creacion de casos de DUP
    */
    public static testmethod void testGeneracionCasosDUP(){
        
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

        Variedad__C var = [select id from Variedad__c];
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        
        //Creamos un item de DUP    
        Item_de_DUP__c item = Test_TestUtils.crearItemDeDUP(productos.get(0), t, 2, 'Uso Propio',1);
        
        //Llamamos al metodo que crea casos
        UtilsCasos.crearCasosDups(new List<Item_de_DUP__c>{item});
        
    }
    
    /**
    * @author Maximo Martinez
    * @date 04/06/2014
    * @description Metodo encargado de testear la creacion de casos de DUP
    */
    public static testmethod void testGeneracionCasosFactura(){
        
          //Creamos los Datos Necesarios
        
        //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());
        
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

        Variedad__C var = [select id from Variedad__c];
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001',obtentor , cultivo, campanaAgricola, productor, 'Respondida', hoy);
      
        //Creamos una Opportunidad para la Transaccion 1
        Opportunity oportunidad = Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', t, 'FC');
        
        //Agregamos el Número de Comprobante
        oportunidad.N_de_Comprobante__c = '123456';
        oportunidad.Fecha_Emision_Comprobante__c = Date.today();

        update oportunidad;
        
        //Esto deberia generar un caso, asi que ahora buscaremos en la BD si es que se creo un caso asociado a esa factura
        Integer count = [SELECT COUNT() FROM Case WHERE Factura__c = :oportunidad.Id];
        
        System.Debug(LoggingLevel.INFO,[SELECT Id,CaseNumber,RecordTypeId,Subject FROM Case WHERE Factura__c = :oportunidad.Id]);
        
        //System.AssertEquals(count,1);
    }
    
    /**
    * @author Maximo Martinez
    * @date 04/06/2014
    * @description Metodo encargado de testear la creacion de casos de venta
    */
    public static testmethod void testCerrarCasosVenta(){
        
         //Creamos datos de Test
        
        //Creamos los datos de prueba
        
        Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account distribuidor = Test_TestUtils.crearDistribuidor();
        
        Account productor = Test_TestUtils.crearProductor();
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Agregamos un nombre
        cultivo.Name = 'Cultivo Test';
        
        //Actualizamos la Base de Datos
        update cultivo;
        
         //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        Variedad__C var = [select id from Variedad__c];
        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest',null, 'NIDERA A 5509RG', cultivo,  'Regalía Comercial', 2, obtentor, var.id, true);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        p1.Unidad_de_Medida__c = '15';
        
        //Actualizamos la Base De Datos
        update p1;
      
        //Creamos una venta
        Venta__c venta1 = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');
        
        //Esto deberia generar un caso, asi que ahora buscaremos en la BD si es que se creo un caso aosciado a esa venta
        Integer count = [SELECT COUNT() FROM Case WHERE Venta__c = :venta1.Id];
        
        //System.AssertEquals(count,1);
        
        //Ahora generamos una venta, donde el distribuidor vente este producto a un productor
        Venta__c venta2 = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1,  distribuidor, productor, 'Venta');

        //Corremos el batch
        Test.startTest();
        Database.executeBatch(new BatchApexCierraCasosVentas());
        Test.stopTest();
        
        //Esto deberia generar cerrar el caso, asi que ahora buscaremos en la BD si es que se creo un caso aosciado a esa venta
        count = [SELECT COUNT() FROM Case WHERE Venta__c = :venta1.Id AND Status = 'Cerrado'];
        
        //System.AssertEquals(count,1);
                
    } 
    
    
    /**
    * @author Maximo Martinez
    * @date 04/06/2014
    * @description Metodo encargado de testear el cierre de un caso DUP
    */
    public static testmethod void testCerrarCasosDUP(){
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

        Variedad__C var = [select id from Variedad__c];
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        
        //Esto deberia generar un caso, asi que ahora buscaremos en la BD si es que se creo un caso aosciado a esa transaccion
        Integer count = [SELECT COUNT() FROM Case WHERE DUP__c = :t.Id];
        
        System.Debug(LoggingLevel.INFO, [SELECT Id,Subject,Status FROM Case WHERE DUP__c = :t.Id AND Status = 'Nuevo']);
        
        //System.AssertEquals(count,1);
        
        //Creamos un Item de DUP
        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(0), t, 0, 'Uso Propio',null));
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(1), t, 0, 'Uso Propio',null));
        UtilsCasos.cerrarCasosFromDups(new List<Transaccion__c> {t});
    }
    
    /**
    * @author Maximo Martinez
    * @date 03/01/2014
    * @description Metodo encargado de testear la creacion de casos ventas
    */
     public static testmethod void testcrearCasosVentas(){
         
          //Creamos datos de Test
        
        //Creamos los datos de prueba
        Id rtVenta = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Ventas');
        
        Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account distribuidor = Test_TestUtils.crearDistribuidor();
       
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Agregamos un nombre
        cultivo.Name = 'Cultivo Test';
        
        //Actualizamos la Base de Datos
        update cultivo;
        
         //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        Variedad__C var = [select id from Variedad__c];
        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest',null, 'NIDERA A 5509RG', cultivo,  'Regalía Comercial', 2, obtentor, var.id, true);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor, var.id, true);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');
        
        // UtilsCasos.crearCasosFromVentas(new List<Venta__c>{venta});
         
     }
    
    /**
    * @author Maximo Martinez
    * @date 04/06/2014
    * @description Metodo encargado de testear la agrupacion de casos ventas
    */
     public static testmethod void testAgrupaCasosVentas(){
        
        //Creamos datos de Test
        
        //Creamos los datos de prueba
        Id rtVenta = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Ventas');
        
        Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account distribuidor = Test_TestUtils.crearDistribuidor();
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Agregamos un nombre
        cultivo.Name = 'Cultivo Test';
        
        //Actualizamos la Base de Datos
        update cultivo;
        
         //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        Variedad__C var = [select id from Variedad__c];
        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest',null, 'NIDERA A 5509RG', cultivo,  'Regalía Comercial', 2, obtentor, var.id, true);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor, var.id, true);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');
              
        //Creamos un caso de tipo Venta
        Case caso = new Case();
        
        caso.AccountId = obtentor.Id;
        caso.RecordTypeId = rtVenta;
        
        insert caso;
        
        UtilsCasos.agruparCasosVentas(new List<Case>{caso});
        
        //Checkeamos resultados
        caso = [SELECT Id,ParentId FROM Case WHERE Id = :caso.Id];
        
        System.Debug(LoggingLevel.INFO,caso);
        
    }


    /**
    * @author Maximo Martinez
    * @date 28/10/2014
    * @description Metodo encargado de testear la asignacion de un caso a legales
    */

    public static testmethod void testAsignarCasoFactiraALegales(){

          //Creamos los Datos Necesarios
        
        //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());
        
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
        
        Variedad__C var = [select id from Variedad__c];

        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001',obtentor , cultivo, campanaAgricola, productor, 'Respondida', hoy);
      
        //Creamos una Opportunidad para la Transaccion 1
        Opportunity oportunidad = Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', t, 'FC');
        
        //Agregamos el Número de Comprobante
        oportunidad.N_de_Comprobante__c = '123456';
        oportunidad.Fecha_Emision_Comprobante__c = Date.today();
        
        update oportunidad;
        
        //Esto deberia generar un caso, asi que ahora buscaremos en la BD si es que se creo un caso asociado a esa factura
        Integer count = [SELECT COUNT() FROM Case WHERE Factura__c = :oportunidad.Id];

        if(count > 0)
            //Pasamos el id de la opp al metodo
            UtilsCasos.setOwnerToLegalesQueue(new Set<Id>{oportunidad.Id}); 
        

    }

    @isTest
    static void cerrarCasosFromFactura_test(){
        Opportunity oportunidad = new Opportunity(Name = 'Test', StageName = 'Test', CloseDate = Date.today());
        insert oportunidad;

        Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');

        Case cs = new Case(Factura__c = oportunidad.Id, RecordTypeId = rtId);
        insert cs;

        test.startTest();
        UtilsCasos.cerrarCasosFromFactura(new set<Id> {oportunidad.Id});
        UtilsCasos.setOwnerToLegalesQueue(new set<Id> {oportunidad.Id});

        Id rtId2 = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');

        Case cspadre = new Case(Factura__c = oportunidad.Id, RecordTypeId = rtId2, Status = 'Cerrado');
        insert cspadre;
        Case cshijo = new Case(Factura__c = oportunidad.Id, RecordTypeId = rtId2, ParentId = cspadre.Id);
        insert cshijo;

        UtilsCasos.abrirCasosPadres(new List<Case> {cshijo});
        test.stopTest();

        cs = [SELECT Id, Status, ParentId, RecordTypeId FROM Case WHERE Id = :cs.Id];
        Assert.areEqual('Cerrado', cs.Status);
    }

     @isTest
    static void cerrarCasosFromPadres_test(){
        Opportunity oportunidad = new Opportunity(Name = 'Test', StageName = 'Test', CloseDate = Date.today());
        insert oportunidad;

        Id rtId2 = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Ventas');

        Case cspadre = new Case(Factura__c = oportunidad.Id, RecordTypeId = rtId2);
        insert cspadre;
        Case cshijo = new Case(Factura__c = oportunidad.Id, RecordTypeId = rtId2, ParentId = cspadre.Id, Status = 'Cerrado');
        insert cshijo;

        test.startTest();

        UtilsCasos.cerrarCasosPadres(new List<Case> {cshijo});
        test.stopTest();
    }
   
    public static testmethod void testCerrarCasosVentas(){
         
          //Creamos datos de Test
        
        //Creamos los datos de prueba
        Id rtVenta = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Ventas');
        
        Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account distribuidor = Test_TestUtils.crearDistribuidor();
       
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Agregamos un nombre
        cultivo.Name = 'Cultivo Test';
        
        //Actualizamos la Base de Datos
        update cultivo;
        
         //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        Variedad__C var = [select id from Variedad__c];
        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest',null, 'NIDERA A 5509RG', cultivo,  'Regalía Comercial', 2, obtentor, var.id, true);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor, var.id, true);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, distribuidor, obtentor, 'C');
        Venta__c venta2 = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');

        Case c1 = new Case(RecordTypeId = rtVenta, Venta__c = venta.Id, AccountId = distribuidor.Id);
        insert c1;
        Case c2 = new Case(RecordTypeId = rtVenta, Venta__c = venta2.Id, AccountId = obtentor.Id);
        insert c2;


        
        UtilsCasos.cerrarCasosFromVentas(new List<Venta__c>{venta, venta2});
        
    }
}