/**
* @author Maximo Martinez
* @date 8/30/2014
* @description Clase de Test de la Clase DeclaracionesOnlineIndexController
*/

@isTest
public class Test_DeclaracionesOnlineHomeCtrl{
    
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
    public static testmethod void test(){
        
        //Creamos datos de Test
        
        //RecordType que usamos en el Test
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
      
        //Creamos una cuenta de tipo Obtentor
        Account obtentor = Test_TestUtils.crearObtentor();
    
   
        //Creamos un distribuidor
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
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor));
        
        productos.add(Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor));
        
        
         //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = False
        Transaccion__c t2 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000002', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
    
        
        //Tenemos un productor con transacciones DUP
        
        //Obtenemos el token del productor
        String token = Utils.createToken(productor.Id);
        
        //Seteamos el parametro de la pagina actual
        ApexPages.currentPage().getParameters().put('token',token);
        
        //Ahora testeamos el controller
        
        //Instanciamos el controlador standard
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(productor);
        
        //Instanciamos el controlador custom
        DeclaracionesOnlineIndexController ctrl = new DeclaracionesOnlineIndexController(stdCtrl);
        
        //Obtenemos las transacciones
        List<DeclaracionesOnlineIndexController.Transaccion> transacciones = ctrl.getTransacciones();
        
        //Checkeamos que son solamente dos transacciones
        //System.AssertEquals(transacciones.size(),2);
        
        //Acciones para testear la paginacion
        
        //Primer página
        ctrl.firstPage();
        
        //Ultima pagina
        ctrl.lastPage();
        
        //Página Siguiente
        ctrl.next();
        
        //Pagina anterior
        ctrl.prev();
    }
    
}