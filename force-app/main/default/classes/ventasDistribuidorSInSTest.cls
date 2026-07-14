@isTest
public class ventasDistribuidorSInSTest {
    public static testmethod void main() {

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
        
        List<String> whereList = new List<String>();  
        
        ventasDistribuidorSInS.getDatos(distribuidor.Id,null,null,whereList);
        
        whereList.add(cultivo.Name);
        
        ventasDistribuidorSInS.getDatos(distribuidor.Id,null,0,whereList);
        
        whereList.add(campanaAgricola.Ano__c);

        system.debug(whereList);
        system.debug([select Campana_Agricola__r.Ano__c, Cultivo__r.Name, Id_Obtentor__c from Venta__c].Campana_Agricola__r.Ano__c);
        
        ventasDistribuidorSInS.getDatos(distribuidor.Id,null,1,whereList);

        Venta__c v = [select Id_Obtentor__c, Producto__r.Variedad__c, Tipo_de_Producto__c, Categoria__c, UM__c from Venta__c];

        whereList.add(v.Id_Obtentor__c);

        ventasDistribuidorSInS.getDatos(distribuidor.Id,null,2,whereList);
        
        whereList.add(v.Producto__r.Variedad__c);
        whereList.add(v.Tipo_de_Producto__c);
        whereList.add(v.Categoria__c);
        whereList.add(v.UM__c);

        ventasDistribuidorSInS.getDatos(distribuidor.Id,null,3,whereList);

        ventasDistribuidorSInS.getAccountIdCommunity();

        ventasDistribuidorSInS.getDatos(distribuidor.Id,null,null,whereList, false);
    }
}