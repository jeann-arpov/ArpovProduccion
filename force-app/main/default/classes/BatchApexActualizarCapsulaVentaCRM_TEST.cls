@isTest
public class BatchApexActualizarCapsulaVentaCRM_TEST {
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
            Obtentor_Comercializa__c = acc.Id
        );
        insert var;

        Product2 prod = new Product2(
            Variedad2__c = var.Id,
            Variedad__c = 'test',
            Name = 'test'
        );
        insert prod;

        Venta__c venta = new Venta__c(Licencia__c = lic.Id, Cultivo__c = cultivo.Id, Cantidad__c = 75, Campana_Agricola__c = campana.Id, Destinatario__c = acc.Id, Producto__c = prod.Id);
        insert venta;
    }

    @isTest
    static void testCapsulasVentaCRM(){      
        Test.startTest();
        BatchApexActualizarCapsulaVentaCRM b = new BatchApexActualizarCapsulaVentaCRM();
        Database.executeBatch(b);
        Test.stopTest();

        Venta__c ens = [SELECT Id, Capsula__c FROM Venta__c LIMIT 1];

        Assert.areEqual('GRUPO DON MARIO', ens.Capsula__c, 'Capsulas no coinciden');
    }
}