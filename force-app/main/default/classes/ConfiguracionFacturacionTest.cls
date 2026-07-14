@isTest
public class ConfiguracionFacturacionTest {
    
    @isTest static void test(){
        Account cuenta = Test_TestUtils.crearProductor();
        Account obtentor = Test_TestUtils.crearObtentor();

        ConfiguracionFacturacion.getData(true);
        ConfiguracionFacturacion.doSave(cuenta.Id, obtentor.Id);

        List<Punto_de_Venta__c> configs = [SELECT Id FROM Punto_de_Venta__c];
        System.assertEquals(1, configs.size());

        ConfiguracionFacturacion.doDelete(configs[0].Id);
        ConfiguracionFacturacion.searchAccounts('asd', null);

    }
}