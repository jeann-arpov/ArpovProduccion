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
            Fecha_de_Inicio__c = Date.today().addMonths(-2),
            SKEY_CAMPANIA__c = 8800004125L,
            Z9_Clave_Unica__c = 'CGV-TRIGO-2025',
            Id_Externo__c = 'CGV-TRIGO-2025'
        );
        insert campana;

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
        insert new List<Variedad__c>{ catalpa, donMario, araucaria, meteoro };

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
            tonelada(productor, cultivo, campana, cg, meteoro, 'Cesión HT', 10, -1)
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
                    aRegularizar += -variedad.saldo;
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
        System.assertEquals(500, porNombre.get('Don Mario CGV').credito, 'Compra SF positiva no se netea con la anulación');
        System.assertEquals(200, porNombre.get('Don Mario CGV').debito, 'Compra SF negativa es débito, no resta del crédito');
        System.assertEquals(300, porNombre.get('Don Mario CGV').saldo);
        System.assertEquals(0, porNombre.get('Don Mario CGV').entregas);
        // Saldo negativo sin entregas es Debe regularizar, no Sin entregas.
        System.assertEquals('Debe regularizar', porNombre.get('Meteoro CGV').estado);
        System.assertEquals(-10, porNombre.get('Meteoro CGV').saldo);
        System.assertEquals(0, porNombre.get('Meteoro CGV').entregas);

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
        System.assertEquals(0, CuentaGranaria.getRegularizarPorCampana(new List<Id>(), null).size());
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
            Etapa__c = 'Aplicada',
            Origen__c = origen,
            Variedad__c = variedad.Id,
            Cuenta_Granaria__c = cg.Id,
            No_asignar_campa_a__c = true
        );
    }
}
