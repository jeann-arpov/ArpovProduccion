@isTest
public class BatchApexActualizarCapsulaHT_TEST {
    @TestSetup
    static void makeData(){
        Test_TestUtils.disableFlows();

        Account acc = new Account(
            Name = 'Test', 
            Id_Obtentor__c = '03', 
            Type = 'Obtentor', 
            Nombre_Obtentor__c = 'test',
            RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor')
        );
        insert acc;
        Licencia__c lic = new Licencia__c(Cuenta_Obtentor__c = acc.Id, Estado__c = 'Aprobada');
        insert lic;

        Campana_Agricola__c campana = new Campana_Agricola__c();
        insert campana;
        
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);

        Variedad__c var = new Variedad__c(
            Obtentor_Comercializa__c = acc.Id,
            Biotecnologia__c = 'Enlist E3'
        );
        insert var;

        Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c(
            Variedad__c = var.Id,
            Cantidad__c = 10,
            Productor__c = acc.Id
        );
        insert ht;
    }

    @isTest
    static void testCapsulasVentaCRM(){      
        Test.startTest();
        BatchApexActualizarCapsulaHT b = new BatchApexActualizarCapsulaHT();
        Database.executeBatch(b);
        Test.stopTest();

        Hectareas_Tecnologicas__c ens = [SELECT Id, Capsula__c FROM Hectareas_Tecnologicas__c LIMIT 1];

        Assert.areEqual('GRUPO DON MARIO', ens.Capsula__c, 'Capsulas no coinciden');
    }
}