@isTest
private class FiltrarMBTPendientesTest {

    @testSetup
    static void setupData() {
        // 1. Crear Cuenta requerida por el Flow (cuentaId)
        Account accTest = new Account(Name = 'Cuenta Test Flow');
        insert accTest;

        // 2. Crear registro maestro de Cultivo
        Cultivo__c cultivoTest = new Cultivo__c(
            Name = 'Soja',
            Densidad_de_Siembra__c = 10.0
        );
        insert cultivoTest;

        // 3. Crear registros del expediente
        Expediente_de_Negativos__c exp1 = new Expediente_de_Negativos__c(Name = 'Expediente Test 1');
        Expediente_de_Negativos__c exp2 = new Expediente_de_Negativos__c(Name = 'Expediente Test 2');
        insert new List<Expediente_de_Negativos__c>{ exp1, exp2 };

        // 4. Crear registros de TN_Regalia_Enlist__c (Facturas)
        TN_Regalia_Enlist__c fact1 = new TN_Regalia_Enlist__c(
            Expediente_de_Negativos__c = exp1.Id,
            CTGs_Involucrados__c = '[1025834788, 1025834789]'
        );
        insert fact1;

        // 5. Crear registros de Movimiento_BolsaTech__c (MBTs) completando la Cuenta y Cultivo
        List<Movimiento_BolsaTech__c> mbtsToInsert = new List<Movimiento_BolsaTech__c>();

        // MBT 1: CTG ya facturado en exp1
        Movimiento_BolsaTech__c mbt1 = new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = exp1.Id,
            CTG__c = '1025834788',
            Cultivo__c = cultivoTest.Id,
            Titular_asignado__c = accTest.Id // Asignación del Id de Cuenta para el Flow
        );

        // MBT 2: CTG NO facturado en exp1
        Movimiento_BolsaTech__c mbt2 = new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = exp1.Id,
            CTG__c = '9999999999',
            Cultivo__c = cultivoTest.Id,
            Titular_asignado__c = accTest.Id
        );

        // MBT 3: CTG vacío en exp1
        Movimiento_BolsaTech__c mbt3 = new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = exp1.Id,
            CTG__c = '',
            Cultivo__c = cultivoTest.Id,
            Titular_asignado__c = accTest.Id
        );

        // MBT 4: CTG en exp2
        Movimiento_BolsaTech__c mbt4 = new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = exp2.Id,
            CTG__c = '8888888888',
            Cultivo__c = cultivoTest.Id,
            Titular_asignado__c = accTest.Id
        );

        mbtsToInsert.addAll(new List<Movimiento_BolsaTech__c>{ mbt1, mbt2, mbt3, mbt4 });

        // Si el Flow espera la cuenta en otro campo de lookup distinto a Titular_asignado__c,
        // aseguramos la asignación en los otros campos comunes:
        for (Movimiento_BolsaTech__c mbt : mbtsToInsert) {
            mbt.Titular_original__c = accTest.Id;
            mbt.Destinatario__c = accTest.Id;
        }

        insert mbtsToInsert;
    }

    @isTest
    static void testObtenerPendientesExitoso() {
        List<Expediente_de_Negativos__c> exps = [SELECT Id FROM Expediente_de_Negativos__c ORDER BY Name ASC];
        Id exp1Id = exps[0].Id;
        Id exp2Id = exps[1].Id;

        List<FiltrarMBTPendientes.Request> requests = new List<FiltrarMBTPendientes.Request>();
        
        FiltrarMBTPendientes.Request req1 = new FiltrarMBTPendientes.Request();
        req1.expedienteId = exp1Id;
        requests.add(req1);

        FiltrarMBTPendientes.Request req2 = new FiltrarMBTPendientes.Request();
        req2.expedienteId = exp2Id;
        requests.add(req2);

        Test.startTest();
        List<FiltrarMBTPendientes.Response> respuestas = FiltrarMBTPendientes.obtenerPendientes(requests);
        Test.stopTest();

        System.assertEquals(2, respuestas.size(), 'Deberían retornarse 2 respuestas.');

        FiltrarMBTPendientes.Response res1 = respuestas[0];
        System.assertEquals(2, res1.cantidadPendientes, 'Deberían quedar 2 MBTs pendientes para el expediente 1.');

        FiltrarMBTPendientes.Response res2 = respuestas[1];
        System.assertEquals(1, res2.cantidadPendientes, 'Debería haber 1 MBT pendiente para el expediente 2.');
    }

    @isTest
    static void testObtenerPendientesRequestVacio() {
        List<FiltrarMBTPendientes.Request> requests = new List<FiltrarMBTPendientes.Request>();
        
        FiltrarMBTPendientes.Request reqVacio = new FiltrarMBTPendientes.Request();
        reqVacio.expedienteId = '';
        requests.add(reqVacio);

        Test.startTest();
        List<FiltrarMBTPendientes.Response> respuestas = FiltrarMBTPendientes.obtenerPendientes(requests);
        Test.stopTest();

        System.assertEquals(1, respuestas.size(), 'Debería haber una respuesta devuelta.');
        System.assertEquals(0, respuestas[0].cantidadPendientes, 'La cantidad de pendientes debe ser 0 para un ID vacío.');
    }
}