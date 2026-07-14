@isTest
public class EstablecimientoTriggerHandlerTest {
    
    @TestSetup
    static void setup(){
        Account productor = Test_TestUtils.crearProductor();

        Establecimiento__c establecimiento = new Establecimiento__c();
        establecimiento.Name = 'test';
        establecimiento.Coordenadas__latitude__s = -35.13;
        establecimiento.Coordenadas__longitude__s = -61.33;
        establecimiento.Vigente__c = false;
        establecimiento.Productor__c = productor.Id;
        establecimiento.Origen__c = 'Propio';

        insert establecimiento;
    }

    @isTest static void testSuccess(){

        Account productor = [SELECT Id FROM Account LIMIT 1];

        Establecimiento__c establecimiento = new Establecimiento__c();
        establecimiento.Name = 'test2';
        establecimiento.Coordenadas__latitude__s = -36.11;
        establecimiento.Coordenadas__longitude__s = -60.73;
        establecimiento.Vigente__c = false;
        establecimiento.Productor__c = productor.Id;
        establecimiento.Origen__c = 'Propio';

        EstablecimientoTriggerHandler.shouldRun = true;

        Database.SaveResult result = Database.insert(establecimiento);

        System.assert(result.isSuccess());
    }

    @isTest static void testDuplicate(){

        Account productor = [SELECT Id FROM Account LIMIT 1];

        Establecimiento__c establecimiento = new Establecimiento__c();
        establecimiento.Name = 'test';
        establecimiento.Coordenadas__latitude__s = -35.13;
        establecimiento.Coordenadas__longitude__s = -61.33;
        establecimiento.Vigente__c = false;
        establecimiento.Productor__c = productor.Id;
        establecimiento.Origen__c = 'Propio';

        EstablecimientoTriggerHandler.shouldRun = true;

        try{
            Database.SaveResult result = Database.insert(establecimiento);
        }catch(Exception e){
            System.assert(e.getMessage().contains('Registro duplicado'));
        }
    }
}