@isTest
public class Test_VImportExcel {

    @TestSetup
    static void makeData() {
        insert new Account(Name = 'VI Import Test', N_CUIT__c = '20398301987');
    }

    @isTest static void testSetearOperadorRemesa() {
        List<Map<String,Object>> ventas = new List<Map<String,Object>>();

        Map<String,Object> venta3 = new Map<String,Object>();
        venta3.put('Fecha_de_Facturacion__c', '15/07/2019');
        ventas.add(venta3);

        try {
            lwcVentasImportFromExcel.inserRecodrsFromExcel(ventas, 'YXNk', 'Test', null);
        } catch (AuraHandledException e) {
            // Fila incompleta o sin datos válidos: el test cubre ramas de validación.
        }

        Boolean lanzoSinFilas = false;
        try {
            lwcVentasImportFromExcel.inserRecodrsFromExcel(new List<Map<String,Object>>(), 'YXNk', 'Test', null);
        } catch (AuraHandledException e) {
            lanzoSinFilas = true;
        }
        System.assert(lanzoSinFilas, 'Sin filas de datos debe lanzar AuraHandledException.');

        lwcVentasImportFromExcel.saveFileExcel(new List<Map<String,Object>>{new Map<String,Object>()});

        try {
            lwcVentasImportFromExcel.getContentDocument(null);
        } catch (Exception e) {}

        lwcVentasImportFromExcel.checkVenta(null, new Map<String,Object>(), null);
        lwcVentasImportFromExcel.checkVenta(new List<String>{}, new Map<String,Object>(), new Ventas_Informadas__c(Categoria__c = '123'));
        lwcVentasImportFromExcel.checkForDuplicates(new List<Ventas_Informadas__c>{new Ventas_Informadas__c(Cantidad_de_Bolsas__c = 8)});
    }

    /** Import mínimo en contexto de test (sin comunidad). */
    @isTest static void inserRecodrsFromExcelFilaCompletaTest() {
        Test_TestUtils.disableFlows();

        Account acc = [SELECT N_CUIT__c FROM Account LIMIT 1];
        Cultivo__c cultivo = new Cultivo__c(Name = 'VI IMPORT SOJA', Densidad_de_Siembra__c = 1);
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'VI IMPORT CAMP 2025',
            Ano__c = '2025',
            Id_Externo__c = 'VI_IMP_CAMP_001',
            Z9_Clave_Unica__c = 'VI_Z9_IMP_001',
            SKEY_CAMPANIA__c = 8800991,
            Cultivo__c = cultivo.Id
        );
        insert campana;

        Variedad__c variedad = new Variedad__c(
            Cultivar_Inase__c = 'VI IMPORT VAR',
            Cultivo__c = cultivo.Id
        );
        insert variedad;

        insert new Product2(
            Name = 'VI Import Prod',
            Cultivar_Inase__c = 'VI IMPORT VAR',
            Categoria__c = 'Primera Multiplicación',
            Family = 'Semilla Fiscalizada',
            IsActive = true,
            Cultivo__c = cultivo.Id,
            Variedad__c = variedad.Id,
            Variedad2__c = variedad.Id
        );

        Map<String, Object> row = new Map<String, Object>{
            'Fecha_de_Facturacion__c' => '15/07/2025',
            'Cantidad_de_Bolsas__c' => '40',
            'Categoria__c' => 'Primera Multiplicación',
            'CUIT_Destinatario__c' => acc.N_CUIT__c,
            'CUIT_Originante__c' => '20389301977',
            'Linea_Facturacion__c' => '1',
            'Tipo_Comprobante_Externo__c' => 'FC',
            'Variedad__c' => 'VI IMPORT VAR',
            'Campana_de_Ventas__c' => '2025',
            'N_de_Comprobante__c' => 'VI-001'
        };

        Test.startTest();
        List<Map<String, Object>> result = lwcVentasImportFromExcel.inserRecodrsFromExcel(
            new List<Map<String, Object>>{ row },
            EncodingUtil.base64Encode(Blob.valueOf('test')),
            'TestImport.xlsx',
            acc.Id
        );
        Test.stopTest();

        System.assertEquals(1, result.size());
        if (result[0].containsKey('Error')) {
            System.assert(false, 'Import no debe fallar: ' + result[0].get('Error'));
        }
        System.assertEquals(true, result[0].get('isSucces'), 'La fila debe importarse sin errores.');
    }

    @isTest static void batchVentasInformeFromExcelSmokeTest() {
        Test_TestUtils.disableFlows();

        Account acc = [SELECT N_CUIT__c FROM Account LIMIT 1];
        Cultivo__c cultivo = new Cultivo__c(Name = 'VI BATCH SOJA', Densidad_de_Siembra__c = 1);
        insert cultivo;
        insert new Campana_Agricola__c(
            Name = 'VI BATCH CAMP 2025',
            Ano__c = '2025',
            Id_Externo__c = 'VI_BATCH_CAMP_001',
            Z9_Clave_Unica__c = 'VI_Z9_BATCH_001',
            SKEY_CAMPANIA__c = 8800992,
            Cultivo__c = cultivo.Id
        );
        insert new Variedad__c(Cultivar_Inase__c = 'VI BATCH VAR', Cultivo__c = cultivo.Id);
        Variedad__c variedad = [SELECT Id FROM Variedad__c WHERE Cultivar_Inase__c = 'VI BATCH VAR' LIMIT 1];
        insert new Product2(
            Name = 'VI Batch Prod',
            Cultivar_Inase__c = 'VI BATCH VAR',
            Categoria__c = 'Primera Multiplicación',
            Family = 'Semilla Fiscalizada',
            IsActive = true,
            Cultivo__c = cultivo.Id,
            Variedad__c = variedad.Id,
            Variedad2__c = variedad.Id
        );

        Test.startTest();
        Id jobId = lwcVentasImportFromExcel.saveFileExcel(new List<Map<String, Object>>{
            new Map<String, Object>{
                'Fecha_de_Facturacion__c' => '15/07/2025',
                'Cantidad_de_Bolsas__c' => '40',
                'Categoria__c' => 'Primera Multiplicación',
                'CUIT_Destinatario__c' => acc.N_CUIT__c,
                'CUIT_Originante__c' => acc.N_CUIT__c,
                'Linea_Facturacion__c' => '1',
                'Tipo_de_Comprobante__c' => 'FC',
                'Variedad__c' => 'VI BATCH VAR',
                'Campana_de_Ventas__c' => '2025',
                'N_de_Comprobante__c' => 'VI-BATCH-001'
            }
        });
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @isTest static void batchVentasInformeFromExcelExecuteDirectTest() {
        Test_TestUtils.disableFlows();

        Account acc = [SELECT N_CUIT__c FROM Account LIMIT 1];
        Cultivo__c cultivo = new Cultivo__c(Name = 'VI BATCH EXEC SOJA', Densidad_de_Siembra__c = 1);
        insert cultivo;
        insert new Campana_Agricola__c(
            Name = 'VI BATCH EXEC CAMP 2025',
            Ano__c = '2025',
            Id_Externo__c = 'VI_BATCH_EXEC_001',
            Z9_Clave_Unica__c = 'VI_Z9_BATCH_EXEC_001',
            SKEY_CAMPANIA__c = 8800993,
            Cultivo__c = cultivo.Id
        );
        Variedad__c variedad = new Variedad__c(Cultivar_Inase__c = 'VI BATCH EXEC VAR', Cultivo__c = cultivo.Id);
        insert variedad;
        insert new Product2(
            Name = 'VI Batch Exec Prod',
            Cultivar_Inase__c = 'VI BATCH EXEC VAR',
            Categoria__c = 'Primera Multiplicación',
            Family = 'Semilla Fiscalizada',
            IsActive = true,
            Cultivo__c = cultivo.Id,
            Variedad__c = variedad.Id,
            Variedad2__c = variedad.Id
        );

        Map<String, Object> row = new Map<String, Object>{
            'Fecha_de_Facturacion__c' => '15/07/2025',
            'Cantidad_de_Bolsas__c' => '40',
            'Categoria__c' => 'Primera Multiplicación',
            'CUIT_Destinatario__c' => acc.N_CUIT__c,
            'CUIT_Originante__c' => acc.N_CUIT__c,
            'Linea_Facturacion__c' => '1',
            'Tipo_de_Comprobante__c' => 'FC',
            'Variedad__c' => 'VI BATCH EXEC VAR',
            'Campana_de_Ventas__c' => '2025',
            'N_de_Comprobante__c' => 'VI-BATCH-EXEC-001'
        };

        BatchApexVentasInformeFromExcel batch =
            new BatchApexVentasInformeFromExcel(new List<Map<String, Object>>{ row });

        Test.startTest();
        batch.start(null);
        batch.execute(null, new List<Map<String, Object>>{ row });
        Test.stopTest();

        List<Ventas_Informadas__c> ventas = [
            SELECT Destinatario__c, Rol_Destinatario__c
            FROM Ventas_Informadas__c
            WHERE N_de_Comprobante__c = 'VI-BATCH-EXEC-001'
        ];
        System.assertEquals(1, ventas.size());
        System.assertNotEquals(null, ventas[0].Destinatario__c);
    }

    /** Normalización de CUITs: clientes mandan con guiones, SF necesita sin guiones. */
    @isTest static void normalizeCuitFieldsTest() {
        Map<String,Object> row = new Map<String,Object>{
            'CUIT_Destinatario__c' => '20-39342968-3',
            'CUIT_Originante__c'   => '30 50711923 5'
        };
        lwcVentasImportFromExcel.normalizeCuitFields(row);
        System.assertEquals('20393429683', (String)row.get('CUIT_Destinatario__c'));
        System.assertEquals('30507119235', (String)row.get('CUIT_Originante__c'));

        // Casos borde: null, mapa vacío, valores sin separadores.
        lwcVentasImportFromExcel.normalizeCuitFields(null);
        Map<String,Object> row2 = new Map<String,Object>{
            'CUIT_Destinatario__c' => null,
            'CUIT_Originante__c'   => '20.39342968.3'
        };
        lwcVentasImportFromExcel.normalizeCuitFields(row2);
        System.assertEquals(null, row2.get('CUIT_Destinatario__c'));
        System.assertEquals('20393429683', (String)row2.get('CUIT_Originante__c'));
    }

    @isTest static void coerceExcelCellToPlainStringTest() {
        System.assertEquals(
            '5000009670',
            lwcVentasImportFromExcel.coerceExcelCellToPlainString(Decimal.valueOf('5.00000967E9'))
        );
        System.assertEquals('30707295089', lwcVentasImportFromExcel.coerceExcelCellToPlainString(Decimal.valueOf('30707295089')));
        System.assertEquals('A-0001-00000001', lwcVentasImportFromExcel.coerceExcelCellToPlainString('A-0001-00000001'));

        Map<String,Object> nro = new Map<String,Object>{
            'N_de_Comprobante__c' => Decimal.valueOf('5.00000967E9')
        };
        lwcVentasImportFromExcel.normalizeNComprobanteField(nro);
        System.assertEquals('5000009670', (String)nro.get('N_de_Comprobante__c'));

        Map<String,Object> linea = new Map<String,Object>{ 'Linea_Facturacion__c' => Decimal.valueOf('2') };
        lwcVentasImportFromExcel.normalizeLineaFacturacionField(linea);
        System.assertEquals('2', (String)linea.get('Linea_Facturacion__c'));
    }

    /** Plantilla legacy (hoja Planilla, encabezados API + Tipo_de_Comprobante__c). */
    @isTest static void normalizeTipoComprobanteLegacyPlantillaTest() {
        Map<String, Object> row = new Map<String, Object>{
            'Campana_de_Ventas__c' => '2026',
            'Kilos Totales' => '400',
            'Categoria__c' => 'Primera Multiplicación',
            'CUIT_Destinatario__c' => '30711969523',
            'CUIT_Originante__c' => '30709538418',
            'Fecha_de_Facturacion__c' => '46183',
            'Kilos_por_Bolsa__c' => '1',
            'Linea_Facturacion__c' => '1',
            'N_de_Comprobante__c' => 'A-0001-00000001',
            'Razon_Social_Destinatario__c' => 'ADBLICK GRANOS S.A.',
            'Tipo_de_Comprobante__c' => 'FC',
            'Variedad__c' => 'ARAUCARIA'
        };

        lwcVentasImportFromExcel.normalizeColumnAliases(row);
        lwcVentasImportFromExcel.normalizeTipoComprobanteField(row);

        System.assertEquals('FC', row.get('Tipo_Comprobante_Externo__c'));
        System.assertEquals('FC', row.get('Tipo_de_Comprobante__c'));
        System.assertEquals('400', row.get('Cantidad_de_Bolsas__c'));
        System.assertNotEquals(null, lwcVentasImportFromExcel.parseFlexibleDate('46183'));

        Map<String, Object> remito = new Map<String, Object>{ 'Tipo_de_Comprobante__c' => 'REMITO' };
        lwcVentasImportFromExcel.normalizeTipoComprobanteField(remito);
        System.assertEquals('Remito', remito.get('Tipo_Comprobante_Externo__c'));
        System.assertEquals('FC', remito.get('Tipo_de_Comprobante__c'));
    }

    /** Variedad en el preproceso: trim + mayúsculas; vacío/espacios → null. */
    @isTest static void normalizeVariedadFieldTest() {
        Map<String,Object> r1 = new Map<String,Object>{ 'Variedad__c' => '  baguette 620 ' };
        lwcVentasImportFromExcel.normalizeVariedadField(r1);
        System.assertEquals('BAGUETTE 620', (String)r1.get('Variedad__c'));

        Map<String,Object> r2 = new Map<String,Object>{ 'Variedad__c' => '   ' };
        lwcVentasImportFromExcel.normalizeVariedadField(r2);
        System.assertEquals(null, r2.get('Variedad__c'));

        Map<String,Object> r3 = new Map<String,Object>{ 'Variedad__c' => null };
        lwcVentasImportFromExcel.normalizeVariedadField(r3);
        System.assertEquals(null, r3.get('Variedad__c'));

        lwcVentasImportFromExcel.normalizeVariedadField(null);
    }

    /** Kilos Totales en formato argentino: '.' miles, ',' decimal (y tolerancia US legacy). */
    @isTest static void parseKilosTotalesTest() {
        // Formato US legacy (lo que llega hoy del serializador numérico).
        System.assertEquals(Decimal.valueOf('3280.0'),  lwcVentasImportFromExcel.parseKilosTotales('3280.0'));
        System.assertEquals(Decimal.valueOf('44800.0'), lwcVentasImportFromExcel.parseKilosTotales('44800.0'));
        System.assertEquals(Decimal.valueOf('20'),      lwcVentasImportFromExcel.parseKilosTotales('20'));

        // Formato argentino: punto = miles, coma = decimal.
        System.assertEquals(Decimal.valueOf('3280'),       lwcVentasImportFromExcel.parseKilosTotales('3.280'));
        System.assertEquals(Decimal.valueOf('1600'),       lwcVentasImportFromExcel.parseKilosTotales('1.600'));
        System.assertEquals(Decimal.valueOf('1600'),       lwcVentasImportFromExcel.parseKilosTotales('1,600'));
        System.assertEquals(Decimal.valueOf('1600'),       lwcVentasImportFromExcel.parseKilosTotales('1600.00'));
        System.assertEquals(Decimal.valueOf('1234567'),    lwcVentasImportFromExcel.parseKilosTotales('1.234.567'));
        System.assertEquals(Decimal.valueOf('1234.56'),    lwcVentasImportFromExcel.parseKilosTotales('1.234,56'));
        System.assertEquals(Decimal.valueOf('1234567.89'), lwcVentasImportFromExcel.parseKilosTotales('1.234.567,89'));
        System.assertEquals(Decimal.valueOf('1234.5'),     lwcVentasImportFromExcel.parseKilosTotales('1234,5'));

        // Formato US con miles por coma.
        System.assertEquals(Decimal.valueOf('1234.56'), lwcVentasImportFromExcel.parseKilosTotales('1,234.56'));

        // Con espacios / texto: se limpia.
        System.assertEquals(Decimal.valueOf('3280'), lwcVentasImportFromExcel.parseKilosTotales(' 3.280 '));

        // No numérico / vacío => null.
        System.assertEquals(null, lwcVentasImportFromExcel.parseKilosTotales(''));
        System.assertEquals(null, lwcVentasImportFromExcel.parseKilosTotales('   '));
        System.assertEquals(null, lwcVentasImportFromExcel.parseKilosTotales(null));

        // normalizeKilosTotalesField deja un string numérico canónico (deserializable).
        Map<String,Object> rk = new Map<String,Object>{ 'Cantidad_de_Bolsas__c' => '1.234,56' };
        lwcVentasImportFromExcel.normalizeKilosTotalesField(rk);
        System.assertEquals(Decimal.valueOf('1234.56'), Decimal.valueOf(String.valueOf(rk.get('Cantidad_de_Bolsas__c'))));

        Map<String,Object> rk2 = new Map<String,Object>{ 'Cantidad_de_Bolsas__c' => 'abc' };
        lwcVentasImportFromExcel.normalizeKilosTotalesField(rk2);
        System.assertEquals(null, rk2.get('Cantidad_de_Bolsas__c'));

        lwcVentasImportFromExcel.normalizeKilosTotalesField(null);
    }

    /** Primer año de 4 dígitos: 2025/26 → 2025, SOJA - 2025/26 → 2025. */
    @isTest static void normalizeCampanaAgricolaTest() {
        Map<String,Object> r1 = new Map<String,Object>{'Campana_de_Ventas__c' => '2026'};
        lwcVentasImportFromExcel.normalizeCampanaAgricolaPreDeserialize(r1);
        System.assertEquals('2026', (String)r1.get('Campana_de_Ventas__c'));

        Map<String,Object> r2 = new Map<String,Object>{'Campana_de_Ventas__c' => '2025/26'};
        lwcVentasImportFromExcel.normalizeCampanaAgricolaPreDeserialize(r2);
        System.assertEquals('2025', (String)r2.get('Campana_de_Ventas__c'));

        Map<String,Object> r3 = new Map<String,Object>{'Campaña Agrícola' => 'SOJA - 2025/26'};
        lwcVentasImportFromExcel.normalizeColumnAliases(r3);
        lwcVentasImportFromExcel.normalizeCampanaAgricolaPreDeserialize(r3);
        System.assertEquals('2025', (String)r3.get('Campana_de_Ventas__c'));

        Map<String,Object> r4 = new Map<String,Object>{'Campana_de_Ventas__c' => '26-27'};
        lwcVentasImportFromExcel.normalizeCampanaAgricolaPreDeserialize(r4);
        System.assertEquals('2026', (String)r4.get('Campana_de_Ventas__c'));

        Map<String,Object> r5 = new Map<String,Object>{'Campana_de_Ventas__c' => '26/27'};
        lwcVentasImportFromExcel.normalizeCampanaAgricolaPreDeserialize(r5);
        System.assertEquals('2026', (String)r5.get('Campana_de_Ventas__c'));
    }

    @isTest static void primerAnioCampanaTextTest() {
        System.assertEquals('2025', lwcVentasImportFromExcel.primerAnioCampanaText('2025/26'));
        System.assertEquals('2026', lwcVentasImportFromExcel.primerAnioCampanaText('2026-2027'));
        System.assertEquals('2026', lwcVentasImportFromExcel.primerAnioCampanaText('26-27'));
        System.assertEquals('2026', lwcVentasImportFromExcel.primerAnioCampanaText('26/27'));
        System.assertEquals('2025', lwcVentasImportFromExcel.primerAnioCampanaText('25/26'));
        System.assertEquals(null, lwcVentasImportFromExcel.primerAnioCampanaText('sin año'));
    }

    @isTest static void filterFilasLeyendaTest() {
        List<Map<String,Object>> rows = new List<Map<String,Object>>{
            new Map<String,Object>{
                'Campaña Agrícola' => '2026',
                'Kilos Totales' => '100',
                'Variedad__c' => 'TESTVAR'
            },
            new Map<String,Object>{
                'Campaña Agrícola' => 'POR FAVOR ELIMINE LAS LÍNEAS DESDE AQUÍ ANTES DE ENVIAR'
            },
            new Map<String,Object>{
                'Campaña Agrícola' => 'Campana_de_Ventas__c',
                'Kilos Totales' => 'Año de la Campaña de Comercialización'
            }
        };
        List<Map<String,Object>> filtradas = lwcVentasImportFromExcel.filterFilasDatosVentas(rows);
        System.assertEquals(1, filtradas.size(), 'Solo debe quedar la fila de datos real.');
        System.assertEquals('2026', filtradas[0].get('Campaña Agrícola'));
    }

    @isTest static void kilosTotalesAliasTest() {
        Map<String,Object> row = new Map<String,Object>{'Kilos Totales' => '100'};
        lwcVentasImportFromExcel.normalizeColumnAliases(row);
        System.assertEquals('100', String.valueOf(row.get('Cantidad_de_Bolsas__c')));
    }

    /** Bulk query de Variedad__c case/space-insensitive (también ignora espacios internos). */
    @isTest static void getVariedadesPorNombreTest() {
        Test_TestUtils.disableFlows();
        insert new Variedad__c(Cultivar_Inase__c = 'TESTVAR-ABC');
        insert new Variedad__c(Cultivar_Inase__c = 'DD 32');  // catálogo con espacio

        List<Map<String,Object>> rows = new List<Map<String,Object>>{
            new Map<String,Object>{ 'Variedad__c' => '  testvar-abc  ' },  // case + espacios
            new Map<String,Object>{ 'Variedad__c' => 'DD32' },             // sin el espacio interno
            new Map<String,Object>{ 'Variedad__c' => 'NO-EXISTE' },
            new Map<String,Object>{ 'Variedad__c' => null }
        };

        Test.startTest();
        Map<String, Variedad__c> m = lwcVentasImportFromExcel.getVariedadesPorNombre(rows);
        Test.stopTest();

        System.assert(m.containsKey('TESTVAR-ABC'), 'Debe match case-insensitive y con trim.');
        System.assert(m.containsKey('DD32'), 'Debe match aunque le falte el espacio interno (DD32 = DD 32).');
        System.assert(!m.containsKey('NO-EXISTE'), 'No debe haber variedades que no existan en SF.');
    }

    /** variedadKey: normalización para match (mayúsculas, sin espacios). */
    @isTest static void variedadKeyTest() {
        System.assertEquals(null, lwcVentasImportFromExcel.variedadKey(null));
        System.assertEquals('ABC', lwcVentasImportFromExcel.variedadKey('  abc  '));
        System.assertEquals('SOJADM4615', lwcVentasImportFromExcel.variedadKey('soja dm 4615'));
        System.assertEquals('DD32', lwcVentasImportFromExcel.variedadKey('DD 32'));
        System.assertEquals('DD32', lwcVentasImportFromExcel.variedadKey('dd32'));
    }

    /** Categoría: sin acento, mayúsculas o espacios extra → valor canónico INASE. */
    @isTest static void normalizeCategoriaTest() {
        System.assertEquals('Primera Multiplicación', lwcVentasImportFromExcel.normalizeCategoria('PRIMERA MULTIPLICACION'));
        System.assertEquals('Pre Básica', lwcVentasImportFromExcel.normalizeCategoria('pre basica'));
        System.assertEquals('Original o Fundadora', lwcVentasImportFromExcel.normalizeCategoria('  ORIGINAL O FUNDADORA  '));
        System.assertEquals('Original o Fundadora', lwcVentasImportFromExcel.normalizeCategoria('Original'));
        System.assertEquals('Original o Fundadora', lwcVentasImportFromExcel.normalizeCategoria('FUNDADORA'));
        System.assertEquals('Original o Fundadora', lwcVentasImportFromExcel.normalizeCategoria('Origina'));
        System.assertEquals('Segunda Multiplicación', lwcVentasImportFromExcel.normalizeCategoria('segunda multiplicacion'));
        System.assertEquals('Tercera Multiplicación', lwcVentasImportFromExcel.normalizeCategoria('TERCERA MULTIPLICACIÓN'));

        Map<String,Object> row = new Map<String,Object>{ 'Categoría' => 'primera multiplicacion' };
        lwcVentasImportFromExcel.normalizeColumnAliases(row);
        lwcVentasImportFromExcel.normalizeCategoriaField(row);
        System.assertEquals('Primera Multiplicación', (String)row.get('Categoria__c'));
    }

    @isTest static void parseFlexibleDateTest() {
        System.assertEquals(Date.newInstance(2019, 7, 15),
            lwcVentasImportFromExcel.parseFlexibleDate('15/07/2019'));
        System.assertEquals(Date.newInstance(2020, 3, 9),
            lwcVentasImportFromExcel.parseFlexibleDate('2020-03-09'));
        System.assertEquals(Date.newInstance(2026, 6, 17),
            lwcVentasImportFromExcel.parseFlexibleDate('6/17/2026'));
        System.assertEquals(Date.newInstance(2026, 6, 17),
            lwcVentasImportFromExcel.parseFlexibleDate('17/6/2026'));
        System.assertEquals(null, lwcVentasImportFromExcel.parseFlexibleDate(null));
        System.assertEquals(null, lwcVentasImportFromExcel.parseFlexibleDate('fecha invalida'));
    }

    @isTest static void normalizeTipoComprobanteTest() {
        System.assertEquals('FC', lwcVentasImportFromExcel.normalizeTipoComprobante('REMITO'));
        System.assertEquals('NC', lwcVentasImportFromExcel.normalizeTipoComprobante('remito de devolucion'));
        System.assertEquals('FC', lwcVentasImportFromExcel.normalizeTipoComprobante('fc'));
        System.assertEquals('Remito', lwcVentasImportFromExcel.canonicalTipoComprobanteExterno('remito'));
        System.assertEquals('FC', lwcVentasImportFromExcel.canonicalTipoComprobanteExterno('fc'));
        System.assertEquals('Remito de Devolución', lwcVentasImportFromExcel.canonicalTipoComprobanteExterno('REMITO DE DEVOLUCION'));
        System.assertEquals(true, lwcVentasImportFromExcel.esTipoComprobanteExternoValido('nc'));
        System.assertEquals(false, lwcVentasImportFromExcel.esTipoComprobanteExternoValido('ND'));

        Map<String, Object> rowMinus = new Map<String, Object>{
            'Tipo_Comprobante_Externo__c' => 'remito'
        };
        lwcVentasImportFromExcel.normalizeTipoComprobanteField(rowMinus);
        System.assertEquals('Remito', rowMinus.get('Tipo_Comprobante_Externo__c'));
        System.assertEquals('FC', rowMinus.get('Tipo_de_Comprobante__c'));
    }

    @isTest static void applyNComprobantePrefijoRemitoTest() {
        Map<String,Object> remito = new Map<String,Object>{
            'Tipo_Comprobante_Externo__c' => 'Remito',
            'N_de_Comprobante__c' => '12345'
        };
        lwcVentasImportFromExcel.applyNComprobantePrefijoRemito(remito);
        System.assertEquals('R-12345', (String)remito.get('N_de_Comprobante__c'));

        Map<String,Object> remitoVacio = new Map<String,Object>{
            'Tipo_Comprobante_Externo__c' => 'Remito',
            'N_de_Comprobante__c' => ''
        };
        lwcVentasImportFromExcel.applyNComprobantePrefijoRemito(remitoVacio);
        System.assertEquals(null, remitoVacio.get('N_de_Comprobante__c'));

        Map<String,Object> rd = new Map<String,Object>{
            'Tipo_Comprobante_Externo__c' => 'Remito de Devolución',
            'N_de_Comprobante__c' => 'RD-99'
        };
        lwcVentasImportFromExcel.applyNComprobantePrefijoRemito(rd);
        System.assertEquals('RD-99', (String)rd.get('N_de_Comprobante__c'));
    }
}