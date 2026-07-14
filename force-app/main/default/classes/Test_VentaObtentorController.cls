@isTest
public class Test_VentaObtentorController{
    
    public static testmethod void test(){

        Test_TestUtils.disableFlows();
        
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
        Product2 p1 = Test_TestUtils.crearProducto(true,'ProductoTest',null, 'NIDERA A 5509RG', cultivo,  'Regalía Comercial', 2, obtentor, var.Id, true);
        
        //Seteamos la categoria del producto 
        p1.Categoria__c = 'Primera Multiplicación';
        p1.Unidad_de_Medida__c = 'Granel';
        
        //Actualizamos la Base De Datos
        update p1;

        //Creamos una venta
        Venta__c venta = Test_TestUtils.crearVenta(p1, campanaAgricola, cultivo, 1, obtentor, distribuidor, 'Venta');
    
        //Lista que contendra las filas devueltas
        List<VentasObtentorController.RowWrapper> filas = null;
        
        List<String> whereList = new List<String>();  
        
        filas = VentasObtentorController.getDatos(obtentor.Id,null, null,whereList, null);
        
        //Verificamos que solo se devuelva una fila (solo hay una venta dada de alta)
        //System.AssertEquals(filas.size(),1);
        
        whereList.add(cultivo.Name);
        
        filas = VentasObtentorController.getDatos(obtentor.Id,null, 0,whereList, null);
        
        //Verificamos que solo se devuelva una fila (solo hay una venta dada de alta)
        //System.AssertEquals(filas.size(),1);
        
        
        whereList.add(campanaAgricola.Ano__c);
        
        
        filas = VentasObtentorController.getDatos(obtentor.Id,null, 1,whereList, null);

        filas = VentasObtentorController.getDatos(obtentor.Id,null, 2,whereList, null);


        
        //Verificamos que solo se devuelva una fila (solo hay una venta dada de alta)
        //System.AssertEquals(filas.size(),1);

        VentasObtentorController.RowWrapper rw = new VentasObtentorController.RowWrapper();
        rw.cultivo = 'TEST';
        rw.campana = 'TEST';
        rw.variedad = 'TEST';
        rw.tipo = 'TEST';
        rw.categoria = 'TEST';
        rw.um = 'TEST';
        rw.informadas = 12;
        rw.distribuidor = 12;
        rw.productor = 12;
        rw.porcentajeProductor = 12;
        rw.sinOrigen = 12;

        VentasObtentorController.calculateRowWrapper(new List<VentasObtentorController.RowWrapper>{rw});
        
    }
}