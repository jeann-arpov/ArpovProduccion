@isTest
public class BatchApexActualizarCapsulaLicencias_TEST {
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
    }

    @isTest
    static void testCapsulaLicencias(){
        Test.startTest();
        BatchApexActualizarCapsulaLicencias b = new BatchApexActualizarCapsulaLicencias();
        Database.executeBatch(b);
        Test.stopTest();

        Licencia__c ens = [SELECT Id, Capsula__c FROM Licencia__c LIMIT 1];

        Assert.areEqual(null, ens.Capsula__c, 'Capsulas no coinciden');
    }
}