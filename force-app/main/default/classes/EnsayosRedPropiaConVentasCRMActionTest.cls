@isTest
public class EnsayosRedPropiaConVentasCRMActionTest {

    @TestSetup
    static void setup(){
        Test_TestUtils.disableFlows();

        Account obtentor = Test_TestUtils.crearObtentor();
        Account productor = Test_TestUtils.crearProductor();

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 1000);

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id);
        insert var;

        Product2 producto = Test_TestUtils.crearProducto(true, 'test producto', 'conversion', 'SOJA', cultivo, 'familia test', 1000, obtentor, var.Id, false);
        producto.Sembra_Evolucion__c = true;
        insert producto;

        Campana_Agricola__c campania = Test_TestUtils.crearCampanaAgricola('2023', cultivo, Date.today().addDays(-1), Date.today().addDays(10), 'test');

        Venta__c venta = Test_TestUtils.crearVenta(producto, campania, cultivo, 10, obtentor, productor, 'C');
    }

    @isTest
    static void test(){
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor'];

        List<EnsayosRedPropiaConVentasCRMAction.ValidacionRedPropiaResult> result = EnsayosRedPropiaConVentasCRMAction.obtenerListasProductores(new List<List<Id>>{new List<Id>{productor.Id}});

        Assert.isTrue(result[0].productoresConVentasCrmDestinatario.size() == 1);
    }
}