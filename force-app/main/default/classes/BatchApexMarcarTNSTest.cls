@isTest
public class BatchApexMarcarTNSTest {
    
    @TestSetup
    static void setup(){
        Test_TestUtils.disableFlows();

        Test_TestUtils.crearProductor();
        Test_TestUtils.crearObtentor();

        Account sembraEvolucion = new Account(Name = 'Sembrá Evolución');
        insert sembraEvolucion;

        // En tests el batch usa marzo del año actual
        Date fechaVencimiento = Date.newInstance(Date.today().year(), 03, 06);

        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA', Densidad_de_Siembra__c = 5, Fecha_Vencimiento_Tonelada__c = fechaVencimiento, Id_Externo__c = 'SOJA', Sembra_Evolucion__c = true);
        insert cultivo;

        Variedad__c var = new Variedad__c(Name = 'test', Biotecnologia__c = 'Enlist E3');
        insert var;
    }

    @isTest
    static void testCreaBalanceAnual(){
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor'];
        Variedad__c var = [SELECT Id FROM Variedad__c LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];

        // En tests el batch usa marzo del año actual
        Date fechaFin = Date.newInstance(Date.today().year(), 03, 06);
        Date fechaInicio = Date.newInstance(Date.today().year(), 03, 01);

        Tonelada__c tonelada = new Tonelada__c(
            Productor__c = productor.id, 
            Tonelada_Anterior__c = false, 
            Biotecnologia__c = 'Enlist E3', 
            Signo__c = -1, 
            Cantidad__c = 9, 
            Cultivo__c = cultivo.id, 
            Variedad__c = var.id, 
            Origen__c = 'Compra HT', 
            Fecha_Inicio__c = fechaInicio, 
            Fecha_Fin__c = fechaFin
        );
        insert tonelada;

        Test.startTest();
        Database.executeBatch(new BatchApexMarcarTNS());
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Tonelada__c WHERE Origen__c = 'Balance Anual']);
    }

    @isTest
    static void testNoCreaBalanceAnual(){
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor'];
        Variedad__c var = [SELECT Id FROM Variedad__c LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];

        // En tests el batch usa marzo del año actual
        Date fechaFin = Date.newInstance(Date.today().year(), 03, 06);
        Date fechaInicio = Date.newInstance(Date.today().year(), 03, 01);

        Tonelada__c tonelada = new Tonelada__c(
            Productor__c = productor.id, 
            Tonelada_Anterior__c = false, 
            Biotecnologia__c = 'Enlist E3', 
            Signo__c = 1, 
            Cantidad__c = 9, 
            Cultivo__c = cultivo.id, 
            Variedad__c = var.id, 
            Origen__c = 'Compra HT', 
            Fecha_Inicio__c = fechaInicio, 
            Fecha_Fin__c = fechaFin
        );
        insert tonelada;

        Test.startTest();
        Database.executeBatch(new BatchApexMarcarTNS());
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Tonelada__c WHERE Origen__c = 'Balance Anual']);
    }
}