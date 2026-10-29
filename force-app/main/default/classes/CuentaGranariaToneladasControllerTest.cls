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

        // Toneladas
        List<Object> toneladas = (List<Object>) result.get('toneladas');
        System.assertEquals(3, toneladas.size(), 'Debe haber 3 toneladas');

        // Totales
        Decimal total = (Decimal) result.get('total');
        Decimal totalPositivo = (Decimal) result.get('totalPositivo');
        Decimal totalNegativo = (Decimal) result.get('totalNegativo');
        System.assertEquals(120, total, 'Total debe ser 100+50-30=120');
        System.assertEquals(150, totalPositivo, 'Positivo debe ser 100+50=150');
        System.assertEquals(-30, totalNegativo, 'Negativo debe ser -30');

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
}