@isTest
public class Test_ws_CrearNotaDeCredito{
    
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

     public static testmethod void test(){
         
        //Creamos los Datos Necesarios
        
        //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());
        
        //Seteamos variables para almacenar los recordtypes que necesitaremos
        RecordType rtDUP = null;
        RecordType rtAud = null;
        RecordType rtObtentor = null;
        
        //Obtenemos los RecordType que necesitamos
        for( RecordType recordType : [SELECT DeveloperName FROM RecordType WHERE SObjectType IN ('Transaccion__c','Account')]){
            if(recordType.DeveloperName == 'DUP'){
                rtDUP = recordType;
            }else if( recordType.DeveloperName == 'Auditorias' ){
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
        
        Account distribuidor = Test_TestUtils.crearDistribuidor();
        
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
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor);
        
        Product2 producto2= Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor);
        
        productos.add(producto1);
        
        productos.add(producto2);
        
        List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE (Product2Id = :producto1.Id) OR (Product2Id = :producto2.Id)];
        
        if(pbes.size() == 0){
        
            //Creamos un pricebook entry para cada producto
            pbes = Test_TestUtils.crearPricebookEntry( productos, listaPrecios);
        
        }
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(rtDUP,'00000001', obtentor, cultivo, campanaAgricola, distribuidor, 'Respondida', hoy);
        
        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        Item_de_DUP__c item1 = Test_TestUtils.crearItemDeDUP(productos.get(0), t1, 2, 'Uso Propio',1);
        Item_de_DUP__c item2 = Test_TestUtils.crearItemDeDUP(productos.get(1), t1, 2, 'Uso Propio',1);
        
        
        //Creamos una Opportunidad para la Transaccion 1
        Opportunity oportunidad1 = Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', t1, 'FC');
        
        //Creamos una Linea de Oportunidad para Cada Opportunidad
        // 27/03/2014 - JL.IUDICA: cambio Cantidad__c por Cantidad_de_Facturacion__c
        OpportunityLineItem oli1 = Test_TestUtils.crearOpportunityLineItem(oportunidad1, pbes.get(0), 100, 2, (Double)item1.Tipo_de_Cambio__c);
        
        
        OpportunityLineItem oli2 = Test_TestUtils.crearOpportunityLineItem(oportunidad1, pbes.get(1), 200, 2, (Double)item2.Tipo_de_Cambio__c);
        
        
        //Pasamos las transacciones a Estado Pedido de Facturación
        t1.Estado__c = 'Pedido de Facturación';
        
        //update t1;
        
        //A ambas oportunidades le agregamos el Número de Comprobante
        
        oportunidad1.N_de_Comprobante__c = '123456';
        
        update oportunidad1;
        
        //Llamamos al Web Services para que nos cree un Nota de Credito para la Oportunidad 1
        String idNotaCredito1 = ws_CrearNotaDeCredito.crearNotaDeCredito(oportunidad1.Id);
        
        //Comprobamos que el Id que se devuelve no es cadena vacia 
        System.Assert(idNotaCredito1 != ''); 
     }
    
}