@isTest
public with sharing class GraficoSemillaControllerTest {
    public static testmethod void main() {
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
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG1', cultivo,  'Semilla Fiscalizada', 2, obtentor, false);
        p1.Categoria__c = 'Primera Multiplicación';
        insert p1;
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG2', cultivo,  'Regalía Comercial', 2, obtentor);        
        
        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'Venta');

        List<GraficoSemillaController.Data> data = GraficoSemillaController.getData([select name from Campana_Agricola__c where id =: campanaAgricola.id].name);

        System.assertEquals(data.size(), 1);         
    }
}