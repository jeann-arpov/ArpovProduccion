/**
* @author Maximo Martinez
* @date 8/30/2014
* @description Clase de Test de la Clase DOABMDUPController
*/
@isTest
public class Test_DeclaracionesOnlineABController{
    
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

        Provincia__c prov = new Provincia__c();
        prov.Name = 'Test';
        insert prov;

        Localidad__c loc = new Localidad__c();
        loc.Provincia__c = prov.Id;
        loc.Name = 'Test';
        insert loc;
        
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
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor));
        
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy, false);
        
        t1.Provincia__c = prov.Id;

        insert t1;

        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = False
        Transaccion__c t2 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000002', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy);
        
        //Creamos algunos items de dup
        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(0), t1, 0, 'Uso Propio',null));
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(1), t1, 0, 'Uso Propio',null));
        

        //Tenemos un productor con transacciones DUP e items de dupahora testeamos el controllador
        
        //Obtenemos el token del productor
        String token = Utils.createToken(t1.Id);
        
        //Seteamos el parametro de la pagina actual
        ApexPages.currentPage().getParameters().put('token',token);
        
        //Instanciamos un controladore standard  
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(t1);
        
        //Instanciamos el controlador custom
        DOABMDUPController ctrl = new DOABMDUPController(stdCtrl);
        
        //Obtenemos los obtentores (seran todos los cargados en el sitio)
        List<SelectOption> obtentores = ctrl.getObtentores();
        
        //Obtenemos la cantidad de obtentores en el sitio
        //AggregateResult cantObtentores = [SELECT Count(Id) Cantidad FROM Account WHERE RecordTypeId = :rtObtentor];
        
        //Deberia coincidir la cantidad de obtentores, (restamos la opcion de ninguno)
        //System.AssertEquals(Integer.valueOf(cantObtentores.get('Cantidad')),obtentores.size()-1);
        
        //Obtenemos los cultivo (seran todos los cargados en el sitio)
        List<SelectOption> cultivos = ctrl.getCultivos();
        
        //Obtenemos la cantidad de cultivos en el sitio
        //AggregateResult cantCultivos = [SELECT COUNT(Id) Cantidad FROM Cultivo__c];
        
        //Deberia coincidir la cantidad de cultivos, (restamos la opcion de ninguno)
        //System.AssertEquals(Integer.valueOf(cantCultivos.get('Cantidad')),cultivos.size()-1);
        
        //Obtenemos las opciones de campaña
        List<SelectOption> campanas = ctrl.getCampanas();
        
        System.Debug(LoggingLevel.INFO,campanas);
        
        //Deberiamos tener solo dos opciones Ninguna y la Campaña que creamos
        //System.AssertEquals(campanas.size(),2);
        
        //Obtenemos los productos
        List<SelectOption> pr = ctrl.getProductos();
        
        //Deberiamos tener solo los dos productos que creamos
        //System.AssertEquals(pr.size(),3);
        
        //Hacemos el primer grabado para pasar a la etapa de confirmacion
        ctrl.grabar();
        
        //Obtenemos los item de dup
        List<DOABMDUPController.WrapperDup> its = ctrl.items;
        
        //Obtenemos los item de confirmacion
        List<DOABMDUPController.WrapperDup> itsC = ctrl.itemsConfirmacion;
        
        //Seteamos la misma cantidad de los items a los items de confirmacion
        for(Integer i = 0;i < its.size() ; i++){
            
            itsC[i].item.Cantidad_Declarada__c = its[i].item.Cantidad_Declarada__c;
            
        }
        
        //Grabamos
        ctrl.grabarConfirmacion();
        
        //Creamos una nueva variedad
        ctrl.agregarVariedad();
        
        // Testeamos si un producto tiene que validar hectareas o no
        DOABMDUPController.isProductHectarea(productos.get(0).Id); 


        
        ctrl.getLocalidades();
        
        ctrl.setIdLocalidad(loc.Id);

        ctrl.getIdLocalidad();

    }
    
}