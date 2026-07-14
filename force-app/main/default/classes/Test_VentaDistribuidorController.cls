@isTest
public class Test_VentaDistribuidorController{
    
    public static testmethod void test(){

        Test_TestUtils.disableFlows();
        
        //Creamos datos de Test
        
        //RecordType que usamos en el Test
        RecordType rtDistribuidor = null;
        RecordType rtObtentor = null;
         
        //Creamos datos de Test
        
        //RecordType que usamos en el Test 
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
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

        Variedad__c var = new Variedad__c(Name = 'test', Biotecnologia__c = 'Enlist E3');
        insert var;
        
        //Creamos un par de productos
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG', cultivo,  'Regalía Comercial', 2, obtentor, var.Id, true);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        p1.Unidad_de_Medida__c = 'Granel';
        
        //Actualizamos la Base De Datos
        update p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG1', cultivo,  'Regalía Comercial', 2, obtentor, var.Id, true);    
        
        p2.Unidad_de_Medida__c = 'Granel';
        update p2;
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');
        
        List<VentasDistribuidorController.RowWrapper> filas = null;
        
        List<String> whereList = new List<String>();  
        
        //Ejecutamos agrupacion por cultivo  
        filas = VentasDistribuidorController.getDatos(distribuidor.Id,null, null,whereList);
        
        System.Debug(LoggingLevel.INFO,filas);
        
        //Verificamos que solo se devuelva una fila (solo hay una venta dada de alta)
        //System.AssertEquals(filas.size(),1);
        
        whereList.add(cultivo.Name);
        
        //Ejecutamos agrupacion por campaña
        filas = VentasDistribuidorController.getDatos(distribuidor.Id,null,0,whereList);
        
        System.Debug(LoggingLevel.INFO,filas);
        
        //Verificamos que solo se devuelva una fila (solo hay una venta dada de alta)
        //System.AssertEquals(filas.size(),1);
        
        whereList.add(campanaAgricola.Ano__c);
        
        //Ejecutamos agrupacion por obtentor
        filas = VentasDistribuidorController.getDatos(distribuidor.Id,null,1,whereList);
        
        System.Debug(LoggingLevel.INFO,filas);
        
        //Verificamos que solo se devuelva una fila (solo hay una venta dada de alta)
        //System.AssertEquals(filas.size(),2);
        
        whereList.add(obtentor.Id_Obtentor__c);
        
        //Ejecutamos agrupacion por variedad, tipo de producto y categoria
        filas = VentasDistribuidorController.getDatos(distribuidor.Id,null,2,whereList);
        
        System.Debug(LoggingLevel.INFO,filas);
        
        //Verificamos que solo se devuelva una fila (solo hay una venta dada de alta)
        //System.AssertEquals(filas.size(),1);
        
        whereList.add(p1.Variedad__c);
        
        whereList.add(p1.Family);
        
        whereList.add(p1.Categoria__c);

        whereList.add(p1.Unidad_de_Medida__c);
        
        //Ejecutamos el listado por um, Originante, Distribuidor, etc.
        filas = VentasDistribuidorController.getDatos(distribuidor.Id,null,3,whereList);
        
        //Verificamos que solo se devuelva una fila (solo hay una venta dada de alta)
        //System.AssertEquals(filas.size(),2);
    }
    
}