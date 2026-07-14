@IsTest
public class UploadItemDupExcelControllerTest {
    
    @TestSetup
    static void makeData(){

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

        Provincia__c prov = new Provincia__c();
        prov.Name = 'Test';
        insert prov;

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
        Campana_Agricola__c campanaAgricola1 = Test_TestUtils.crearCampanaAgricola('2013', cultivo, hoy, manana, '2013 - Test');
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola2 = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        //Seteamos la campaña anterior
        campanaAgricola2.Nombre_de_Campana_Anterior__c = campanaAgricola1.Id;
        
        //Actualizamos en la BD
        update campanaAgricola2;
        
        Lote__c lote = Test_TestUtils.crearLote(campanaAgricola1, cultivo, 'Basico');
        insert lote;

        //Creamos un par de productos
        List<Product2> productos = new List<Product2>();
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test3',null, 'NIDERA A 5509RG', cultivo,  'Regalía Comercial', 2, obtentor));

        List<Transaccion__c> trs = new List<Transaccion__c>();

        // Creamos Transacciones DUPS

        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        trs.add(Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola1, productor, 'Creada', hoy, false));
    
        trs[0].Z9_Cambio__c = true;
    
        insert trs;

    
        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();

        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        items.add(Test_TestUtils.crearItemDeDUP(productos[0], trs[0], 1000, 'Uso Propio',1,false, prov.Id));
    
        insert items;

        Configuracion_Carga_Dups_Excel__c settings = Configuracion_Carga_Dups_Excel__c.getOrgDefaults();
        settings.Categoria_Productos__c = 'Uso Propio';
        settings.Columna_Alta_Cuenta__c = 'ALTA CUENTA';
        settings.Columna_Alta_Item_DUP__c = 'ALTA ITEM DUP';
        settings.Columna_Alta_Transaccion__c = 'ALTA TRANSACCION';
        settings.Columna_CUIT_Remitente_Destinatario__c = 'CUIT REMITENTE O DESTINATARIO';
        settings.Columna_Egresos__c = 'EGRESOS (kg)';
        settings.Columna_Error_Alta_Cuenta__c = 'ERROR ALTA CUENTA';
        settings.Columna_Error_Alta_Item_DUP__c = 'ERROR ALTA ITEM DUP';
        settings.Columna_Error_Alta_Transaccion__c = 'ERROR ALTA TRANSACCION';
        settings.Columna_Error__c = 'ERRORES';
        settings.Columna_Ids__c = 'IDS';
        settings.Columna_Ingresos__c = 'INGRESOS (kg)';
        settings.Columna_Remitente_Destinatario__c = 'REMITENTE O DESTINATARIO';
        settings.Columna_Variedad_Producto__c = 'CULTIVAR';
        settings.Cultivo__c = cultivo.Id;
        settings.Dias_Vencimiento__c  = 30.0;
        settings.Familia_Productos__c = 'Regalía Extendida';
        settings.Item_de_Dup_Estado__c = 'Uso Propio';
        settings.Item_de_Dup_Tipo_de_Producto__c = 'ORL';
        settings.Item_de_Dup_Unidad_de_Medida_Declarada__c = 'Granel';
        settings.Lote_Tipo_de_Lote__c = 'Especial';
        settings.Lote_Tipo__c = 'Informe';
        settings.Tamano_Lote_Batch__c = 50.0;
        settings.Transaccion_Cultivo__c = cultivo.Id;
        settings.Transaccion_Estado__c = 'Respondida';
        settings.Transaccion_Tipo_de_Registro__c = Schema.SObjectType.Transaccion__c.getRecordTypeInfosByDeveloperName().get('DUP').getRecordTypeId();
        settings.Unidad_de_Medida_Productos__c = 'Granel';
        insert settings;

    }
    

    @IsTest
    static void testBatch(){
        
        List<Map<String,Object>> json = new List<Map<String,Object>>();

        json.add(new Map<String,Object>{
            'PRODUCTO' => 'Grano de Algodón',
            'FECHA DEL MOVIMIENTO' =>43739,
            'TIPO' =>2,
            'NUMERO' => '36741450',
            'CUIT REMITENTE O DESTINATARIO' => '30651205146',
            'REMITENTE O DESTINATARIO' => 'MARFRA SA',
            'CULTIVAR' => 'DP 1238 BGRR',
            'INGRESOS (kg)' => 28480,
            'EGRESOS (kg)' => 22740
        });

        Campana_Agricola__c cAgricola = [SELECT Id FROM Campana_Agricola__c LIMIT 1]; 

        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];

        Test.startTest();
        Database.executeBatch(new BatchApexProcessItemsDupsFromExcel(json,cAgricola.Id,productor.Id,'TEST'),BatchApexProcessItemsDupsFromExcel.BATCH_SIZE);
        Test.stopTest();
        
    }

    @IsTest
    static void testController(){

        List<Map<String,Object>> json = new List<Map<String,Object>>();

        json.add(new Map<String,Object>{
            'PRODUCTO' => 'Grano de Algodón',
            'FECHA DEL MOVIMIENTO' =>43739,
            'TIPO' =>2,
            'NUMERO' => '36741450',
            'CUIT REMITENTE O DESTINATARIO' => '30651205146',
            'REMITENTE O DESTINATARIO' => 'MARFRA SA',
            'CULTIVAR' => 'DP 1238 BGRR',
            'INGRESOS (kg)' => 28480,
            'EGRESOS (kg)' => 22740
        });

        Campana_Agricola__c cAgricola = [SELECT Id FROM Campana_Agricola__c LIMIT 1]; 

        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];

        Test.startTest();
        UploadItemDupExcelController.processFileRows(json,cAgricola.Id,productor.Id,'TEST');
        Test.stopTest();
        
    }

    @IsTest
    static void testInnerClasses(){

        Lote__c l = [SELECT Id FROM Lote__c];

        Campana_Agricola__c cAgricola = [SELECT Id FROM Campana_Agricola__c LIMIT 1]; 

        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];

        Account obtentor = [SELECT Id FROM Account WHERE Name = 'obtentor' LIMIT 1];

        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        Transaccion__c t = [SELECT Id FROM Transaccion__c LIMIT 1];

        Item_de_DUP__c item = [SELECT Id FROM Item_de_DUP__c LIMIT 1];

        BatchApexProcessItemsDupsFromExcel.createNewTransaction(l.Id, cAgricola.Id,obtentor.Id,productor.Id,productor.Id);
        BatchApexProcessItemsDupsFromExcel.createNewItemDeDUP(cAgricola.Id,productor.Id,product.Id,10,10);

        BatchApexProcessItemsDupsFromExcel.Transaccion decoratorT = new BatchApexProcessItemsDupsFromExcel.Transaccion(new Map<String,Object>{
            'PRODUCTO' => 'Grano de Algodón',
            'FECHA DEL MOVIMIENTO' =>43739,
            'TIPO' =>2,
            'NUMERO' => '36741450',
            'CUIT REMITENTE O DESTINATARIO' => '30651205146',
            'REMITENTE O DESTINATARIO' => 'MARFRA SA',
            'CULTIVAR' => 'DP 1238 BGRR',
            'INGRESOS (kg)' => 28480,
            'EGRESOS (kg)' => 22740
        });

        decoratorT.transacion = t;

        decoratorT.setErrors('Test');
        decoratorT.setRecordId(t.Id);

        BatchApexProcessItemsDupsFromExcel.Item decoratorItem = new BatchApexProcessItemsDupsFromExcel.Item(item,new Map<String,Object>{
            'PRODUCTO' => 'Grano de Algodón',
            'FECHA DEL MOVIMIENTO' =>43739,
            'TIPO' =>2,
            'NUMERO' => '36741450',
            'CUIT REMITENTE O DESTINATARIO' => '30651205146',
            'REMITENTE O DESTINATARIO' => 'MARFRA SA',
            'CULTIVAR' => 'DP 1238 BGRR',
            'INGRESOS (kg)' => 28480,
            'EGRESOS (kg)' => 22740
        });

        decoratorItem.setErrors('Test');
        decoratorItem.setRecordId(item.Id);

        BatchApexProcessItemsDupsFromExcel.ListHelper lHelper = new BatchApexProcessItemsDupsFromExcel.ListHelper();
        lHelper.clear();




    }

}