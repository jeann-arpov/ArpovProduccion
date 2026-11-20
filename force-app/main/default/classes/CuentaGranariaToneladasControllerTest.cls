@isTest
private class CuentaGranariaToneladasControllerTest {

    @testSetup
    static void setup() {
        Test_TestUtils.disableFlows();

        Account prod = Test_TestUtils.crearProductor();

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Tipo_de_Especie__c = 'SOJA',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'SOJA 2025',
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-3)
        );
        insert campana;

        // Cuenta Granaria regular (con campaña)
        Cuenta_Granaria__c cgRegular = new Cuenta_Granaria__c(
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Tecnologia__c = 'Enlist E3/Conkesta E3',
            Saldo_Cuenta__c = 150,
            Clave_Unica__c = prod.Id + '|' + campana.Id + '|' + cultivo.Id + '|Enlist E3/Conkesta E3'
        );
        insert cgRegular;

        // Cuenta Granaria HT (sin campaña)
        Cuenta_Granaria__c cgHT = new Cuenta_Granaria__c(
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Tecnologia__c = 'Enlist E3/Conkesta E3',
            Saldo_Cuenta__c = 200,
            Clave_Unica__c = prod.Id + '||' + cultivo.Id + '|Enlist E3/Conkesta E3'
        );
        insert cgHT;

        // Toneladas positivas para la cuenta regular
        List<Tonelada__c> toneladas = new List<Tonelada__c>();
        toneladas.add(new Tonelada__c(
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'Enlist E3',
            Cantidad__c = 100,
            Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-10),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF',
            Cuenta_Granaria__c = cgRegular.Id
        ));
        toneladas.add(new Tonelada__c(
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'Enlist E3',
            Cantidad__c = 50,
            Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-5),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF',
            Cuenta_Granaria__c = cgRegular.Id
        ));
        // Tonelada negativa
        toneladas.add(new Tonelada__c(
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'Enlist E3',
            Cantidad__c = 30,
            Signo__c = -1,
            Fecha_Inicio__c = Date.today().addDays(-2),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'BolsaTech',
            Cuenta_Granaria__c = cgRegular.Id
        ));
        insert toneladas;
    }

    @isTest
    static void testGetToneladasCuentaRegular() {
        Cuenta_Granaria__c cg = [SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c != null LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = CuentaGranariaToneladasController.getToneladas(cg.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);

        List<Tonelada__c> esperadas = [
            SELECT Cantidad_con_Signo__c
            FROM Tonelada__c
            WHERE Cuenta_Granaria__c = :cg.Id
                AND Fecha_Inicio__c <= TODAY
                AND Etapa__c != 'Pendiente'
                AND Origen__c != 'Balance Anual'
        ];
        Decimal totalEsperado = 0;
        Decimal positivoEsperado = 0;
        Decimal negativoEsperado = 0;
        for (Tonelada__c tn : esperadas) {
            Decimal cantidad = tn.Cantidad_con_Signo__c == null ? 0 : tn.Cantidad_con_Signo__c;
            totalEsperado += cantidad;
            if (cantidad >= 0) {
                positivoEsperado += cantidad;
            } else {
                negativoEsperado += cantidad;
            }
        }

        List<Object> toneladas = (List<Object>) result.get('toneladas');
        System.assertEquals(esperadas.size(), toneladas.size(), 'Debe listar las toneladas vigentes');
        System.assertEquals(totalEsperado, (Decimal) result.get('total'));
        System.assertEquals(positivoEsperado, (Decimal) result.get('totalPositivo'));
        System.assertEquals(negativoEsperado, (Decimal) result.get('totalNegativo'));

        // Info de cuenta
        Map<String, Object> cuenta = (Map<String, Object>) result.get('cuenta');
        System.assertNotEquals(null, cuenta);
        System.assertEquals(false, cuenta.get('esCompraHT'), 'No debe ser Compra HT');
    }

    @isTest
    static void testGetToneladasCuentaHT() {
        Cuenta_Granaria__c cg = [SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c = null LIMIT 1];
        
        Test.startTest();
        Map<String, Object> result = CuentaGranariaToneladasController.getToneladas(cg.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);

        Map<String, Object> cuenta = (Map<String, Object>) result.get('cuenta');
        System.assertEquals(true, cuenta.get('esCompraHT'), 'Debe ser Compra HT');

        // Debe tener cuentas relacionadas (la cuenta regular)
        List<Object> cuentasRelacionadas = (List<Object>) cuenta.get('cuentasRelacionadas');
        System.assertNotEquals(null, cuentasRelacionadas);
        System.assert(cuentasRelacionadas.size() > 0, 'Debe tener cuentas relacionadas');
    }

    @isTest
    static void testGetToneladasSinToneladas() {
        Account prod = [SELECT Id FROM Account LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];

        Cuenta_Granaria__c cgVacia = new Cuenta_Granaria__c(
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Tecnologia__c = 'RR1/RR2 - BT/Convencional',
            Saldo_Cuenta__c = 0,
            Clave_Unica__c = prod.Id + '||' + cultivo.Id + '|RR1/RR2 - BT/Convencional'
        );
        insert cgVacia;

        Test.startTest();
        Map<String, Object> result = CuentaGranariaToneladasController.getToneladas(cgVacia.Id);
        Test.stopTest();

        List<Object> toneladas = (List<Object>) result.get('toneladas');
        System.assertEquals(0, toneladas.size(), 'No debe tener toneladas');
        System.assertEquals(0, (Decimal) result.get('total'));
    }

    @isTest
    static void testPuedeGenerarConsumoCargaManualNegativa() {
        Cuenta_Granaria__c cgRegular = [
            SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c != null LIMIT 1
        ];
        Cuenta_Granaria__c cgHT = [
            SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c = null LIMIT 1
        ];

        cgRegular.Es_Carga_Manual__c = true;
        cgRegular.Saldo_Cuenta__c = -40;
        cgHT.Saldo_Cuenta__c = 100;
        update new List<Cuenta_Granaria__c>{ cgRegular, cgHT };

        Test.startTest();
        Map<String, Object> result = CuentaGranariaToneladasController.getToneladas(cgRegular.Id);
        Test.stopTest();

        Map<String, Object> cuenta = (Map<String, Object>) result.get('cuenta');
        System.assertEquals(true, cuenta.get('esCargaManual'));
        System.assertEquals(true, cuenta.get('puedeGenerarConsumo'));
    }

    @isTest
    static void testGenerarConsumoHTRechazaCuentaNoManual() {
        Cuenta_Granaria__c cgRegular = [
            SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c != null LIMIT 1
        ];
        cgRegular.Saldo_Cuenta__c = -40;
        update cgRegular;

        Boolean errorLanzado = false;
        Test.startTest();
        try {
            CuentaGranariaToneladasController.generarConsumoHT(cgRegular.Id);
        } catch (AuraHandledException e) {
            errorLanzado = true;
        }
        Test.stopTest();

        System.assertEquals(true, errorLanzado, 'Debe rechazar cuentas que no son carga manual');
    }

    @isTest
    static void testGenerarConsumoHTCargaManual() {
        Account prod = [SELECT Id FROM Account LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c LIMIT 1];

        Cuenta_Granaria__c cgRegular = [
            SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c != null LIMIT 1
        ];
        Cuenta_Granaria__c cgHT = [
            SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c = null LIMIT 1
        ];

        cgRegular.Es_Carga_Manual__c = true;
        cgRegular.Saldo_Cuenta__c = -30;
        cgHT.Saldo_Cuenta__c = 100;
        update new List<Cuenta_Granaria__c>{ cgRegular, cgHT };

        RecordType rtObtentor = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor'
            LIMIT 1
        ];
        Account obtentor = new Account(
            Name = 'Obt Consumo Test',
            RecordTypeId = rtObtentor.Id,
            Id_Obtentor__c = '88',
            Type = 'Obtentor',
            Nombre_Obtentor__c = 'Obt Consumo Test'
        );
        insert obtentor;

        Variedad__c variedad = new Variedad__c(
            Name = 'Var Consumo Test',
            Biotecnologia__c = 'Enlist E3',
            Sembra_Evolucion__c = true,
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert variedad;

        Product2 producto = new Product2(
            Name = 'Prod Consumo Test',
            IsActive = true,
            Cultivo__c = cultivo.Id,
            Variedad__c = variedad.Id,
            Variedad2__c = variedad.Id
        );
        insert producto;

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = producto.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert entry;

        Compra_HT__c compra = new Compra_HT__c(
            Lista_de_Precios__c = Test.getStandardPricebookId(),
            Cuenta_Productor__c = prod.Id,
            Estado__c = 'Creada'
        );
        insert compra;

        Licencia__c licencia = new Licencia__c(
            Cuenta_Obtentor__c = obtentor.Id,
            Estado__c = 'Aprobada'
        );
        insert licencia;

        Linea_de_Compra_HT__c linea = new Linea_de_Compra_HT__c(
            Cantidad__c = 50,
            Precio_de_Lista__c = 10,
            Compra_HT__c = compra.Id,
            Estado__c = 'Creada',
            Licencia__c = licencia.Id,
            Tipo_de_cambio__c = 14,
            Tipo_de_Compra__c = 'Disponible',
            Id_Producto_de_Lista_de_Precio__c = entry.Id
        );
        insert linea;

        Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c(
            Linea_de_Compra_HT__c = linea.Id,
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Variedad__c = variedad.Id,
            Biotecnologia__c = 'Enlist E3',
            Cantidad__c = 50,
            Signo__c = 1,
            Origen__c = 'Compra HT',
            Valor_Conversion__c = 3000
        );
        insert ht;

        Tonelada__c loteHT = new Tonelada__c(
            HT_Id__c = ht.Id,
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'Enlist E3',
            Cantidad__c = 50,
            Signo__c = 1,
            Origen__c = 'Compra HT',
            Fecha_Inicio__c = Date.today().addDays(-5),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Cobrada',
            Variedad__c = variedad.Id,
            N_CUIT__c = '20301234567',
            Cuenta_Granaria__c = cgHT.Id
        );
        insert loteHT;

        Test.startTest();
        CuentaGranariaToneladasController.ConsumoResult resultado =
            CuentaGranariaToneladasController.generarConsumoHT(cgRegular.Id);
        Test.stopTest();

        System.assertEquals(true, resultado.success);
        System.assertEquals(30, resultado.cantidadConsumida);

        List<Tonelada__c> consumos = [
            SELECT Id, Signo__c, Cantidad__c, Cuenta_Granaria__c, Origen__c
            FROM Tonelada__c
            WHERE Origen__c = 'Consumo'
                AND Cuenta_Granaria__c IN :new Set<Id>{ cgRegular.Id, cgHT.Id }
        ];
        System.assertEquals(2, consumos.size(), 'Debe crear consumo positivo y negativo');

        Cuenta_Granaria__c cgRegularActualizada = [
            SELECT Saldo_Cuenta__c FROM Cuenta_Granaria__c WHERE Id = :cgRegular.Id
        ];
        System.assertEquals(0, cgRegularActualizada.Saldo_Cuenta__c);
    }

    @isTest
    static void testGenerarConsumoHTUsaLotesManualesEnCuentaHT() {
        Account prod = [SELECT Id FROM Account LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c LIMIT 1];

        Cuenta_Granaria__c cgRegular = [
            SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c != null LIMIT 1
        ];
        Cuenta_Granaria__c cgHT = [
            SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c = null LIMIT 1
        ];

        cgRegular.Es_Carga_Manual__c = true;
        cgRegular.Saldo_Cuenta__c = -25;
        cgHT.Saldo_Cuenta__c = 80;
        update new List<Cuenta_Granaria__c>{ cgRegular, cgHT };

        Tonelada__c loteManual = new Tonelada__c(
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Biotecnologia__c = 'Enlist E3',
            Cantidad__c = 80,
            Signo__c = 1,
            Origen__c = 'Compra HT',
            Fecha_Inicio__c = Date.today().addDays(-30),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Cobrada',
            N_CUIT__c = '20309998877',
            Cuenta_Granaria__c = cgHT.Id
        );
        insert loteManual;

        Test.startTest();
        CuentaGranariaToneladasController.ConsumoResult resultado =
            CuentaGranariaToneladasController.generarConsumoHT(cgRegular.Id);
        Test.stopTest();

        System.assertEquals(true, resultado.success);
        System.assertEquals(25, resultado.cantidadConsumida);

        List<Tonelada__c> consumos = [
            SELECT Id, Signo__c, Cantidad__c, Tonelada_Compra_HT__c
            FROM Tonelada__c
            WHERE Origen__c = 'Consumo'
                AND Tonelada_Compra_HT__c = :loteManual.Id
        ];
        System.assertEquals(2, consumos.size(), 'Debe consumir del lote manual en la CG HT');
    }

    @isTest
    static void testGetResumenAgrupaPorOrigen() {
        Cuenta_Granaria__c cg = [
            SELECT Id, Productor__c, Cultivo__c, Campania__c
            FROM Cuenta_Granaria__c WHERE Campania__c != null LIMIT 1
        ];
        insert new Tonelada__c(
            Productor__c = cg.Productor__c,
            Cultivo__c = cg.Cultivo__c,
            Campania__c = cg.Campania__c,
            Biotecnologia__c = 'Enlist E3',
            Cantidad__c = 20,
            Signo__c = -1,
            Fecha_Inicio__c = Date.today().addDays(-1),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF',
            Cuenta_Granaria__c = cg.Id
        );

        Test.startTest();
        Map<String, Object> result = CuentaGranariaToneladasController.getResumen(cg.Id, null);
        Test.stopTest();

        Decimal credito = (Decimal) result.get('credito');
        Decimal debito = (Decimal) result.get('debito');
        System.assertEquals(150, credito);
        System.assert(debito < 0);
        System.assertEquals(credito + debito, (Decimal) result.get('saldo'));

        Decimal sumaCreditos = 0;
        Decimal sumaDebitos = 0;
        Integer sumaMovimientos = 0;
        Integer filasCompraSF = 0;
        for (Object fila : (List<Object>) result.get('origenes')) {
            Map<String, Object> row = (Map<String, Object>) fila;
            if (row.get('tipo') == 'credito') {
                sumaCreditos += (Decimal) row.get('toneladas');
            } else {
                sumaDebitos += (Decimal) row.get('toneladas');
            }
            sumaMovimientos += (Integer) row.get('movimientos');
            if (row.get('origen') == 'Compra SF') {
                filasCompraSF++;
            }
        }
        System.assertEquals(credito, sumaCreditos, 'Las filas de crédito suman el Crédito total');
        System.assertEquals(debito, sumaDebitos, 'Las filas de débito suman el Débito total');
        System.assertEquals((Integer) result.get('movimientos'), sumaMovimientos);
        System.assertEquals(2, filasCompraSF, 'El débito de Compra SF va en su propia fila');

        Map<String, Object> cuenta = (Map<String, Object>) result.get('cuenta');
        System.assertEquals('25/26', cuenta.get('campaniaPeriodo'));

        Cuenta_Granaria__c cgHT = [SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c = null LIMIT 1];
        Map<String, Object> resumenHT = CuentaGranariaToneladasController.getResumen(cgHT.Id, null);
        Map<String, Object> cuentaHT = (Map<String, Object>) resumenHT.get('cuenta');
        System.assertEquals(true, cuentaHT.get('esCompraHT'));
    }

    @isTest
    static void testResumenTrigoPorVariedad() {
        Account prod = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];
        Cultivo__c trigo = new Cultivo__c(
            Name = 'TRIGO',
            Tipo_de_Especie__c = 'Autógama',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert trigo;
        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'TRIGO 2025 CGT',
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = trigo.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-3),
            SKEY_CAMPANIA__c = 8800004127L,
            Z9_Clave_Unica__c = 'CGT-TRIGO-2025',
            Id_Externo__c = 'CGT-TRIGO-2025'
        );
        insert campana;
        RecordType tipoObtentor = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor' LIMIT 1
        ];
        Account obtentor = new Account(
            Name = 'Semillero CGT',
            RecordTypeId = tipoObtentor.Id,
            Id_Obtentor__c = 'T7',
            Type = 'Obtentor',
            Nombre_Obtentor__c = 'MARCA CGT'
        );
        insert obtentor;
        Variedad__c negativa = new Variedad__c(
            Name = 'Negativa CGT', Biotecnologia__c = 'Convencional',
            Sembra_Evolucion__c = true, Obtentor_Comercializa__c = obtentor.Id
        );
        Variedad__c sinEntregas = new Variedad__c(
            Name = 'Sin Entregas CGT', Biotecnologia__c = 'Convencional',
            Sembra_Evolucion__c = true, Obtentor_Comercializa__c = obtentor.Id
        );
        insert new List<Variedad__c>{ negativa, sinEntregas };

        Cuenta_Granaria__c cg = new Cuenta_Granaria__c(
            Productor__c = prod.Id,
            Cultivo__c = trigo.Id,
            Campania__c = campana.Id,
            Tecnologia__c = 'RR1/RR2 - BT/Convencional',
            Clave_Unica__c = prod.Id + '|' + campana.Id + '|CGT'
        );
        insert cg;
        insert new List<Tonelada__c>{
            toneladaTrigo(prod.Id, trigo.Id, campana.Id, cg.Id, negativa.Id, 'Compra SF', 100, 1),
            toneladaTrigo(prod.Id, trigo.Id, campana.Id, cg.Id, negativa.Id, 'Cesión HT', 120, -1),
            toneladaTrigo(prod.Id, trigo.Id, campana.Id, cg.Id, sinEntregas.Id, 'Compra SF', 50, 1)
        };

        Test.startTest();
        Map<String, Object> resumen = CuentaGranariaToneladasController.getResumen(cg.Id, null);
        Map<String, Object> soloNegativa = CuentaGranariaToneladasController.getResumen(cg.Id, negativa.Id);
        Test.stopTest();

        System.assertEquals(true, resumen.get('esTrigo'));
        Map<String, Map<String, Object>> porNombre = new Map<String, Map<String, Object>>();
        for (Object fila : (List<Object>) resumen.get('variedades')) {
            Map<String, Object> row = (Map<String, Object>) fila;
            porNombre.put((String) row.get('nombre'), row);
        }
        System.assertEquals('Debe regularizar', porNombre.get('Negativa CGT').get('estado'));
        System.assertEquals(-20, (Decimal) porNombre.get('Negativa CGT').get('saldo'));
        System.assertEquals('MARCA CGT', porNombre.get('Negativa CGT').get('semillero'));
        System.assertEquals('Sin entregas', porNombre.get('Sin Entregas CGT').get('estado'));

        System.assertEquals(100, (Decimal) soloNegativa.get('credito'));
        System.assertEquals(-120, (Decimal) soloNegativa.get('debito'));
        System.assertEquals('Negativa CGT', soloNegativa.get('variedadNombre'));
        System.assertEquals(0, ((List<Object>) soloNegativa.get('variedades')).size());

        Map<String, Object> lista = CuentaGranariaToneladasController.getToneladas(cg.Id, negativa.Id);
        System.assertEquals(2, ((List<Object>) lista.get('toneladas')).size(), 'Ver variedad filtra la lista de toneladas');
        System.assertEquals('25/26', ((Map<String, Object>) lista.get('cuenta')).get('campaniaPeriodo'));
        String csvTrigo = CuentaGranariaToneladasController.exportarCsv(cg.Id, 'Compra SF', 'credito', negativa.Id);
        System.assert(csvTrigo.contains('Fecha creación'));
        System.assert(csvTrigo.contains('Variedad'));
        System.assert(csvTrigo.contains('Negativa CGT'));
    }

    private static Tonelada__c toneladaTrigo(
        Id productorId, Id cultivoId, Id campanaId, Id cgId, Id variedadId,
        String origen, Decimal cantidad, Integer signo
    ) {
        return new Tonelada__c(
            Productor__c = productorId,
            Cultivo__c = cultivoId,
            Campania__c = campanaId,
            Biotecnologia__c = 'Convencional',
            Cantidad__c = cantidad,
            Signo__c = signo,
            Fecha_Inicio__c = Date.today().addDays(-3),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = origen,
            Variedad__c = variedadId,
            Cuenta_Granaria__c = cgId
        );
    }

    @isTest
    static void testDetallePaginadoYCsv() {
        Cuenta_Granaria__c cg = [SELECT Id FROM Cuenta_Granaria__c WHERE Campania__c != null LIMIT 1];

        Test.startTest();
        Map<String, Object> detalle = CuentaGranariaToneladasController.getDetalle(
            cg.Id, 'Compra SF', 'credito', null, null, null, null
        );
        String csv = CuentaGranariaToneladasController.exportarCsv(cg.Id, 'Compra SF', 'credito', null);
        Test.stopTest();

        List<Object> filas = (List<Object>) detalle.get('filas');
        System.assertEquals(2, filas.size());
        System.assertEquals(false, detalle.get('hayMas'));
        System.assert(csv.contains('Compra Semilla Fiscalizada'));
        System.assert(csv.contains('Nombre;Origen;Etapa;Fecha creación;Cantidad'));
    }
}