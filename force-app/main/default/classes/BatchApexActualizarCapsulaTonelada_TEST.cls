@isTest
public class BatchApexActualizarCapsulaTonelada_TEST {
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
        Compra_HT__c compra = new Compra_HT__c(Lista_de_Precios__c = Test.getStandardPricebookId(), Cuenta_Productor__c = acc.id, Estado__c = 'Creada');
        insert compra;

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = acc.id, Sembra_Evolucion__C = true, Biotecnologia__c = 'RR1');
        insert var;

        Tonelada__c tn = new Tonelada__c(Variedad__c = var.Id, Cantidad__c = 200, Productor__c = acc.Id);
        insert tn;
    }

    @isTest
    static void actualizarCapsulaCompraHT_test(){      
        Test.startTest();
        BatchApexActualizarCapsulaTonelada b = new BatchApexActualizarCapsulaTonelada();
        Database.executeBatch(b);
        Test.stopTest();

        Tonelada__c ens = [SELECT Id, Capsula__c FROM Tonelada__c LIMIT 1];

        Assert.areEqual('GRUPO DON MARIO', ens.Capsula__c, 'Capsulas no coinciden');
    }
}