/**
* @author Maximo Martinez
* @date 5/6/2014
* @description Clase de Test de la Clase CustomLookUpProductosController
*/
@isTest(SeeAllData = true)
public class Test_CustomLookUpProductosController{
    
    /*
    * @description Método de Test
    */
    public static testmethod void test(){
        
        //Creamos datos de Test
        
        //Creamos los datos de prueba
        Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
         //Creamos una cuenta de tipo Obtentor
        Account obtentor = Test_TestUtils.crearObtentor();
 
        //Creamos un distribuidor
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
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest1',null, 'NIDERA A 5509RG 1', cultivo,  'Regalía Comercial', 2, obtentor);
            
        Product2 p2 = Test_TestUtils.crearProducto(true,'ProductoTest2',null, 'NIDERA A 5509RG 2', cultivo,  'Regalía Comercial', 2, obtentor);     
        
        //Seteamos algunos argumentos a la pagina
        ApexPages.currentPage().getParameters().put('idOriginante',obtentor.Id);
        
        ApexPages.currentPage().getParameters().put('idCampana',campanaAgricola.Id);
        
        //Instanciamos el controller
        CustomLookUpProductosController ctrl = new CustomLookUpProductosController();
        
        //Obtenemos los productos, como el filtro es por obtentor y campaña, deberiamos obtener los dos productos que creamos
        List<Product2> ps = ctrl.getProducts();
        
        //System.AssertEquals(ps.size(),2);
        
        //Testamos los metodos clasicos de paginacion
        ctrl.firstPage();
        ctrl.lastPage();
        ctrl.next();
        ctrl.prev();
        
        
        //Generamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'C');
        
        //Seteamos algunos argumentos a la pagina
        ApexPages.currentPage().getParameters().put('idOriginante',distribuidor.Id);
        
        ApexPages.currentPage().getParameters().put('idCampana',campanaAgricola.Id);
        
        //Instanciamos el controller
        ctrl = new CustomLookUpProductosController();
        
        //Obtenemos los productos, como el filtro es por distribuidor y campaña, deberiamos obtener los dos productos que estan en una venta
        //donde el distribuidor esta como destinatario osea 1 solo
        ps = ctrl.getProducts();
        
        //System.AssertEquals(ps.size(),1);
        
        //Obtenemos la direccion del filtrado
        ctrl.getSortDirection();
        
        //Indicamos que vamos a filtrar por nombre
        ctrl.sortExpression = 'Name';
        
        //Reseteamos el filtro
        //ctrl.resetFilter();
    }
    
}