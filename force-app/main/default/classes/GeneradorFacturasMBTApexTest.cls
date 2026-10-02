@isTest
private class GeneradorFacturasMBTApexTest {

    // Método auxiliar proporcionado para crear el Obtentor cumpliendo todas las validaciones
    private static Account crearObtentor(String cuit, String sufijo) {
        Id rtObtentor = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Obtentor')
            .getRecordTypeId();
        Account acc = new Account(
            Name = 'GDM ARGENTINA S. A. (' + sufijo + ')',
            N_CUIT__c = cuit,
            Type = 'Obtentor',
            RecordTypeId = rtObtentor,
            Id_Obtentor__c = sufijo,
            Nombre_Obtentor__c = 'GDM ' + sufijo
        );
        insert acc;
        return acc;
    }

    @testSetup
    static void setupData() {
        // 1. Crear Cuenta Obtentora usando el método con sufijo '30' (2 caracteres máx)
        Account accObtentor = crearObtentor('20444444445', '30');

        // 2. Crear Cuentas requeridas (Productor, Cobrador y Destinatario)
        List<Account> cuentas = new List<Account>();
        
        Account accCobrador1 = new Account(
            Name = 'Cobrador Remitente Test',
            N_CUIT__c = '20111111112',
            ParentId = null
        );
        cuentas.add(accCobrador1);

        Account accDestinatario = new Account(
            Name = 'Destinatario Cobrador Test',
            N_CUIT__c = '20222222223',
            ParentId = null
        );
        cuentas.add(accDestinatario);

        Account accProductor = new Account(
            Name = 'Productor Test',
            N_CUIT__c = '20333333334'
        );
        cuentas.add(accProductor);

        insert cuentas;

        // 3. Configurar Custom Setting Sembra_Evolucion__c referenciando al Obtentor real
        Sembra_Evolucion__c setting = new Sembra_Evolucion__c(
            Corteva_30_Id__c = accObtentor.Id
        );
        insert setting;

        // 4. Crear registro maestro de Cultivo obligatorio
        Cultivo__c cultivoTest = new Cultivo__c(
            Name = 'SOJA',
            Densidad_de_Siembra__c = 10.0
        );
        insert cultivoTest;
        cultivoTest = [SELECT Id, Name FROM Cultivo__c WHERE Id = :cultivoTest.Id LIMIT 1];

        // 5. Crear Expediente de prueba
        Expediente_de_Negativos__c expTest = new Expediente_de_Negativos__c(
            Name = 'Expediente Test'
        );
        insert expTest;

        // 6. Crear registros de Movimiento_BolsaTech__c (MBTs)
        List<Movimiento_BolsaTech__c> mbts = new List<Movimiento_BolsaTech__c>();

        Movimiento_BolsaTech__c mbt1 = new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = expTest.Id,
            Cultivo__c = cultivoTest.Id,
            Titular__c = accProductor.Id,
            Titular_asignado__c = accProductor.Id,
            Titular_original__c = accProductor.Id,
            Destinatario__c = accCobrador1.Id,
            CUIT_Titular__c = '20000000001',
            Cuit_Remitente_Comercial__c = '20111111112',
            CTG__c = '12345678',
            Destino__c = '20635',
            Tecnologia__c = 'ENLIST',
            Estado__c = 'Creado',
            Peso_Neto__c = 30000,
            Cosecha__c = '2324',
            Tipo_de_entrega__c = 'Segunda Disposición'
        );

        Movimiento_BolsaTech__c mbt2 = new Movimiento_BolsaTech__c(
            Expediente_de_Negativos__c = expTest.Id,
            Cultivo__c = cultivoTest.Id,
            Titular__c = accProductor.Id,
            Titular_original__c = accProductor.Id,
            Destinatario__c = accDestinatario.Id,
            CTG__c = '87654321',
            Destino__c = '20635',
            Tecnologia__c = 'ENLIST',
            Estado__c = 'Creado',
            Peso_Neto__c = 30000,
            Cosecha__c = '2324',
            Tipo_de_entrega__c = 'Segunda Disposición'
        );

        mbts.add(mbt1);
        mbts.add(mbt2);

        insert mbts;
    }

    @isTest
    static void testGenerarFacturasExitoso() {
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Name = 'Productor Test' LIMIT 1];
        
        List<Movimiento_BolsaTech__c> mbts = [
            SELECT Id, CUIT_Titular__c, Cuit_Remitente_Comercial__c, Destinatario__c, 
                   Titular_asignado__c, Titular_original__c, Tonelada_MBT__c, CTG__c 
            FROM Movimiento_BolsaTech__c
        ];

        GeneradorFacturasMBTApex.Request req = new GeneradorFacturasMBTApex.Request();
        req.mbtsSeleccionados = mbts;
        req.cultivoId = cultivo.Id;
        req.expedienteId = exp.Id;
        req.productorId = productor.Id;
        req.productorCuit = productor.N_CUIT__c;

        List<GeneradorFacturasMBTApex.Request> requests = new List<GeneradorFacturasMBTApex.Request>{ req };

        Test.startTest();
        List<List<TN_Regalia_Enlist__c>> resultados = GeneradorFacturasMBTApex.generar(requests);
        Test.stopTest();

        // Validaciones
        System.assertEquals(1, resultados.size(), 'Debe retornar 1 lista de respuestas.');
        List<TN_Regalia_Enlist__c> facturas = resultados[0];
        System.assertEquals(2, facturas.size(), 'Deberían haberse generado 2 facturas.');

        // Validación Factura 1
        TN_Regalia_Enlist__c fac1 = facturas[0];
        System.assertEquals('Enlist', fac1.Biotecnologia__c);
        System.assertEquals('A Facturar', fac1.Etapa__c);
        System.assertEquals('12345678', fac1.CTGs_Involucrados__c);

        // Validación Factura 2
        TN_Regalia_Enlist__c fac2 = facturas[1];
        System.assertEquals('87654321', fac2.CTGs_Involucrados__c);
    }

    @isTest
    static void testGenerarSinMBTs() {
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        Account productor = [SELECT Id, N_CUIT__c FROM Account WHERE Name = 'Productor Test' LIMIT 1];

        GeneradorFacturasMBTApex.Request req = new GeneradorFacturasMBTApex.Request();
        req.mbtsSeleccionados = new List<Movimiento_BolsaTech__c>();
        req.cultivoId = cultivo.Id;
        req.expedienteId = exp.Id;
        req.productorId = productor.Id;
        req.productorCuit = productor.N_CUIT__c;

        Test.startTest();
        List<List<TN_Regalia_Enlist__c>> resultados = GeneradorFacturasMBTApex.generar(new List<GeneradorFacturasMBTApex.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, resultados.size());
        System.assertEquals(0, resultados[0].size(), 'La lista de facturas generadas debe estar vacía.');
    }
}