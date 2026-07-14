/**
* @author Maximo Martinez
* @date 03/06/2014
* @description Clase con Metodos Utilitarios el testeo de la funcionalidad del trigger tg_Venta
*/
@isTest
public class Test_tg_Venta{
    

    /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo que testea la funcionalidad de generar venta CA
    */
    public static testmethod void testGenerarVentasTipoCA(){
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
        
    }
    
    /**
    * @description Método que se encarga de testear la capacidad de generar compras a partir de otras ventas
    */
    public static testmethod void testGeneracionDeCompras(){
        
        //Creamos datos de Test
        
        //Creamos los datos de prueba
        Id rtObtentor =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');
        Id rtdistribuidor =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Distribuidor');
        
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
        
    }
    
}