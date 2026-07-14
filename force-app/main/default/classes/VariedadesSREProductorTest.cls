@isTest
public class VariedadesSREProductorTest {
    
    @TestSetup
    static void setup(){
        Test_TestUtils.disableFlows();

        Account obtentor = Test_TestUtils.crearObtentor();
        Account productor = Test_TestUtils.crearProductor(); //name: productor

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Propietario__c = obtentor.id, Obtentor_Comercializa__c = obtentor.id);
        insert var;
    }

    @isTest
    static void testVariedadesObtentor(){
        List<Variedad__c> variedadesObtentor = VariedadesSREProductor.getVariedadesSRE();
        Assert.areEqual(1, variedadesObtentor.size());
    }

    @isTest
    static void testBuscadorCuentas(){
        List<LookupSearchResult> results = VariedadesSREProductor.searchAccounts('productor', null);
        Assert.areEqual(1, results.size());
    }

    @isTest
    static void testVariedadesSREProductor(){
        List<Variedad_SRE_por_Productor__c> variedadesSREProductor = VariedadesSREProductor.getVariedadesSREProductor([SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1].Id);
        Assert.areEqual(0, variedadesSREProductor.size());
    }

    @isTest
    static void testNewVariedadSREProductor(){
        Variedad__c var = [SELECT Id FROM Variedad__c];
        Account prod = [SELECT Id FROM Account WHERE Name = 'productor'];

        VariedadesSREProductor.doSave(prod.Id, new List<Id>{var.Id});

        Assert.areEqual(1, [SELECT Count() FROM Variedad_SRE_por_Productor__c]);

        VariedadesSREProductor.doSave(prod.Id, new List<Id>());

        Assert.areEqual(0, [SELECT Count() FROM Variedad_SRE_por_Productor__c]);
    }
}