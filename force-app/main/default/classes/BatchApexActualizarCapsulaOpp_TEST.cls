@isTest
public class BatchApexActualizarCapsulaOpp_TEST {
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
        Opportunity opp = new Opportunity(Obtentor__c = acc.Id, AccountId = acc.Id, Name = 'Test', StageName = 'Creada', CloseDate = Date.today());
        insert opp;
    }

    @isTest
    static void actualizarCapsulaVentaHT_test(){      
        Test.startTest();
        BatchApexActualizarCapsulaOportunidad b = new BatchApexActualizarCapsulaOportunidad();
        Database.executeBatch(b);
        Test.stopTest();

        Opportunity ens = [SELECT Id, Capsula__c FROM Opportunity LIMIT 1];

        Assert.areEqual('GRUPO DON MARIO', ens.Capsula__c, 'Capsulas no coinciden');
    }
}