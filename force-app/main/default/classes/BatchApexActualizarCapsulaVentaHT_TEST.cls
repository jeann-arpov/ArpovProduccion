@isTest
public class BatchApexActualizarCapsulaVentaHT_TEST {
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

        Venta_HT__c venta = new Venta_HT__c(Obtentor__c = acc.Id, Estado__c = 'Creada');
        insert venta;
    }

    @isTest
    static void actualizarCapsulaVentaHT_test(){      
        Test.startTest();
        BatchApexActualizarCapsulaVentaHT b = new BatchApexActualizarCapsulaVentaHT();
        Database.executeBatch(b);
        Test.stopTest();

        Venta_HT__c ens = [SELECT Id, Capsula__c, Obtentor__r.Id_Obtentor__c FROM Venta_HT__c LIMIT 1];

        system.debug('Venta');
        system.debug(ens);

        Assert.areEqual('GRUPO DON MARIO', ens.Capsula__c, 'Capsulas no coinciden');
    }
}