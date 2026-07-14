/**
* @author Maximo Martinez
* @date 8/30/2014
* @description Clase de Test de la Clase AgregaTipoCambio
*/
@isTest
public class Test_AgregaTipoCambio{
    
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


    /**
    * @description Método de Test
    */
    public static testmethod void testAgragarTipoCambioItemsDUP(){
        Variedad__c var = new Variedad__c(Name = 'test');
        insert var;
    
      //Creamos algunos datos de test
       //Creamos datos de Test
        
        //RecordType que usamos en el Test 
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        //Creamos una localidad
        Localidad__c localidad = new Localidad__c();
        
        //Seteamos algunos datos
        localidad.Zona_Bolsa_Cereales__c = 'Test';
        
        //Insertamos en la Base de Datos
        insert localidad;
        
        
        //Creamos una cuenta de tipo Obtentor
        Account obtentor = Test_TestUtils.crearObtentor();
    
   
        //Creamos un distribuidor
        Account productor = Test_TestUtils.crearDistribuidor();
        
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
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
        
        
         //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = False
        Transaccion__c t2 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000002', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        
        //Creamos algunos items de dup
        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(0), t1, 0, 'Uso Propio',null));
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(1), t1, 0, 'Uso Propio',null));

        
        AgregaTipoCambio.agregarTipoCambio(items);
          
        
    }
    
    public static testmethod void testAgragarTipoCambioItemsAuditoria(){
        Variedad__c var = new Variedad__c(Name = 'test');
        insert var;
    
        //Creamos los Datos Necesarios
        
        //Creamos datos de Test
        
        //RecordType que usamos en el Test
        Id rtAud = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');
        
         //Creamos una cuenta de tipo Obtentor
        Account obtentor = Test_TestUtils.crearObtentor();
    
   
        //Creamos un distribuidor
        Account productor = Test_TestUtils.crearDistribuidor();
        
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
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);
        
        Product2 producto2 = Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);
        
        //Creamos una transaccion de tipo Auditoria
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtAud),'00000001', obtentor, cultivo, null, productor, 'Respondida', hoy);
        
        List<Item_Auditoria__c> items = new List<Item_Auditoria__c>();

        Provincia__c prov = new Provincia__c();

        prov.Name = 'Test';

        insert prov;
        
        //Creamos dos Items para la auditoria
        items.add(Test_TestUtils.crearItemAuditoria(producto1, t1,  campanaAgricola, 'Irregular', 'Granel', 1, 1, false));    
    
        items.add(Test_TestUtils.crearItemAuditoria(producto2, t1,  campanaAgricola, 'Irregular', 'Granel', 1, 1, false));  
        
        items.get(0).Lugar_de_Siembra__c = prov.Id;
        items.get(1).Lugar_de_Siembra__c = prov.Id;

        insert items;

        //Agregamos el tipo de cambio 
        AgregaTipoCambio.agregarTipoCambio(items); 
     
    }
}