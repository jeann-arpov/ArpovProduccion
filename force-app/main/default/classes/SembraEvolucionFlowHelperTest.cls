@isTest(SeeAllData=false)
private class SembraEvolucionFlowHelperTest {

    @TestSetup
    static void makeData() {
        // 1. Desactivar automatizaciones de flujos para evitar excepciones en la inserción de registros
        Test_TestUtils.disableFlows();

        // 2. Configuración e inserción de Listas de Precios necesarias para los flujos de Producto/Variedad
        Id standardPbId = Test.getStandardPricebookId();
        Pricebook2 standardPb = new Pricebook2(
            Id = standardPbId, 
            IsActive = true
        );
        update standardPb;

        Pricebook2 pbSE = new Pricebook2(
            Name = 'Lista de Precios SE', 
            IsActive = true
        );
        insert pbSE;

        // 3. Configuración de datos de ERP base (Moneda y Datos Generales)
        ERPvs.TestUtils.insertDatosGenerales();
        ERPvs__Datos_Generales__c dg = [SELECT Id FROM ERPvs__Datos_Generales__c LIMIT 1];

        ERPvs__Moneda__c monERP = new ERPvs__Moneda__c(
            Name = '1',
            ERPvs__Denominacion__c = 'moneda',
            ERPvs__Pertenece_A__c = dg.Id,
            ERPvs__Moneda_Nacional__c = false,
            ERPvs__Moneda_Traducida__c = true
        );
        insert monERP;

        Moneda__c moneda = Test_TestUtils.crearMoneda('USD', 'USD', true, false);
        moneda.Moneda_ERP__c = monERP.Id;
        insert moneda;

        // 4. Crear Localidad y Cuenta con los campos obligatorios del modelo de datos
        Localidad__c localidad = new Localidad__c(Zona_Bolsa_Cereales__c = 'Test');
        insert localidad;

        Account acc = new Account(
            Name = 'Productor Test',
            N_CUIT__c = '20128018639',
            Condicion_Impositiva__c = 'No Aplica',
            Localidad_Envio__c = localidad.Id,
            Clave_Unica__c = 'TEST_PRODUCTOR_SRE'
        );
        insert acc;

        // 5. Crear Variedades de prueba
        Variedad__c varTrue = new Variedad__c(
            Name = 'Variedad True Test',
            Sembra_Evolucion__c = true,
            Biotecnologia__c = 'Convencional'
        );
        insert varTrue;

        Variedad__c varFalse = new Variedad__c(
            Name = 'Variedad False Test',
            Sembra_Evolucion__c = false,
            Biotecnologia__c = 'Convencional'
        );
        insert varFalse;

        // 6. Crear Registro de Excepción en Variedad_SRE_por_Productor__c
        Variedad_SRE_por_Productor__c sre = new Variedad_SRE_por_Productor__c(
            Cuenta__c = acc.Id,
            Variedad__c = varFalse.Id
        );
        insert sre;
    }

    @isTest
    static void testEvaluacionSembraEvolucion() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Variedad__c> variedades = [SELECT Id, Sembra_Evolucion__c FROM Variedad__c];
        
        Id varTrueId;
        Id varFalseId;
        for (Variedad__c v : variedades) {
            if (v.Sembra_Evolucion__c) {
                varTrueId = v.Id;
            } else {
                varFalseId = v.Id;
            }
        }

        Test.startTest();
        List<SembraEvolucionFlowHelper.Request> requests = new List<SembraEvolucionFlowHelper.Request>();

        // Req 1: Variedad global true -> Debe devolver true
        SembraEvolucionFlowHelper.Request req1 = new SembraEvolucionFlowHelper.Request();
        req1.accountId = acc.Id;
        req1.variedadId = varTrueId;
        requests.add(req1);

        // Req 2: Variedad global false pero con registro en Variedad_SRE_por_Productor__c -> Debe devolver true
        SembraEvolucionFlowHelper.Request req2 = new SembraEvolucionFlowHelper.Request();
        req2.accountId = acc.Id;
        req2.variedadId = varFalseId;
        requests.add(req2);

        List<Boolean> resultados = SembraEvolucionFlowHelper.evaluarSembraEvolucion(requests);
        Test.stopTest();

        Assert.areEqual(2, resultados.size(), 'Debe devolver un resultado por cada request recibida');
        Assert.isTrue(resultados[0], 'Debe ser true por configuración global de la variedad');
        Assert.isTrue(resultados[1], 'Debe ser true por registro de excepción en Variedad_SRE_por_Productor__c');
    }
}