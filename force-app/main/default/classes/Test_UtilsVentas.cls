/**
* @author Maximo Martinez
* @date 28/07/2014
* @description Clase encargada de testear la clase UtilsVentas
*/
@isTest
private class Test_UtilsVentas {

    @TestSetup
    static void makeData(){
        Comportamiento_Segun_Rol_Ventas__c compor = new Comportamiento_Segun_Rol_Ventas__c(
            Tipo_de_Producto__c = 'Regalía Comercial',
            Categoria__c = 'Primera Multiplicación',
            Rol_Destinatario__c = 'Distribuidor',
            Rol_Originante__c = 'Distribuidor',
            Name = '10'
        );

        insert compor;
    }

    /**
    * @author Maximo Martinez
    * @date 16/10/2014
    * @description Metodo encargado de testear el metodo CalcularSaldoTotal
    */
    @isTest static void testCalcularSaldoTotal(){

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
        Campana_Agricola__c ca1 = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        //Creamos la campaña agricola que le seguiria
        Campana_Agricola__c ca2 = Test_TestUtils.crearCampanaAgricola('2015', cultivo, hoy, manana, '2015 - Test');

        //Indicamos que ca1 es la anterios de ca2
        ca2.Nombre_de_Campana_Anterior__c = ca1.Id;

        //Actualizamos la BD
        update ca2;

        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG1', cultivo,  'Regalía Comercial', 2, obtentor);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, ca1, cultivo, 1, distribuidor, obtentor, 'C');

        UtilsVentas.calcularSaldoTotal(new Set<String>{distribuidor.Id}, ca1.Id);

    }
    
    /**
    * @author Maximo Martinez
    * @date 16/10/2014
    * @description Metodo encargado de testear el metodo eliminarVentasTipoTRA
    */
    @isTest static void testGenerarVentasTipoTRC(){
        
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
        
        //Creamos una campaña agricola
        Campana_Agricola__c ca1 = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        //Creamos la campaña agricola que le seguiria
        Campana_Agricola__c ca2 = Test_TestUtils.crearCampanaAgricola('2015', cultivo, hoy, manana, '2015 - Test');

        //Indicamos que ca1 es la anterios de ca2
        ca2.Nombre_de_Campana_Anterior__c = ca1.Id;

        //Actualizamos la BD
        update ca2;

        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG6', cultivo,  'Regalía Comercial', 2, obtentor, false);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        insert p1;

        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG7', cultivo,  'Semilla Fiscalizada', 2, obtentor, false);
        
        //Seteamos la categoria del producto 
        p2.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        
        insert p2;
            
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, ca1, cultivo, 1,obtentor, distribuidor,'C');
        
        //ejecutamos el metodo
        System.assertEquals(1, [SELECT COUNT() FROM Venta__c WHERE Tipo_de_Venta__c = 'TRC']);
        
    }

    /**
    * @author Maximo Martinez
    * @date 16/10/2014
    * @description Metodo encargado de testear el metodo eliminarVentasTipoTRA
    */
    @isTest static void testGenerarVentasTipoRCA(){
       
         //Creamos los casos de Test
        
        //Creamos los datos de prueba

        Id rtDistribuidor = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Distribuidor');
        Id rtObtentor = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');
        Id rtComercio =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Comercio');
         
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
        Campana_Agricola__c ca1 = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        //Creamos la campaña agricola que le seguiria
        Campana_Agricola__c ca2 = Test_TestUtils.crearCampanaAgricola('2015', cultivo, hoy, manana, '2015 - Test');

        //Indicamos que ca1 es la anterios de ca2
        ca2.Nombre_de_Campana_Anterior__c = ca1.Id;

        //Actualizamos la BD
        update ca2;

        List<Product2> productos = new List<Product2>();

        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG10', cultivo,  'Regalía Comercial', 2, obtentor, false);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Auditada';
        
        // //Actualizamos la Base De Datos
        insert p1;

        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG11', cultivo,  'Semilla Fiscalizada', 2, obtentor, false);
        
        //Seteamos la categoria del producto 
        p2.Categoria__c = 'Primera Multiplicación';
        
        // //Actualizamos la Base De Datos
        
        insert p2;

        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, ca1, cultivo, 1, obtentor, distribuidor, 'C');
        
        System.debug(LoggingLevel.WARN, [SELECT Id, Originante__r.RecordType.Name, Destinatario__r.RecordType.Name, Producto__r.Id, Producto__r.Family, Tipo_de_Venta__c, Producto__r.Unidad_de_Medida__c, Producto__r.Categoria__c FROM Venta__c WHERE Id = :venta.Id]);
        
        System.debug(LoggingLevel.WARN, [SELECT Family FROM Product2 WHERE Id = :p1.Id]);

        System.debug(LoggingLevel.WARN,rtDistribuidor);
        System.debug(LoggingLevel.WARN,rtObtentor);

        System.debug(LoggingLevel.WARN, [SELECT Name FROM RecordType WHERE Id = :obtentor.RecordTypeId]);
        System.debug(LoggingLevel.WARN, [SELECT Name FROM RecordType WHERE Id = :distribuidor.RecordTypeId]);

        System.assertEquals(1, [SELECT COUNT() FROM Venta__c WHERE Originante__r.RecordTypeId = :rtObtentor AND (Destinatario__r.RecordTypeId = :rtComercio OR Destinatario__r.RecordTypeId = :rtDistribuidor) AND Producto__r.Family = 'Regalía Comercial' AND Tipo_de_Venta__c = 'C' AND Id = :venta.Id]);

        // Revisamos resultados
        System.assertEquals(1, [SELECT COUNT() FROM Venta__c WHERE Tipo_de_Venta__c = 'RCA' AND Categoria__c = 'Auditada']);
        //System.assertEquals(1, [SELECT COUNT() FROM Venta__c WHERE Tipo_de_Venta__c = 'RCA' AND Categoria__c = 'Primera Multiplicación']);

    }

    /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo encargado de testear el metodo eliminarVentasTipoCA
    */   
    @isTest static void testEliminarVentasTipoCA() {

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
        
        //Creamos una campaña agricola
        Campana_Agricola__c ca1 = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        //Creamos la campaña agricola que le seguiria
        Campana_Agricola__c ca2 = Test_TestUtils.crearCampanaAgricola('2015', cultivo, hoy, manana, '2015 - Test');

        //Indicamos que ca1 es la anterios de ca2
        ca2.Nombre_de_Campana_Anterior__c = ca1.Id;

        //Actualizamos la BD
        update ca2;

        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG1', cultivo,  'Regalía Comercial', 2, obtentor);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, ca1, cultivo, 1, distribuidor, obtentor, 'TC');
        
        //ejecutamos el metodo
        UtilsVentas.eliminarVentasCA(new List<Venta__c>{venta});

    }
    
    /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo encargado de testear el metodo generarVentasTipoCA
    */   
    @isTest static void testGenerarVentasTipoCA() {

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
        
        //Creamos una campaña agricola
        Campana_Agricola__c ca1 = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        //Creamos la campaña agricola que le seguiria
        Campana_Agricola__c ca2 = Test_TestUtils.crearCampanaAgricola('2015', cultivo, hoy, manana, '2015 - Test');

        //Indicamos que ca1 es la anterios de ca2
        ca2.Nombre_de_Campana_Anterior__c = ca1.Id;

        //Actualizamos la BD
        update ca2;

        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG1', cultivo,  'Regalía Comercial', 2, obtentor);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, ca1, cultivo, 1, distribuidor, obtentor, 'TC');
        
        //ejecutamos el metodo
        UtilsVentas.generarVentasTipoCA(new List<Venta__c>{venta});

    }

    @isTest static void testSetTipoVenta() {

        //Creamos los casos de Test
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
        
        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG1', cultivo,  'Regalía Comercial', 2, obtentor);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');
        
        UtilsVentas.setTipoDeVenta(new List<Venta__c>{venta});
    }
    
    @isTest static void testDeleteList() {

        //Creamos los casos de Test
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
        
        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG1', cultivo,  'Regalía Comercial', 2, obtentor);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');
        
        UtilsVentas.deleteList(new List<Venta__c>{venta});

    }


    @isTest static void testInsertPartialList() {

        //Creamos los casos de Test
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
        
        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG1', cultivo,  'Regalía Comercial', 2, obtentor);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');
        
        UtilsVentas.insertPartialList(new List<Venta__c>{venta});

    }

    @isTest static void testAgregaOrigen() {

        //Creamos los casos de Test
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
        
        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG1', cultivo,  'Regalía Comercial', 2, obtentor);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');

        UtilsVentas.agregaOrigen(new List<Venta__c>{venta});

    }
}