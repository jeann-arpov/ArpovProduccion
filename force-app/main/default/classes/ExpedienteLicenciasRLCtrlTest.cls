@IsTest
private class ExpedienteLicenciasRLCtrlTest {
    /** Aísla datos del setup frente a otras clases de test en paralelo (deploy/prod). */
    private static final String CAMPANIA_SETUP_NAME = 'SOJA 2025 EXP-LIC';
    private static final String LICENCIA_NAME_PREFIX = 'LIC-PAG-';
    private static final String EXPEDIENTE_EMAIL_MARCADOR = 'expediente_licencias_rl_ctrl_test_only@invalid.test';

    private static Id idExpedienteSetup() {
        List<Expediente_de_Negativos__c> rows = [
            SELECT Id
            FROM Expediente_de_Negativos__c
            WHERE Email__c = :EXPEDIENTE_EMAIL_MARCADOR
            LIMIT 1
        ];
        System.assertEquals(1, rows.size(), 'Expediente del @TestSetup no encontrado por Email__c marcador');
        return rows[0].Id;
    }

    @TestSetup
    static void setupData() {
        Test_TestUtils.disableFlows();

        Account productor = Test_TestUtils.crearProductor();
        Account distribuidor = Test_TestUtils.crearDistribuidor();
        distribuidor.N_CUIT__c = productor.N_CUIT__c;
        update distribuidor;

        Account obtentor = Test_TestUtils.crearObtentor();

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Tipo_de_Especie__c = 'SOJA',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c campania = new Campana_Agricola__c(
            Name = CAMPANIA_SETUP_NAME,
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-2),
            Fecha_de_Fin__c = Date.today().addMonths(8)
        );
        insert campania;

        Cuenta_Granaria__c cg = new Cuenta_Granaria__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campania.Id,
            Tecnologia__c = 'Enlist E3/Conkesta E3',
            Saldo_Cuenta__c = -5,
            Clave_Unica__c = productor.Id + '|' + campania.Id + '|' + cultivo.Id + '|Enlist E3/Conkesta E3'
        );
        insert cg;

        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c(
            Campania__c = campania.Id,
            Cuenta__c = productor.Id,
            Cuenta_Granaria__c = cg.Id,
            Email__c = EXPEDIENTE_EMAIL_MARCADOR,
            Saldo_Previo_al_Expediente__c = -5,
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today()
        );
        insert expediente;

        List<Licencia__c> licencias = new List<Licencia__c>();
        for (Integer i = 1; i <= 12; i++) {
            licencias.add(
                new Licencia__c(
                    Name = LICENCIA_NAME_PREFIX + i,
                    Created__c = Date.today().addDays(-i),
                    Cuenta_Productor__c = productor.Id,
                    Cuenta_Obtentor__c = obtentor.Id,
                    Cuenta_Distribuidor__c = distribuidor.Id,
                    Tipo_de_Licencia__c = 'Productor',
                    Tecnologia__c = 'Enlist',
                    Estado__c = 'Aprobada',
                    Fecha_de_Vencimiento__c = Date.today().addYears(1),
                    Direccion_Fiscal_Firmante__c = 'Calle Test ' + i,
                    Email__c = 'licencia' + i + '@test.com',
                    Firmante_Celular__c = '1111111111',
                    Carta_de_Aceptacion_Firmada__c = true
                )
            );
        }
        insert licencias;

        // Algunas orgs disparan triggers al insertar Licencia__c que vuelven a fijar N_CUIT del distribuidor;
        // el controlador matchea expediente (CUIT del productor) vs Cuenta_Distribuidor__r.N_CUIT__c.
        Account distPostLic = [SELECT Id FROM Account WHERE Id = :distribuidor.Id];
        distPostLic.N_CUIT__c = productor.N_CUIT__c;
        update distPostLic;
    }

    @IsTest
    static void nullId_returnsEmpty() {
        ExpedienteLicenciasRelatedListController.RelatedListResponse res = ExpedienteLicenciasRelatedListController.getLicenciasForExpediente(
            null,
            1,
            10
        );
        System.assertEquals(0, res.licencias.size(), 'Sin Id no debe devolver filas');
        System.assertEquals(0, res.totalRecords, 'Total en cero');
        System.assertEquals('expedienteId=null', res.diagnostico);
    }

    @IsTest
    static void idQueNoEsExpediente_devuelveError() {
        ExpedienteLicenciasRelatedListController.RelatedListResponse res = ExpedienteLicenciasRelatedListController.getLicenciasForExpediente(
            UserInfo.getUserId(),
            1,
            10
        );
        System.assertEquals('No se encontró el expediente.', res.errorMessage);
        System.assertEquals(0, res.totalRecords);
    }

    @IsTest
    static void pagination_defaults_y_tope_pageSize() {
        Id expId = idExpedienteSetup();

        ExpedienteLicenciasRelatedListController.RelatedListResponse d = ExpedienteLicenciasRelatedListController.getLicenciasForExpediente(
            expId,
            null,
            null
        );
        System.assertEquals(1, d.pageNumber);
        System.assertEquals(10, d.pageSize);

        ExpedienteLicenciasRelatedListController.RelatedListResponse bad = ExpedienteLicenciasRelatedListController.getLicenciasForExpediente(
            expId,
            0,
            -1
        );
        System.assertEquals(1, bad.pageNumber);
        System.assertEquals(10, bad.pageSize);

        ExpedienteLicenciasRelatedListController.RelatedListResponse cap = ExpedienteLicenciasRelatedListController.getLicenciasForExpediente(
            expId,
            1,
            500
        );
        System.assertEquals(100, cap.pageSize);
    }

    @IsTest
    static void expediente_matchea_licencias_por_cuit_distribuidor() {
        Id expId = idExpedienteSetup();
        String licNameLike = LICENCIA_NAME_PREFIX + '%';

        // Re-aplicar estado por si triggers en la org lo cambiaron al insertar (solo licencias de este test)
        List<Licencia__c> licUp = new List<Licencia__c>();
        for (Licencia__c l : [SELECT Id FROM Licencia__c WHERE Name LIKE :licNameLike]) {
            licUp.add(
                new Licencia__c(
                    Id = l.Id,
                    Estado__c = 'Aprobada',
                    Fecha_de_Vencimiento__c = Date.today().addYears(1)
                )
            );
        }
        update licUp;

        System.assertEquals(
            12,
            [
                SELECT COUNT()
                FROM Licencia__c
                WHERE Estado__c = 'Aprobada' AND Name LIKE :licNameLike
            ],
            'Setup: deben quedar 12 licencias aprobadas'
        );

        Expediente_de_Negativos__c ex = [
            SELECT Id, CUIT_cliente__c, Cuenta__r.N_CUIT__c
            FROM Expediente_de_Negativos__c
            WHERE Id = :expId
        ];
        System.assert(
            String.isNotBlank(ex.CUIT_cliente__c),
            'CUIT_cliente__c (fórmula Cuenta__r.N_CUIT__c) no debe quedar vacío'
        );
        System.assertEquals(
            ex.Cuenta__r.N_CUIT__c,
            ex.CUIT_cliente__c,
            'Fórmula CUIT_cliente__c debe coincidir con N_CUIT del productor'
        );
        Licencia__c licEj = [
            SELECT Cuenta_Distribuidor__r.N_CUIT__c
            FROM Licencia__c
            WHERE Name = :LICENCIA_NAME_PREFIX + '1'
            LIMIT 1
        ];
        System.assertEquals(
            ex.CUIT_cliente__c,
            licEj.Cuenta_Distribuidor__r.N_CUIT__c,
            'Distribuidor de la licencia debe compartir CUIT con expediente (mismo match que el controlador)'
        );

        String cuitCliente = ex.CUIT_cliente__c.trim();
        Integer countComoControlador = Database.countQuery(
            'SELECT COUNT() FROM Licencia__c WHERE Estado__c = \'Aprobada\' AND Name LIKE :licNameLike' +
                ' AND N_CUIT__c = :cuitCliente AND Tecnologia__c = \'Enlist\' AND Tipo_de_Licencia__c = \'Productor\''
        );
        System.assertEquals(
            12,
            countComoControlador,
            'El WHERE de CUIT debe devolver 12 filas (misma lógica que ExpedienteLicenciasRelatedListController)'
        );

        // pageSize 11 (no 10) para no reutilizar la misma clave de caché que pagination_defaults (cacheable=true + mismos args)
        Test.startTest();
        ExpedienteLicenciasRelatedListController.RelatedListResponse p1 = ExpedienteLicenciasRelatedListController.getLicenciasForExpediente(
            expId,
            1,
            11
        );
        ExpedienteLicenciasRelatedListController.RelatedListResponse p2 = ExpedienteLicenciasRelatedListController.getLicenciasForExpediente(
            expId,
            2,
            11
        );
        Test.stopTest();

        System.assert(String.isBlank(p1.errorMessage), 'No debe haber error: ' + p1.errorMessage);
        System.assertEquals(12, p1.totalRecords, 'Debe contar las 12 licencias');
        System.assertEquals(2, p1.totalPages, 'Con tamaño 11 son 2 páginas');
        System.assertEquals(11, p1.licencias.size(), 'Primera página: 11 filas');
        System.assertEquals(1, p2.licencias.size(), 'Segunda página: 1 fila');
    }

    @IsTest
    static void getLicencias_ajusta_numero_de_pagina_si_excede_total() {
        Id expId = idExpedienteSetup();
        Test.startTest();
        ExpedienteLicenciasRelatedListController.RelatedListResponse r = ExpedienteLicenciasRelatedListController.getLicenciasForExpediente(
            expId,
            999,
            10
        );
        Test.stopTest();
        System.assert(String.isBlank(r.errorMessage), r.errorMessage);
        System.assert(r.totalRecords > 0, 'Setup debe tener licencias para probar el tope de página');
        System.assertEquals(r.totalPages, r.pageNumber, 'Si pide página 999 debe quedar en la última');
        System.assertEquals(2, r.licencias.size(), 'Última página con total 12 y tamaño 10: 2 filas');
    }
}