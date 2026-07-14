@isTest
public class Test_BatchApexGeneracionFacturas{


    @TestSetup 
    static void setup(){
        Test_TestUtils.disableFlows();
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
         Variedad__c var = new Variedad__c(Name = 'test var');
         insert var;
         
        //Creamos los datos necesarios
        
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
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'ProductoTest 1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);
        
        Product2 producto2 = Test_TestUtils.crearProducto(true,'ProductoTest 2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);
      
        List<PricebookEntry> pbsEntrys = [SELECT Id FROM PricebookEntry WHERE (Product2Id = :producto1.Id) OR (Product2Id = :producto2.Id)];
        
        if(pbsEntrys.size() == 0){
        
            List<Product2> productos = new List<Product2>(); 
        
            productos.add(producto1);
        
            productos.add(producto2);
        
            //Creamos un pricebook entry para cada producto
            List<PricebookEntry> pbes = Test_TestUtils.crearPricebookEntry( productos, listaPrecios);
        
        }
        
        
        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(rtDUP,'00000001', obtentor, cultivo, campanaAgricola, distribuidor, 'Creada', hoy);
        
        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        Item_de_DUP__c item1 = Test_TestUtils.crearItemDeDUP(producto1, t1, 2, 'Uso Propio',1,false);
        Item_de_DUP__c item2 = Test_TestUtils.crearItemDeDUP(producto2, t1, null, 'No Informada',1, false);

        insert new List<Item_de_DUP__c>{item1,item2};
        
        System.assertEquals(1,[SELECT COUNT() FROM Item_de_DUP__c WHERE Estado__c = 'No Informada']);

        System.assertEquals([SELECT Estado__c FROM Transaccion__c WHERE Id = :t1.Id AND Z9_Lineas_No_Informadas__c = 1 AND Z9_Lineas_Totales_DUP__c = 2].Estado__c,'Respondida Parcialmente');
        
        System.assertEquals(1,[SELECT COUNT() FROM Transaccion__c WHERE ((RecordType.DeveloperName = 'Auditorias' AND Estado__c = 'Completa') OR (RecordType.DeveloperName = 'DUP' AND (Estado__c = 'Respondida' OR Estado__c = 'Respondida Parcialmente') AND (Respondida_via_Minisitio__c = false OR (Respondida_via_Minisitio__c = true AND Resultado_Validacion_Analista__c = 'Positiva')))) AND  Factura__c = null AND Subestado__c IN ('POSITIVA','NEGATIVA')  AND No_Facturar__c = false]);

        Destinatarios_Errores_Batchs__c destinatario = new Destinatarios_Errores_Batchs__c();

        destinatario.Name = 'Test';
        destinatario.Email__c = 'test@test.com';
        insert destinatario;

        Test.startTest();
        
        BatchApexGeneracionFacturas b = new BatchApexGeneracionFacturas(); 
        b.errors.add('Test');
        database.executebatch(b);
        
        Test.stopTest();
        
     }
    
}