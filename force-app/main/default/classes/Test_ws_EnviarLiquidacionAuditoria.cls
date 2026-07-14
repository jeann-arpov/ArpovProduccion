@isTest
public with sharing class Test_ws_EnviarLiquidacionAuditoria{
    
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
        Pricebook2 listaPrecios = new Pricebook2(Id=Utils.getPricebook2Id());
        
        //Creamos datos de Test
        
        //RecordType que usamos en el Test
        Id rtAud = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');
        
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
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor);
        
        Product2 producto2 = Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor);
        
        //Verificamos si se ha creado un pricebookentry
        
        List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE (Product2Id = :producto1.Id) OR (Product2Id = :producto2.Id)];
        
        if(pbes.size() == 0){
        
            List<Product2> productos = new List<Product2>(); 
        
            productos.add(producto1);
        
            productos.add(producto2);
        
            //Creamos un pricebook entry para cada producto
            pbes = Test_TestUtils.crearPricebookEntry( productos, listaPrecios);
        
        }
        
        //Creamos una transaccion de tipo Auditoria
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtAud),'00000001', obtentor, cultivo, null, productor, 'Respondida', hoy);
        
        Provincia__c prov = new Provincia__c();

        prov.Name = 'Test';

        insert prov;

        //Creamos dos Items para la auditoria
        Item_Auditoria__c item1= Test_TestUtils.crearItemAuditoria(producto1, t1,  campanaAgricola, 'Irregular', 'Granel', 1, null, false);    
    
        Item_Auditoria__c item2= Test_TestUtils.crearItemAuditoria(producto2, t1,  campanaAgricola, 'Irregular', 'Granel', 1, null, false);    
        
        item1.Lugar_de_Siembra__c = prov.Id;
        item2.Lugar_de_Siembra__c = prov.Id;

        insert item1;

        insert item2;

        //Generamos una oportunidad y dos item de oportunidad (uno por cada item de la transaccion)
        Opportunity o1 =  Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', t1, 'FC');
        
        OpportunityLineItem opl1 = Test_TestUtils.crearOpportunityLineItem(o1, pbes.get(0), 1, 10, 10);
        
        OpportunityLineItem opl2 = Test_TestUtils.crearOpportunityLineItem(o1, pbes.get(1), 1, 10, 10);
        
        //Obtenemos los datos actualizados de la oportunidad
        List<Opportunity> ops = [SELECT Id, Amount FROM Opportunity WHERE Id = :o1.Id LIMIT 1];
        
        if(ops.size() > 0){
            
            //Obtenemos la oportunidad
            Opportunity op = ops.get(0); 
            
            //Llamamos al WS 
            String[] result = ws_EnviarLiquidacionAuditoria.enviar(op.Id);
            
            //Checkeamos el resultado
            System.AssertEquals(result[0],'true');
            
            //Volvemos a llamar al WS ahora para que se produzca un "error"
            result = ws_EnviarLiquidacionAuditoria.enviar(null);
            
            //Checkeamos el resultado
            System.AssertEquals(result[0],'false'); 
            
            //Eliminamosla oportunidad
            delete op;
            
            //Volvemos a llamar al WS ahora para que se produzca un "error" por el Id no va a existir
            result = ws_EnviarLiquidacionAuditoria.enviar(op.Id);
            
            //Checkeamos el resultado
            System.AssertEquals(result[0],'false'); 
        }
    }   
    
}