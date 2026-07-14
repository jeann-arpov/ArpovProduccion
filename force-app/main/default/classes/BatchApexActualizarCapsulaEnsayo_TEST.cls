@isTest
public with sharing class BatchApexActualizarCapsulaEnsayo_TEST {
    @TestSetup
    static void makeData(){
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
        Ensayo__c ens = new Ensayo__c(Licencia__c = lic.Id, Obtentor__c = acc.Id);
        insert ens;
    }

    @isTest
    static void testCapsulasEnsayos(){      
        Test_TestUtils.disableFlows(); 
        system.debug('test');
        system.debug([SELECT Id, Licencia__c FROM Ensayo__c]);

        Test.startTest();
        BatchApexActualizarCapsulaEnsayo b = new BatchApexActualizarCapsulaEnsayo();
        Database.executeBatch(b);
        Test.stopTest();

        Ensayo__c ens = [SELECT Id, Capsula__c FROM Ensayo__c LIMIT 1];

        Assert.areEqual(null, ens.Capsula__c, 'Capsulas no coinciden');
    }
}