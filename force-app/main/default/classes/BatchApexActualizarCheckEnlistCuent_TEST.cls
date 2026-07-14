@isTest
public without sharing class BatchApexActualizarCheckEnlistCuent_TEST {
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
        Licencia__c lic = new Licencia__c(Cuenta_Productor__c = acc.Id, Estado__c = 'Aprobada', Tecnologia__c = 'Enlist', Tipo_de_Licencia__c = 'Productor', Fecha_de_Vencimiento__c = Date.today() + 1);
        insert lic;
    }

    @isTest
    static void testActualizarCheck(){      
        Test.startTest();
        BatchApexActualizarCheckEnlistCuenta b = new BatchApexActualizarCheckEnlistCuenta();
        Database.executeBatch(b);
        Test.stopTest();

        Account acc = [SELECT Id, Usuario_Enlist__c FROM Account LIMIT 1];

        Assert.areEqual(true, acc.Usuario_Enlist__c, 'check debe ser true');
    }
}