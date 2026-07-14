@isTest(SeeAllData=true)
private class TestPriorizaciones{

    static testMethod void testPriorizacion() {
        /**
         //Creamos una cuenta de tipo Obtentor
        Account obtentor = Test_TestUtils.crearObtentor();
    
        //Creamos un distribuidor
        Account productor = Test_TestUtils.crearProductor();
        
        List<Campana_Agricola__c> campanas = new List<Campana_Agricola__c>();
        
        Cultivo__c cultivo = new Cultivo__c();
        cultivo.Name = 'Test';
        cultivo.Densidad_de_Siembra__c = 5;
        insert cultivo;
    
        Campana_Agricola__c campana1 = new Campana_Agricola__c();
        campana1.Name = 'Campaña 1';
        campana1.Id_Externo__c = 'campana1';
        campana1.Ano__c = '2013';
        campana1.Cultivo__c = cultivo.Id;
        campana1.SKEY_CAMPANIA__c = Utils.getRandomLong(10);
        insert campana1;
        
        Campana_Agricola__c campana2 = new Campana_Agricola__c();
        campana2.Nombre_de_Campana_Anterior__c = campana1.ID;
        campana2.Name = 'Campaña 2';
        campana2.Id_Externo__c = 'campana2';
        campana2.Ano__c = '2014';
        campana2.Cultivo__c = cultivo.Id;
        campana2.Estado__c = 'Activa';
        campana2.SKEY_CAMPANIA__c = Utils.getRandomLong(10);
        insert campana2;
    
        campanas.add(campana2);
        
        Transaccion__c t = new Transaccion__c();
        t.Campana__c = campana1.ID;
        t.Name = 'DUP';
        t.Nombre_de_la_cuenta__c = productor.ID;
        t.Obtentor__c = obtentor.ID;
        t.Cultivo__c = cultivo.ID;
        t.Tipo_de_Cambio__c = 10;
        t.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        insert t;
        **/
        
        //Creamos los casos de Test
        
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
        
        List<Campana_Agricola__c> campanas = new List<Campana_Agricola__c>();
        
        //Creamos una campaña agricola
        Campana_Agricola__c ca1 = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        //Creamos la campaña agricola que le seguiria
        Campana_Agricola__c ca2 = Test_TestUtils.crearCampanaAgricola('2015', cultivo, hoy, manana, '2015 - Test');

        //Indicamos que ca1 es la anterios de ca2
        ca2.Nombre_de_Campana_Anterior__c = ca1.Id;

        //Actualizamos la BD
        update ca2;
        
        campanas.add(ca1);
        campanas.add(ca2);

        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG1', cultivo,  'Regalía Comercial', 2, obtentor);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, ca1, cultivo, 1, distribuidor, obtentor, 'TC');
        
        Test.startTest();

        BatchApexPriorizacion batchP = new BatchApexPriorizacion();
        Database.executeBatch(batchP, 100);

        //Iniciamos el Test del batch

        for(Integer i = 1 ; i < = 21 ; i++){

            //Creamos un batch con el groupNumber i
            BatchApexPriorizacionDUPSUpdate b = new BatchApexPriorizacionDUPSUpdate(100000, i, campanas);

            //Ejecutamos la query
            b.buildQuery();

        }
        
        for(Integer i = 1; i <= 4; i++){
            //Creamos un batch con el groupNumber i
            BatchApexPriorizacionCobranzasUpdate b = new BatchApexPriorizacionCobranzasUpdate(100000, i);
            
            //Ejecutamos la query
            b.buildQuery();
        }
        
        campanas.clear();
        campanas.add(ca2);
        
        for(Integer i = 1; i <= 4; i++){
            //Creamos un batch con el groupNumber i
            BatchApexPriorizacionVentasUpdate b = new BatchApexPriorizacionVentasUpdate(100000, i, campanas);
            
            //Ejecutamos la query
            b.buildQuery();
        }

        Test.stopTest();
    }
    
    
}