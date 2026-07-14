@isTest
public class ExpedienteNegativoTest {

    @TestSetup
    static void setup(){
        Account obtentor = Test_TestUtils.crearObtentor();
        Account productor = Test_TestUtils.crearProductor();

        Cultivo__c soja = Test_TestUtils.crearCultivo('SOJA', 100);
    }
    
    @isTest
    static void test(){
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c();
        expediente.Obtentor__c = [SELECT Id FROM Account WHERE Name = 'Obtentor' LIMIT 1].Id;
        expediente.Cuenta__c = productor.Id;
        expediente.Etapa__c = 'Compra HT';
        insert expediente;

        List<LookupSearchResult> results = ExpedienteNegativo.searchAccounts('productor', null);

        Assert.areEqual(1, results.size());

        expediente = ExpedienteNegativo.getExpedienteNegativosByAccountId(productor.Id);

        Assert.isTrue(expediente != null);

        expediente = ExpedienteNegativo.getExpedienteNegativosById(expediente.Id);
    }

    @isTest
    static void testNoRecord(){
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];

        try {
            Expediente_de_Negativos__c expediente = ExpedienteNegativo.getExpedienteNegativosByAccountId(productor.Id);
        } catch (Exception e) {
            Assert.isTrue(true);
        }
    }

    @isTest
    static void testFacturarYCobrarRegaliaEnlist(){
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];
        productor.TN_Disponibles__c = -10;

        update productor;

        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c();
        expediente.Obtentor__c = [SELECT Id FROM Account WHERE Name = 'Obtentor' LIMIT 1].Id;
        expediente.ValidationBypassDateTime__c = Datetime.now();
        expediente.Cuenta__c = productor.Id;
        expediente.Etapa__c = 'Deriva a CTV';
        insert expediente;

        ExpedienteNegativo.facturarRegaliaEnlist(expediente.Id);
    }

    @isTest
    static void testCerrarExpediente(){
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];
        productor.TN_Disponibles__c = 10;

        update productor;

        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c();
        expediente.Obtentor__c = [SELECT Id FROM Account WHERE Name = 'Obtentor' LIMIT 1].Id;
        expediente.ValidationBypassDateTime__c = Datetime.now();
        expediente.Cuenta__c = productor.Id;
        expediente.Etapa__c = 'Deriva a CTV';
        insert expediente;

        ExpedienteNegativo.cerrarExpediente(expediente.Id);

        Assert.areEqual('Finalizado', [SELECT Estado_de_la_Etapa__c FROM Expediente_de_Negativos__c WHERE Id = :expediente.Id].Estado_de_la_Etapa__c);
    }
}