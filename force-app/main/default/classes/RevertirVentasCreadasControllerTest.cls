@IsTest
public with sharing class RevertirVentasCreadasControllerTest {
    
    @IsTest
    static void test(){
        
        Destinatarios_Errores_Batchs__c deb = new Destinatarios_Errores_Batchs__c();
        deb.Name = 'Test';
        deb.Email__c = 'test@email.com';
        insert deb;

        Lote__c lote = new Lote__c();
        lote.Descripcion__c = 'Generacion Ventas a Partir de Ventas Informadas ' + String.valueOf(Date.today());
        lote.Tipo__c = 'Ventas';
        lote.Tipo_de_Lote__c = 'Ventas';
        insert lote;

        //Creamos datos de Test
        
        //Creamos los datos de prueba
        
        Id rtVenta = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Ventas');
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
        venta.Lote__c = lote.Id;
        update venta;

        Test.startTest();
        try{
            RevertirVentasCreadasController.procesar(lote.Id);
        }catch(Exception e){}
        Test.stopTest();

    }

}