@IsTest
private class BatchMarcarTieneComisionRETest {

    @IsTest
    static void startDevuelveQueryLocator() {
        Test.startTest();
        Database.QueryLocator ql = new BatchMarcarTieneComisionRE().start(null);
        Test.stopTest();
        System.assertNotEquals(null, ql);
    }

    @IsTest
    static void executeMarcaTieneComisionRE() {
        Test_TestUtils.disableFlows();

        Account productor = Test_TestUtils.crearProductor();
        Account obtentor = Test_TestUtils.crearObtentor();

        Opportunity factura = new Opportunity(
            Name = 'Factura batch comision RE',
            StageName = 'Facturada',
            CloseDate = Date.today(),
            AccountId = productor.Id,
            Obtentor__c = obtentor.Id,
            Tiene_Comision_RE__c = false
        );
        insert factura;

        Test.startTest();
        new BatchMarcarTieneComisionRE().execute(
            null,
            new List<Opportunity>{ factura }
        );
        Test.stopTest();

        System.assertEquals(
            true,
            [SELECT Tiene_Comision_RE__c FROM Opportunity WHERE Id = :factura.Id].Tiene_Comision_RE__c
        );
    }

    @IsTest
    static void batchCompletoSinErrores() {
        Test_TestUtils.disableFlows();

        Test.startTest();
        Id jobId = Database.executeBatch(new BatchMarcarTieneComisionRE(), BatchMarcarTieneComisionRE.BATCH_SIZE);
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}