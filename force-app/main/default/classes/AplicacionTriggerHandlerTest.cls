@IsTest
private class AplicacionTriggerHandlerTest {

    @IsTest
    static void marcaTieneComisionRECuandoSeAsignaCVComisiones() {
        Test_TestUtils.disableFlows();

        Account productor = Test_TestUtils.crearProductor();
        Account obtentor = Test_TestUtils.crearObtentor();

        Opportunity factura = new Opportunity(
            Name = 'Factura test comision RE',
            StageName = 'Facturada',
            CloseDate = Date.today(),
            AccountId = productor.Id,
            Obtentor__c = obtentor.Id,
            Tiene_Comision_RE__c = false
        );
        insert factura;

        Test.startTest();
        AplicacionComisionREService.marcarDesdeAplicaciones(
            new List<Aplicacion__c>{
                new Aplicacion__c(
                    Factura__c = factura.Id,
                    CV_Comisiones__c = factura.Id
                )
            },
            null
        );
        Test.stopTest();

        System.assertEquals(
            true,
            [SELECT Tiene_Comision_RE__c FROM Opportunity WHERE Id = :factura.Id].Tiene_Comision_RE__c
        );
    }

    @IsTest
    static void noMarcaSiCVComisionesEsNulo() {
        Test_TestUtils.disableFlows();

        Account productor = Test_TestUtils.crearProductor();
        Account obtentor = Test_TestUtils.crearObtentor();

        Opportunity factura = new Opportunity(
            Name = 'Factura sin CV comisiones',
            StageName = 'Facturada',
            CloseDate = Date.today(),
            AccountId = productor.Id,
            Obtentor__c = obtentor.Id,
            Tiene_Comision_RE__c = false
        );
        insert factura;

        Test.startTest();
        AplicacionComisionREService.marcarDesdeAplicaciones(
            new List<Aplicacion__c>{
                new Aplicacion__c(
                    Factura__c = factura.Id,
                    CV_Comisiones__c = null
                )
            },
            null
        );
        Test.stopTest();

        System.assertEquals(
            false,
            [SELECT Tiene_Comision_RE__c FROM Opportunity WHERE Id = :factura.Id].Tiene_Comision_RE__c
        );
    }

    @IsTest
    static void noActualizaSiYaTieneComisionRE() {
        Test_TestUtils.disableFlows();

        Account productor = Test_TestUtils.crearProductor();
        Account obtentor = Test_TestUtils.crearObtentor();

        Opportunity factura = new Opportunity(
            Name = 'Factura con comision RE',
            StageName = 'Facturada',
            CloseDate = Date.today(),
            AccountId = productor.Id,
            Obtentor__c = obtentor.Id,
            Tiene_Comision_RE__c = true
        );
        insert factura;

        Test.startTest();
        AplicacionComisionREService.marcarDesdeAplicaciones(
            new List<Aplicacion__c>{
                new Aplicacion__c(
                    Factura__c = factura.Id,
                    CV_Comisiones__c = factura.Id
                )
            },
            null
        );
        Test.stopTest();

        System.assertEquals(
            true,
            [SELECT Tiene_Comision_RE__c FROM Opportunity WHERE Id = :factura.Id].Tiene_Comision_RE__c
        );
    }

    @IsTest
    static void marcarFacturasActualizaOportunidades() {
        Test_TestUtils.disableFlows();

        Account productor = Test_TestUtils.crearProductor();
        Account obtentor = Test_TestUtils.crearObtentor();

        Opportunity factura = new Opportunity(
            Name = 'Factura marcarFacturas',
            StageName = 'Facturada',
            CloseDate = Date.today(),
            AccountId = productor.Id,
            Obtentor__c = obtentor.Id,
            Tiene_Comision_RE__c = false
        );
        insert factura;

        Test.startTest();
        AplicacionComisionREService.marcarFacturas(new Set<Id>{ factura.Id });
        Test.stopTest();

        System.assertEquals(
            true,
            [SELECT Tiene_Comision_RE__c FROM Opportunity WHERE Id = :factura.Id].Tiene_Comision_RE__c
        );
    }

    @IsTest
    static void listaVaciaNoHaceNada() {
        AplicacionComisionREService.marcarDesdeAplicaciones(new List<Aplicacion__c>(), null);
        AplicacionComisionREService.marcarFacturas(new Set<Id>());
        System.assert(true);
    }
}