@isTest
private class CuentaGranariaVarietalTest {

    @testSetup
    static void setup() {
        Test_TestUtils.disableFlows();

        Account productor = Test_TestUtils.crearProductor();
        Cultivo__c cultivo = new Cultivo__c(
            Name = 'TRIGO',
            Tipo_de_Especie__c = 'Autógama',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'TRIGO 2025 CGV',
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-14),
            Fecha_Inicio_SE__c = Date.today().addMonths(-14),
            Fecha_Fin_SE__c = Date.today().addDays(-2),
            SKEY_CAMPANIA__c = 8800004125L,
            Z9_Clave_Unica__c = 'CGV-TRIGO-2025',
            Id_Externo__c = 'CGV-TRIGO-2025'
        );
        Campana_Agricola__c campanaActual = new Campana_Agricola__c(
            Name = 'TRIGO 2026 CGV',
            Ano__c = '2026',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addDays(-1),
            Fecha_Inicio_SE__c = Date.today().addDays(-1),
            Fecha_Fin_SE__c = Date.today().addMonths(6),
            SKEY_CAMPANIA__c = 8800004126L,
            Z9_Clave_Unica__c = 'CGV-TRIGO-2026',
            Id_Externo__c = 'CGV-TRIGO-2026'
        );
        insert new List<Campana_Agricola__c>{ campana, campanaActual };

        RecordType tipoObtentor = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor'
            LIMIT 1
        ];
        Account alfa = new Account(
            Name = 'Semillero Alfa CGV',
            RecordTypeId = tipoObtentor.Id,
            Id_Obtentor__c = 'V1',
            Type = 'Obtentor',
            Nombre_Obtentor__c = 'Semillero Alfa CGV'
        );
        Account beta = new Account(
            Name = 'Semillero Beta CGV',
            RecordTypeId = tipoObtentor.Id,
            Id_Obtentor__c = 'V2',
            Type = 'Obtentor',
            Nombre_Obtentor__c = 'Semillero Beta CGV'
        );
        insert new List<Account>{ alfa, beta };

        Variedad__c catalpa = variedad('Catalpa CGV', alfa.Id);
        Variedad__c donMario = variedad('Don Mario CGV', beta.Id);
        Variedad__c araucaria = variedad('Araucaria CGV', alfa.Id);
        Variedad__c meteoro = variedad('Meteoro CGV', beta.Id);
        Variedad__c radal = variedad('Radal CGV', alfa.Id);
        radal.Cultivar_INASE__c = '460';
        insert new List<Variedad__c>{ catalpa, donMario, araucaria, meteoro, radal };

        Cuenta_Granaria__c cg = new Cuenta_Granaria__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Variedad__c = catalpa.Id,
            Tecnologia__c = 'RR1/RR2 - BT/Convencional',
            Saldo_Cuenta__c = 800,
            Clave_Unica__c = productor.Id + '|' + campana.Id + '|CGV'
        );
        insert cg;

        List<Tonelada__c> toneladas = new List<Tonelada__c>{
            tonelada(productor, cultivo, campana, cg, catalpa, 'Compra SF', 1000, 1),
            tonelada(productor, cultivo, campana, cg, catalpa, 'Compra HT', 400, 1),
            tonelada(productor, cultivo, campana, cg, catalpa, 'Cesión HT', 200, 1),
            tonelada(productor, cultivo, campana, cg, catalpa, 'BolsaTech', 800, -1),
            tonelada(productor, cultivo, campana, cg, donMario, 'Compra SF', 500, 1),
            tonelada(productor, cultivo, campana, cg, donMario, 'Compra SF', 200, -1),
            tonelada(productor, cultivo, campana, cg, araucaria, 'Compra SF', 100, 1),
            tonelada(productor, cultivo, campana, cg, araucaria, 'BolsaTech', 400, -1),
            tonelada(productor, cultivo, campana, cg, meteoro, 'Cesión HT', 10, -1),
            tonelada(productor, cultivo, campana, cg, radal, 'Cesión HT', 2, -1)
        };
        Tonelada__c pendiente = tonelada(productor, cultivo, campana, cg, donMario, 'Compra SF', 9999, 1);
        pendiente.Etapa__c = 'Pendiente';
        toneladas.add(pendiente);
        toneladas.add(tonelada(productor, cultivo, campana, cg, donMario, 'Balance Anual', 777, 1));
        insert toneladas;
    }

    @isTest
    static void agrupaMarcasYNoMuestraExpediente() {
        Account productor = [SELECT Id, Name, N_CUIT__c FROM Account WHERE Name = 'productor' ORDER BY CreatedDate DESC LIMIT 1];
        CrearCompraController.acc = productor;
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Z9_Clave_Unica__c = 'CGV-TRIGO-2025' LIMIT 1];
        CuentaGranaria.usarCreditoVarietalGuardado = false;

        Test.startTest();
        CuentaGranaria.ResumenVarietal resumen = CuentaGranaria.getResumenVarietal(campana.Id, 'RR1/RR2 - BT/Convencional');
        CuentaGranaria.DetalleVariedad detalle = CuentaGranaria.getDetalleVarietal(
            campana.Id,
            [SELECT Id FROM Variedad__c WHERE Name = 'Don Mario CGV' LIMIT 1].Id,
            'RR1/RR2 - BT/Convencional'
        );
        Test.stopTest();

        Map<String, CuentaGranaria.VariedadPortal> porNombre = new Map<String, CuentaGranaria.VariedadPortal>();
        Decimal aRegularizar = 0;
        for (CuentaGranaria.MarcaPortal marca : resumen.marcas) {
            for (CuentaGranaria.VariedadPortal variedad : marca.variedades) {
                porNombre.put(variedad.nombre, variedad);
                if (variedad.estado == 'Debe regularizar') {
                    aRegularizar += EstadoVarietal.toneladasMostradasARegularizar(variedad.credito, variedad.debito);
                }
            }
        }

        System.assertEquals(aRegularizar, resumen.toneladasARegularizar);
        AggregateResult ultimaFila = [
            SELECT MAX(Fecha_Inicio__c) ultima
            FROM Tonelada__c
            WHERE Campania__c = :campana.Id
                AND Origen__c IN ('BolsaTech', 'Escáner varietal')
        ];
        System.assertEquals((Date) ultimaFila.get('ultima'), resumen.ultimaEntrega);
        System.assertEquals('Sin entregas', porNombre.get('Don Mario CGV').estado);
        System.assertEquals(500, porNombre.get('Don Mario CGV').credito, 'Acreditado suma las compras; la anulación va al débito');
        System.assertEquals(200, porNombre.get('Don Mario CGV').debito, 'Anulación de Compra SF es débito (SE-157)');
        System.assertEquals(300, porNombre.get('Don Mario CGV').saldo);
        System.assertEquals(0, porNombre.get('Don Mario CGV').entregas);
        System.assertEquals('Debe regularizar', porNombre.get('Meteoro CGV').estado);
        System.assertEquals(0, porNombre.get('Meteoro CGV').credito, 'La cesión no resta en Acreditado');
        System.assertEquals(10, porNombre.get('Meteoro CGV').debito, 'Cesión saliente es débito (SE-350)');
        System.assertEquals(-10, porNombre.get('Meteoro CGV').saldo);
        System.assertEquals(0, porNombre.get('Meteoro CGV').entregas);
        System.assertEquals('Radal CGV', porNombre.get('Radal CGV').nombre, 'El portal usa el Name de Salesforce, no el INASE');
        System.assertEquals('Debe regularizar', porNombre.get('Radal CGV').estado, 'D-26: saldo −2 t es Entregaste de más');
        System.assertEquals(-2, porNombre.get('Radal CGV').saldo);
        System.assertEquals(0, porNombre.get('Radal CGV').credito);
        System.assertEquals(2, porNombre.get('Radal CGV').debito);
        System.assertEquals(true, porNombre.get('Meteoro CGV').tieneCesionSaliente, 'Cesión saliente sin entrega');
        System.assertEquals(true, porNombre.get('Radal CGV').tieneCesionSaliente, 'Cesión saliente sin entrega');
        System.assertEquals(false, porNombre.get('Catalpa CGV').tieneCesionSaliente, 'La cesión entrante no cuenta');
        System.assertEquals('Debe regularizar', porNombre.get('Araucaria CGV').estado);
        System.assertEquals(false, porNombre.get('Araucaria CGV').tieneCesionSaliente, 'Negativo solo por Bolsatech');
        System.assertNotEquals(0, porNombre.get('Araucaria CGV').entregas);

        CuentaGranaria.VariedadPortal catalpa = porNombre.get('Catalpa CGV');
        if (catalpa.entregas == 0) {
            System.assertEquals('Sin entregas', catalpa.estado);
        } else {
            System.assertEquals('En regla', catalpa.estado);
        }

        System.assertEquals('Sin entregas', detalle.estado);
        System.assertEquals(0, detalle.toneladasARegularizar);
        System.assertEquals(0, detalle.entregas.size());
        System.assertEquals(500, detalle.credito, 'La tarjeta de crédito suma las filas, no el neto');
        System.assertEquals(200, detalle.debito);
        System.assertEquals(500, detalle.totalCreditos);
        System.assertEquals(1, detalle.debitos.size());
        Boolean encontroCredito = false;
        for (CuentaGranaria.MovimientoPortal mov : detalle.creditos) {
            if (mov.origen == 'Semilla Fiscalizada' && mov.toneladas == 500) {
                encontroCredito = true;
            }
        }
        System.assertEquals(true, encontroCredito);

        CuentaGranaria.DetalleVariedad cesion = CuentaGranaria.getDetalleVarietal(
            campana.Id,
            [SELECT Id FROM Variedad__c WHERE Name = 'Meteoro CGV' LIMIT 1].Id,
            'RR1/RR2 - BT/Convencional'
        );
        System.assertEquals(0, cesion.creditos.size(), 'La cesión saliente no va en créditos');
        System.assertEquals(0, cesion.totalCreditos);
        System.assertEquals(1, cesion.debitos.size());
        System.assertEquals('Cesión a otro productor', cesion.debitos[0].origen);
        System.assertEquals(-10, cesion.debitos[0].toneladas);
        System.assertEquals(-2.5, cesion.debitos[0].ht, '1 HT = 4 t, sin redondear');
        System.assertEquals(true, cesion.tieneCesionSaliente);
        System.assertEquals(10, cesion.debito);
        System.assertEquals(0, cesion.credito);

        List<CuentaGranaria.MovimientoPortal> entregas = CuentaGranaria.getEntregasVarietal(
            campana.Id,
            'RR1/RR2 - BT/Convencional'
        );
        System.assertNotEquals(null, entregas);

        Map<Id, CuentaGranaria.RegularizarCampana> porCampana = CuentaGranaria.getRegularizarPorCampana(
            new List<Id>{ campana.Id },
            'RR1/RR2 - BT/Convencional'
        );
        CuentaGranaria.RegularizarCampana regularizar = porCampana.get(campana.Id);
        System.assertNotEquals(null, regularizar);
        System.assertEquals(resumen.toneladasARegularizar, regularizar.toneladas);
        System.assert(regularizar.variedades.contains('Meteoro CGV'));
        System.assert(regularizar.variedades.contains('Radal CGV'), 'D-26: −2 t entra al total del bloque oscuro');
        System.assertEquals(0, CuentaGranaria.getRegularizarPorCampana(new List<Id>(), null).size());
    }

    @isTest
    static void usaCreditoGuardadoDeDetalle() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' ORDER BY CreatedDate DESC LIMIT 1];
        CrearCompraController.acc = productor;
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Z9_Clave_Unica__c = 'CGV-TRIGO-2025' LIMIT 1];
        Variedad__c donMario = [SELECT Id FROM Variedad__c WHERE Name = 'Don Mario CGV' LIMIT 1];
        Variedad__c meteoro = [SELECT Id FROM Variedad__c WHERE Name = 'Meteoro CGV' LIMIT 1];
        Cuenta_Granaria__c cg = [SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c = :campana.Id LIMIT 1];
        Schema.SObjectType tipoDetalle = Schema.getGlobalDescribe().get('Detalle_Variedad_CG__c');
        if (tipoDetalle == null) {
            return;
        }
        Boolean usaSaldo = tipoDetalle.getDescribe().fields.getMap().containsKey('Saldo_Variedad__c');
        CuentaGranaria.usarCreditoVarietalGuardado = true;

        SObject donMarioDetalle = tipoDetalle.newSObject();
        donMarioDetalle.put('Cuenta_Granaria__c', cg.Id);
        donMarioDetalle.put('Variedad__c', donMario.Id);
        donMarioDetalle.put('Credito_Variedad__c', 48);
        donMarioDetalle.put('Clave_Varietal__c', String.valueOf(cg.Id) + '|' + String.valueOf(donMario.Id));
        SObject meteoroDetalle = tipoDetalle.newSObject();
        meteoroDetalle.put('Cuenta_Granaria__c', cg.Id);
        meteoroDetalle.put('Variedad__c', meteoro.Id);
        meteoroDetalle.put('Credito_Variedad__c', -10);
        meteoroDetalle.put('Clave_Varietal__c', String.valueOf(cg.Id) + '|' + String.valueOf(meteoro.Id));
        if (usaSaldo) {
            donMarioDetalle.put('Saldo_Variedad__c', 33);
            meteoroDetalle.put('Saldo_Variedad__c', -25);
        }
        insert new List<SObject>{ donMarioDetalle, meteoroDetalle };

        Test.startTest();
        CuentaGranaria.ResumenVarietal resumen = CuentaGranaria.getResumenVarietal(campana.Id, 'RR1/RR2 - BT/Convencional');
        CuentaGranaria.DetalleVariedad detalle = CuentaGranaria.getDetalleVarietal(
            campana.Id,
            donMario.Id,
            'RR1/RR2 - BT/Convencional'
        );
        Map<Id, CuentaGranaria.RegularizarCampana> porCampana = CuentaGranaria.getRegularizarPorCampana(
            new List<Id>{ campana.Id },
            'RR1/RR2 - BT/Convencional'
        );
        Test.stopTest();

        CuentaGranaria.VariedadPortal donMarioPortal;
        for (CuentaGranaria.MarcaPortal marca : resumen.marcas) {
            for (CuentaGranaria.VariedadPortal variedad : marca.variedades) {
                if (variedad.nombre == 'Don Mario CGV') {
                    donMarioPortal = variedad;
                }
            }
        }
        System.assertNotEquals(null, donMarioPortal);
        System.assertEquals(48, donMarioPortal.credito);
        System.assertEquals(500, detalle.credito, 'El detalle cierra con las filas, no con el crédito guardado');
        System.assertEquals(200, detalle.debito);
        System.assertEquals(300, detalle.saldo);
        System.assertNotEquals(null, porCampana.get(campana.Id));
        System.assert(porCampana.get(campana.Id).variedades.contains('Meteoro CGV'));
        CuentaGranaria.VariedadPortal meteoroPortal;
        for (CuentaGranaria.MarcaPortal marca : resumen.marcas) {
            for (CuentaGranaria.VariedadPortal variedad : marca.variedades) {
                if (variedad.nombre == 'Meteoro CGV') {
                    meteoroPortal = variedad;
                }
            }
        }
        System.assertEquals(true, meteoroPortal.tieneCesionSaliente, 'El crédito guardado también marca la cesión saliente');
        if (usaSaldo) {
            System.assertEquals(15, donMarioPortal.debito, 'Débito = Crédito − Saldo_Variedad, no la anulación de toneladas');
            System.assertEquals(33, donMarioPortal.saldo);
            System.assertEquals(15, meteoroPortal.debito);
            System.assertEquals(-25, meteoroPortal.saldo);
            System.assertEquals(false, porCampana.get(campana.Id).variedades.contains('Don Mario CGV'));
        } else {
            System.assertEquals(200, donMarioPortal.debito, 'Sin Saldo_Variedad el débito sigue saliendo de las toneladas negativas');
            System.assertEquals(-152, donMarioPortal.saldo);
            System.assert(porCampana.get(campana.Id).variedades.contains('Don Mario CGV'));
        }
    }

    @isTest
    static void negativoMixtoMarcaCesionYEntrega() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' ORDER BY CreatedDate DESC LIMIT 1];
        CrearCompraController.acc = productor;
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Z9_Clave_Unica__c = 'CGV-TRIGO-2025' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'TRIGO' ORDER BY CreatedDate DESC LIMIT 1];
        Cuenta_Granaria__c cg = [SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c = :campana.Id LIMIT 1];
        Variedad__c radal = [SELECT Id FROM Variedad__c WHERE Name = 'Radal CGV' LIMIT 1];
        CuentaGranaria.usarCreditoVarietalGuardado = false;
        insert tonelada(productor, cultivo, campana, cg, radal, 'BolsaTech', 8, -1);

        Test.startTest();
        CuentaGranaria.ResumenVarietal resumen = CuentaGranaria.getResumenVarietal(campana.Id, 'RR1/RR2 - BT/Convencional');
        Test.stopTest();

        CuentaGranaria.VariedadPortal radalPortal;
        for (CuentaGranaria.MarcaPortal marca : resumen.marcas) {
            for (CuentaGranaria.VariedadPortal variedad : marca.variedades) {
                if (variedad.nombre == 'Radal CGV') {
                    radalPortal = variedad;
                }
            }
        }
        System.assertNotEquals(null, radalPortal);
        System.assertEquals('Debe regularizar', radalPortal.estado);
        System.assertEquals(true, radalPortal.tieneCesionSaliente);
        System.assertNotEquals(0, radalPortal.entregas);
    }

    @isTest
    static void creditosUsaFechaDeCreacionYOrden() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' ORDER BY CreatedDate DESC LIMIT 1];
        CrearCompraController.acc = productor;
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Z9_Clave_Unica__c = 'CGV-TRIGO-2025' LIMIT 1];
        Variedad__c catalpa = [SELECT Id FROM Variedad__c WHERE Name = 'Catalpa CGV' LIMIT 1];
        CuentaGranaria.usarCreditoVarietalGuardado = false;

        Tonelada__c compraSf = [
            SELECT Id, CreatedDate, Fecha_Inicio__c
            FROM Tonelada__c
            WHERE Variedad__c = :catalpa.Id
                AND Origen__c = 'Compra SF'
                AND Cantidad_con_Signo__c > 0
            LIMIT 1
        ];

        Test.startTest();
        CuentaGranaria.DetalleVariedad detalle = CuentaGranaria.getDetalleVarietal(
            campana.Id,
            catalpa.Id,
            'RR1/RR2 - BT/Convencional'
        );
        Test.stopTest();

        CuentaGranaria.MovimientoPortal creditoSf;
        for (CuentaGranaria.MovimientoPortal mov : detalle.creditos) {
            if (mov.origen == 'Semilla Fiscalizada' && mov.toneladas == 1000) {
                creditoSf = mov;
            }
        }
        System.assertNotEquals(null, creditoSf);
        System.assertEquals(compraSf.CreatedDate.date(), creditoSf.fecha, 'La lista usa la fecha de creación');
        System.assertNotEquals(compraSf.Fecha_Inicio__c, creditoSf.fecha, 'No usa Fecha Inicio de la vigencia');
    }

    @isTest
    static void creditoDesdeHtSinTonelada() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' ORDER BY CreatedDate DESC LIMIT 1];
        CrearCompraController.acc = productor;
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Z9_Clave_Unica__c = 'CGV-TRIGO-2025' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'TRIGO' ORDER BY CreatedDate DESC LIMIT 1];
        Variedad__c tipa = variedad('Tipa HT CGV', [
            SELECT Id FROM Account WHERE Nombre_Obtentor__c = 'Semillero Alfa CGV' LIMIT 1
        ].Id);
        insert tipa;
        CuentaGranaria.usarCreditoVarietalGuardado = false;

        insert new Hectareas_Tecnologicas__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Variedad__c = tipa.Id,
            Origen__c = 'Compra HT',
            Signo__c = 1,
            Etapa__c = 'Cobrada',
            Cantidad__c = 5,
            Valor_Conversion__c = 4000,
            Biotecnologia__c = 'Convencional',
            Fecha_Inicio__c = Date.today().addDays(-5),
            Fecha_Fin__c = Date.today().addDays(300)
        );

        Test.startTest();
        CuentaGranaria.ResumenVarietal resumen = CuentaGranaria.getResumenVarietal(
            campana.Id,
            'RR1/RR2 - BT/Convencional'
        );
        CuentaGranaria.DetalleVariedad detalle = CuentaGranaria.getDetalleVarietal(
            campana.Id,
            tipa.Id,
            'RR1/RR2 - BT/Convencional'
        );
        Test.stopTest();

        CuentaGranaria.VariedadPortal tipaPortal;
        for (CuentaGranaria.MarcaPortal marca : resumen.marcas) {
            for (CuentaGranaria.VariedadPortal variedad : marca.variedades) {
                if (variedad.nombre == 'Tipa HT CGV') {
                    tipaPortal = variedad;
                }
            }
        }
        System.assertNotEquals(null, tipaPortal, 'La variedad aparece aunque no tenga tonelada');
        System.assertEquals(20, tipaPortal.credito, '5 HT cobradas = 20 t sin pasar por SE-410');
        System.assertEquals(20, detalle.credito);
        System.assertEquals(1, detalle.creditos.size());
        System.assertEquals('Compra de HT', detalle.creditos[0].origen);
    }

    @isTest
    static void cp01VistaIgnoraCanceladaYNcAplicada() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' ORDER BY CreatedDate DESC LIMIT 1];
        CrearCompraController.acc = productor;
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Z9_Clave_Unica__c = 'CGV-TRIGO-2025' LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'TRIGO' ORDER BY CreatedDate DESC LIMIT 1];
        Cuenta_Granaria__c cg = [SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c = :campana.Id LIMIT 1];
        Account alfa = [SELECT Id FROM Account WHERE Nombre_Obtentor__c = 'Semillero Alfa CGV' LIMIT 1];
        Variedad__c tipa = variedad('TIPA CP01 Vista', alfa.Id);
        Variedad__c radalCp = variedad('RADAL CP01 Vista', alfa.Id);
        insert new List<Variedad__c>{ tipa, radalCp };
        CuentaGranaria.usarCreditoVarietalGuardado = false;

        Tonelada__c cancelada1 = tonelada(productor, cultivo, campana, cg, tipa, 'Compra HT', 20, 1);
        cancelada1.Etapa__c = 'Cancelada por NC';
        Tonelada__c cancelada2 = tonelada(productor, cultivo, campana, cg, tipa, 'Compra HT', 20, 1);
        cancelada2.Etapa__c = 'Cancelada por NC';
        Tonelada__c cancelada3 = tonelada(productor, cultivo, campana, cg, tipa, 'Compra HT', 20, 1);
        cancelada3.Etapa__c = 'Cancelada por NC';
        Tonelada__c nc1 = tonelada(productor, cultivo, campana, cg, tipa, 'Compra HT', 20, -1);
        nc1.Etapa__c = 'Aplicada';
        Tonelada__c nc2 = tonelada(productor, cultivo, campana, cg, tipa, 'Compra HT', 20, -1);
        nc2.Etapa__c = 'Aplicada';
        insert new List<Tonelada__c>{
            cancelada1,
            cancelada2,
            cancelada3,
            nc1,
            nc2,
            tonelada(productor, cultivo, campana, cg, radalCp, 'Compra HT', 20, 1)
        };

        Test.startTest();
        CuentaGranaria.ResumenVarietal resumen = CuentaGranaria.getResumenVarietal(
            campana.Id,
            'RR1/RR2 - BT/Convencional'
        );
        CuentaGranaria.DetalleVariedad detalle = CuentaGranaria.getDetalleVarietal(
            campana.Id,
            tipa.Id,
            'RR1/RR2 - BT/Convencional'
        );
        Test.stopTest();

        Map<String, CuentaGranaria.VariedadPortal> porNombre = new Map<String, CuentaGranaria.VariedadPortal>();
        for (CuentaGranaria.MarcaPortal marca : resumen.marcas) {
            for (CuentaGranaria.VariedadPortal variedad : marca.variedades) {
                porNombre.put(variedad.nombre, variedad);
            }
        }
        System.assertEquals(0, porNombre.get('TIPA CP01 Vista').credito, 'CP-01: Cancelada por NC y NC Aplicada no acreditan');
        System.assertEquals(0, porNombre.get('TIPA CP01 Vista').debito);
        System.assertEquals(0, porNombre.get('TIPA CP01 Vista').saldo);
        System.assertEquals(0, detalle.credito);
        System.assertEquals(0, detalle.debito);
        System.assertEquals(20, porNombre.get('RADAL CP01 Vista').credito, 'La compra Cobrada sigue acreditando');
    }

    @isTest
    static void rechazaSinCampana() {
        Boolean lanzo = false;
        try {
            CuentaGranaria.getResumenVarietal(null, null);
        } catch (AuraHandledException ex) {
            lanzo = true;
            System.assert(ex.getMessage().contains('campaña'));
        }
        System.assertEquals(true, lanzo);
    }

    private static Variedad__c variedad(String nombre, Id obtentorId) {
        return new Variedad__c(
            Name = nombre,
            Biotecnologia__c = 'Convencional',
            Sembra_Evolucion__c = true,
            Obtentor_Comercializa__c = obtentorId
        );
    }

    private static Tonelada__c tonelada(
        Account productor,
        Cultivo__c cultivo,
        Campana_Agricola__c campana,
        Cuenta_Granaria__c cg,
        Variedad__c variedad,
        String origen,
        Decimal cantidad,
        Integer signo
    ) {
        return new Tonelada__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'Convencional',
            Cantidad__c = cantidad,
            Signo__c = signo,
            Fecha_Inicio__c = Date.today().addDays(-10),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = (origen == 'Compra HT' || origen == 'Compra SF') ? 'Cobrada' : 'Aplicada',
            Origen__c = origen,
            Variedad__c = variedad.Id,
            Cuenta_Granaria__c = cg.Id,
            No_asignar_campa_a__c = true
        );
    }
}
