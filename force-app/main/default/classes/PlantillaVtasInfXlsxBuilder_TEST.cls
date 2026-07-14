@isTest
public class PlantillaVtasInfXlsxBuilder_TEST {

    @testSetup
    static void setup() {
        Test_TestUtils.disableFlows();
        insert new List<Variedad__c>{
            new Variedad__c(Cultivar_Inase__c = 'SOJA DM 4615'),
            new Variedad__c(Cultivar_Inase__c = 'SOJA DM 5040'),
            new Variedad__c(Cultivar_Inase__c = 'TRIGO BIOINTA 3005')
        };
    }

    @isTest
    static void generaPlantillaBase64EsZipValido() {
        Test.startTest();
        String b64 = PlantillaVtasInfXlsxBuilder.generarPlantillaBase64(false);
        Test.stopTest();

        System.assertNotEquals(null, b64);
        System.assert(b64.length() > 5000, 'El xlsx generado debe heredar el peso de la plantilla base.');

        Blob z = EncodingUtil.base64Decode(b64);
        String hexHeader = EncodingUtil.convertToHex(z).substring(0, 8).toLowerCase();
        System.assertEquals('504b0304', hexHeader, 'Debe ser un ZIP v\u00e1lido.');
    }

    @isTest
    static void diccionariosTienenContenidoEsperado() {
        Test.startTest();
        Map<String, List<String>> dicc = PlantillaVtasInfXlsxBuilder.loadDiccionarios();
        Test.stopTest();

        System.assert(!dicc.get('VARIEDADES').isEmpty(), 'Debe traer variedades del setup.');
        System.assertEquals(5, dicc.get('CATEGORIAS').size(), 'Categor\u00edas INASE fijas.');
        System.assert(
            dicc.get('CATEGORIAS').contains('Original o Fundadora'),
            'La plantilla debe mostrar Original o Fundadora como una sola categor\u00eda.'
        );
        System.assert(
            !dicc.get('CATEGORIAS').contains('Original'),
            'No debe listar Original por separado en la plantilla.'
        );
        System.assertEquals(4, dicc.get('TIPO_COMP').size(), 'FC, NC, Remito, Remito de Devoluci\u00f3n.');
        System.assert(
            !dicc.get('TIPO_COMP').contains('ND'),
            'ND ya no debe estar en la lista de Tipo de Comprobante (ticket 1874).'
        );
        System.assert(
            dicc.get('TIPO_COMP').contains('Remito'),
            'Remito debe estar en Tipo de Comprobante.'
        );
        List<String> anos = dicc.get('CAMPANAS');
        System.assertEquals(4, anos.size(), 'Rango: actual-2, actual-1, actual, actual+1.');
        Integer y = Date.today().year();
        System.assert(anos.contains(String.valueOf(y - 2)), 'Debe incluir 2 a\u00f1os atr\u00e1s.');
        System.assert(anos.contains(String.valueOf(y + 1)), 'Debe incluir 1 a\u00f1o adelante.');
    }

    @isTest
    static void buildAnosCampanaListaTest() {
        List<String> anos = PlantillaVtasInfXlsxBuilder.buildAnosCampanaLista();
        Integer y = Date.today().year();
        System.assertEquals(String.valueOf(y - 2), anos[0]);
        System.assertEquals(String.valueOf(y + 1), anos[3]);
    }

    @isTest
    static void referenciasSheetIncluyeVariedadesYCampanas() {
        Map<String, List<String>> dicc = new Map<String, List<String>>{
            'CATEGORIAS' => new List<String>{ 'A', 'B', 'C', 'D', 'E' },
            'TIPO_COMP'  => new List<String>{ 'FC', 'NC', 'Remito', 'Remito de Devolución' },
            'VARIEDADES' => new List<String>{ 'VAR-1', 'VAR-2' },
            'CAMPANAS'   => new List<String>{ '2025', '2026' }
        };

        String base = '<?xml version="1.0"?>'
            + '<worksheet><sheetPr><tabColor rgb="FFFFC000"/></sheetPr>'
            + '<dimension ref="B1:E7"/><sheetData>'
            + '<row r="1" spans="2:5"><c r="C1" s="31" t="s"><v>0</v></c></row>'
            + '<row r="2" spans="2:5"><c r="B2" s="2" t="s"><v>1</v></c></row>'
            + '<row r="3" spans="2:5"><c r="B3" s="20"/></row>'
            + '</sheetData><mergeCells count="1"><mergeCell ref="C1:E1"/></mergeCells></worksheet>';

        Test.startTest();
        String xml = PlantillaVtasInfXlsxBuilder.patchReferenciasSheet(base, dicc);
        Test.stopTest();

        System.assert(xml.contains('VAR-1'), 'Variedad debe estar en REFERENCIAS.');
        System.assert(xml.contains('Remito de Devoluci'), 'Remito de Devoluci\u00f3n debe estar.');
        System.assert(xml.contains('2026'), 'Campa\u00f1a debe estar.');
        System.assert(xml.contains('tabColor rgb="FFFFC000"'), 'Debe conservar color de pesta\u00f1a.');
        System.assert(xml.contains('s="31"') || xml.contains('s="2"'),
            'Debe conservar estilos del template.');
        System.assert(xml.contains('r="B3"'), 'Campa\u00f1as en columna B.');
        System.assert(xml.contains('r="E3"') || xml.contains('r="E4"'),
            'Variedades en columna E.');
    }

    @isTest
    static void comentariosSheetIncluyeVariedadesYCampanas() {
        Map<String, List<String>> dicc = new Map<String, List<String>>{
            'CATEGORIAS' => new List<String>{ 'A', 'B', 'C', 'D', 'E' },
            'TIPO_COMP'  => new List<String>{ 'FC', 'NC', 'Remito', 'Remito de Devolución' },
            'VARIEDADES' => new List<String>{ 'VAR-1', 'VAR-2' },
            'CAMPANAS'   => new List<String>{ '2025', '2026' }
        };

        Test.startTest();
        String xml = PlantillaVtasInfXlsxBuilder.buildComentariosSheet(dicc);
        Test.stopTest();

        System.assert(xml.contains('VAR-1'), 'Variedad debe estar en el sheet de Comentarios.');
        System.assert(xml.contains('Remito de Devoluci'), 'Remito de Devoluci\u00f3n debe estar.');
        System.assert(xml.contains('2026'), 'Campa\u00f1a debe estar.');
        System.assert(!xml.contains('>ND<'), 'ND no debe aparecer.');
        System.assert(xml.contains('Variedad__c'), 'Header Variedad__c presente.');
        System.assert(xml.contains('Campana_Agricola__c'), 'Header Campana_Agricola__c presente.');
    }

    @isTest
    static void patchSheet1NuevoModeloActualizaReferencias() {
        String sheet1 = '<worksheet>'
            + '<dataValidations count="1">'
            + '<dataValidation sqref="D4:E1048576"/>'
            + '</dataValidations>'
            + '<extLst><ext><x14:dataValidations count="4">'
            + '<x14:dataValidation><x14:formula1><xm:f>REFERENCIAS!$B$3:$B$7</xm:f></x14:formula1></x14:dataValidation>'
            + '<x14:dataValidation><x14:formula1><xm:f>REFERENCIAS!$C$3:$C$6</xm:f></x14:formula1></x14:dataValidation>'
            + '<x14:dataValidation><x14:formula1><xm:f>REFERENCIAS!$D$3:$D$6</xm:f></x14:formula1></x14:dataValidation>'
            + '<x14:dataValidation><x14:formula1><xm:f>REFERENCIAS!$E$3:$E$1504</xm:f></x14:formula1></x14:dataValidation>'
            + '</x14:dataValidations></ext></extLst>'
            + '</worksheet>';

        Map<String, List<String>> dicc = new Map<String, List<String>>{
            'CATEGORIAS' => new List<String>{ 'A', 'B', 'C', 'D', 'E' },
            'TIPO_COMP'  => new List<String>{ 'FC', 'NC', 'Remito', 'Remito de Devolución' },
            'VARIEDADES' => new List<String>{ 'VAR-1', 'VAR-2', 'VAR-3' },
            'CAMPANAS'   => new List<String>{ '2025', '2026' }
        };

        Test.startTest();
        String resultado = PlantillaVtasInfXlsxBuilder.patchSheet1DataValidations(sheet1, dicc);
        Test.stopTest();

        System.assert(resultado.contains('sqref="D4:D1048576"'), 'CUIT solo columna D.');
        System.assert(resultado.contains('REFERENCIAS!$B$3:$B$4'), 'Campa\u00f1as din\u00e1micas en col B.');
        System.assert(resultado.contains('REFERENCIAS!$E$3:$E$5'), 'Variedades din\u00e1micas en col E.');
        System.assert(resultado.contains('REFERENCIAS!$D$3:$D$6'), 'Tipo comprobante 4 valores en col D.');
    }

    @isTest
    static void patchSheet1AgregaValidacionesNuevas() {
        String sheet1 = '<worksheet>'
            + '<dataValidations count="1">'
            +   '<dataValidation allowBlank="1" showInputMessage="1" showErrorMessage="1"'
            +     ' prompt="Kilos totales de la línea de facturación" sqref="B2:B23"'
            +     ' xr:uid="{00000000-0002-0000-0000-000002000000}"/>'
            + '</dataValidations>'
            + '<extLst><ext><x14:dataValidations count="2" xmlns:xm="http://schemas.microsoft.com/office/excel/2006/main">'
            +   '<x14:dataValidation type="list"><x14:formula1><xm:f>Comentarios!$D$5:$D$7</xm:f></x14:formula1>'
            +     '<xm:sqref>K2:K23</xm:sqref></x14:dataValidation>'
            + '</x14:dataValidations></ext></extLst>'
            + '</worksheet>';

        Map<String, List<String>> dicc = new Map<String, List<String>>{
            'CATEGORIAS' => new List<String>{ 'A', 'B', 'C', 'D', 'E' },
            'TIPO_COMP'  => new List<String>{ 'FC', 'NC', 'Remito', 'Remito de Devolución' },
            'VARIEDADES' => new List<String>{ 'VAR-1', 'VAR-2', 'VAR-3' },
            'CAMPANAS'   => new List<String>{ '2025', '2026' }
        };

        Test.startTest();
        String resultado = PlantillaVtasInfXlsxBuilder.patchSheet1DataValidations(sheet1, dicc);
        Test.stopTest();

        System.assert(!resultado.contains('Kilos Totales debe ser un entero mayor o igual a 20'),
            'Kilos Totales ya no debe imponer mínimo 20 kg en plantilla.');
        System.assert(!resultado.contains('<formula1>20</formula1>'),
            'No debe forzar formula1=20 en validación de kilos.');
        System.assert(resultado.contains('Comentarios!$D$5:$D$8'),
            'Tipo Comprobante debe abarcar hasta D8 (4 valores).');
        System.assert(resultado.contains('Comentarios!$F$5:$F$6'),
            'Campa\u00f1a debe apuntar a F5:F6 (2 campa\u00f1as).');
        System.assert(resultado.contains('Comentarios!$E$5:$E$7'),
            'Variedad debe apuntar a E5:E7 (3 variedades).');
        System.assert(resultado.contains('<x14:dataValidations count="4"'),
            'Debe haber 4 validaciones x14 ahora.');
        System.assert(resultado.contains('A2:A23'),
            'Campa\u00f1a debe tener desplegable hasta fila 23.');
        System.assert(resultado.contains('J2:J23'),
            'Variedad debe tener desplegable hasta fila 23 (col J).');
        System.assert(resultado.contains('I2:I23'),
            'Tipo comprobante en columna I.');
        System.assert(resultado.contains('B2:B23'),
            'Kilos Totales debe validar hasta fila 23.');
    }

    @isTest
    static void remapValidacionesLayoutAJTest() {
        String xml = '<dataValidation type="textLength" sqref="I2:I23"/>'
            + '<xm:sqref>K2:K23</xm:sqref><dataValidation sqref="D2:E23"/>'
            + '<dataValidation type="whole" operator="equal" sqref="G2:G23"><formula1>1</formula1></dataValidation>';
        String out = PlantillaVtasInfXlsxBuilder.remapValidacionesLayoutAJ(xml);
        System.assert(out.contains('sqref="G2:G23"') == false || !out.contains('operator="equal"'),
            'Quita validaci\u00f3n kilos/bolsa=1 en G.');
        System.assert(out.contains('sqref="D2:D23"'), 'CUIT solo columna D.');
        System.assert(!out.contains('type="textLength"'), 'Se quita la validaci\u00f3n de 16 d\u00edgitos del N\u00b0 de Comprobante.');
        System.assert(out.contains('<xm:sqref>I2:I23</xm:sqref>'), 'Tipo en I.');
    }

    @isTest
    static void pegarDatosSheetYWorkbookTest() {
        String pegar = PlantillaVtasInfXlsxBuilder.buildPegarDatosSheet();
        System.assert(pegar.contains('Pegá aquí los datos'), 'Debe instruir pegar en esta hoja.');
        System.assert(pegar.contains('Campaña Agrícola'), 'Debe repetir encabezados de Datos.');
        System.assert(pegar.contains('A1:J'), 'Hoja Pegar datos con 10 columnas A-J.');

        Map<String, Blob> entradasNuevo = new Map<String, Blob>{
            'xl/worksheets/sheet3.xml' => Blob.valueOf('<worksheet>CampanaAgricola</worksheet>')
        };
        PlantillaVtasInfXlsxBuilder.addPegarDatosToWorkbook(entradasNuevo);
        System.assert(entradasNuevo.get('xl/worksheets/sheet3.xml').toString().contains('CampanaAgricola'),
            'Modelo nuevo con REFERENCIAS no reemplaza sheet3.');
    }

    @isTest
    static void patchSheet1HeadersRenombraCampana() {
        String sheet1 = '<c r="A1" t="inlineStr"><is><t>Campana_de_Ventas__c</t></is></c>';
        String out = PlantillaVtasInfXlsxBuilder.patchSheet1Headers(sheet1);
        System.assert(out.contains('Campaña Agrícola'), 'Col A debe mostrar el label del Pop Up.');
        System.assert(!out.contains('Campana_de_Ventas__c'), 'No debe quedar el API name viejo en A1.');
    }

    @isTest
    static void patchSheet1HeadersUsaLabelsComprobante() {
        String sheet1 =
              '<c r="E1" t="inlineStr"><is><t>Fecha_de_Facturacion__c</t></is></c>'
            + '<c r="F1" t="inlineStr"><is><t>Linea_Facturacion__c</t></is></c>';
        String out = PlantillaVtasInfXlsxBuilder.patchSheet1Headers(sheet1);
        System.assert(out.contains('Fecha Comprobante'), 'Fecha debe usar label Comprobante.');
        System.assert(out.contains('Línea del Comprobante'), 'Línea debe usar label Comprobante.');
        System.assert(!out.contains('Facturacion'), 'No debe quedar Facturacion en encabezados.');
    }

    @isTest
    static void patchSheet1QuitaValidacionFecha() {
        String sheet1 = '<dataValidations count="2">'
            + '<dataValidation type="date" sqref="E2:E23" xr:uid="{abc}"/>'
            + '<dataValidation sqref="B2:B23" xr:uid="{def}"/>'
            + '</dataValidations>';
        Map<String, List<String>> dicc = PlantillaVtasInfXlsxBuilder.loadDiccionarios();
        String out = PlantillaVtasInfXlsxBuilder.patchSheet1DataValidations(sheet1, dicc);
        System.assert(!out.contains('sqref="E2:E23"'), 'No debe forzar formato fecha en Excel.');
    }

    @isTest
    static void escapeXmlTest() {
        System.assertEquals('', PlantillaVtasInfXlsxBuilder.escapeXml(null));
        System.assertEquals('a &amp; b', PlantillaVtasInfXlsxBuilder.escapeXml('a & b'));
        System.assertEquals('&lt;tag&gt;', PlantillaVtasInfXlsxBuilder.escapeXml('<tag>'));
    }

    @isTest
    static void xlsxGeneradoContieneVariedadesYValidacionesNuevas() {
        Test.startTest();
        String b64 = PlantillaVtasInfXlsxBuilder.generarPlantillaBase64(false);
        Test.stopTest();

        Blob zipBlob = EncodingUtil.base64Decode(b64);
        Compression.ZipReader zr = new Compression.ZipReader(zipBlob);

        String sheet2 = null;
        String sheet1 = null;
        String sheet3 = null;
        String workbook = null;
        for (Compression.ZipEntry e : zr.getEntries()) {
            if (e.getName() == 'xl/worksheets/sheet2.xml') sheet2 = e.getContent().toString();
            if (e.getName() == 'xl/worksheets/sheet1.xml') sheet1 = e.getContent().toString();
            if (e.getName() == 'xl/worksheets/sheet3.xml') sheet3 = e.getContent().toString();
            if (e.getName() == 'xl/workbook.xml') workbook = e.getContent().toString();
        }

        System.assertNotEquals(null, sheet1, 'sheet1.xml debe estar en el zip generado.');

        if (sheet1.contains('REFERENCIAS!')) {
            System.assertNotEquals(null, sheet3, 'sheet3 REFERENCIAS debe estar en el zip generado.');
            System.assert(sheet3.contains('SOJA DM 4615'), 'Variedad SOJA DM 4615 debe estar en REFERENCIAS.');
            System.assert(sheet3.contains('Remito de Devoluci'), 'Remito de Devoluci\u00f3n debe estar en REFERENCIAS.');
            System.assert(sheet3.contains('tabColor'), 'REFERENCIAS debe conservar color de pesta\u00f1a.');
            System.assert(sheet3.contains('<sheetProtection'), 'REFERENCIAS debe estar protegida.');
            System.assert(sheet3.contains('selectLockedCells="0"'),
                'REFERENCIAS debe permitir seleccionar/copiar (selectLockedCells=0 en OOXML).');
            System.assert(sheet1.contains('tabSelected="1"'), 'CARGA debe ser la hoja activa.');
            System.assertNotEquals(null, workbook, 'workbook.xml debe estar en el zip.');
            System.assert(workbook.contains('activeTab="0"'), 'Excel debe abrir en pesta\u00f1a CARGA.');
            System.assert(sheet2 == null || !sheet2.contains('tabSelected="1"'),
                'INSTRUCCIONES no debe quedar como hoja activa.');
            System.assert(sheet3 == null || !sheet3.contains('tabSelected="1"'),
                'REFERENCIAS no debe quedar como hoja activa.');
            System.assert(sheet1.contains('REFERENCIAS!$E$3:$E$'),
                'Debe haber data validation de Variedad apuntando a REFERENCIAS col E.');
            System.assert(sheet1.contains('REFERENCIAS!$B$3:$B$'),
                'Debe haber data validation de Campa\u00f1a apuntando a REFERENCIAS col B.');
            System.assert(sheet1.contains('J4:J'), 'Variedad en columna J desde fila 4.');
            System.assert(sheet1.contains('A4:A') && sheet1.contains('C4:C'),
                'Desplegables deben cubrir desde fila 4.');
        } else {
            System.assertNotEquals(null, sheet2, 'sheet2.xml legacy debe estar en el zip generado.');
            System.assert(sheet2.contains('SOJA DM 4615'), 'Variedad SOJA DM 4615 debe estar en Comentarios.');
            System.assert(sheet1.contains('Comentarios!$E$5:$E$'),
                'Debe haber data validation de Variedad apuntando a Comentarios col E.');
            System.assert(sheet1.contains('J2:J23'),
                'Variedad en columna J hasta fila 23.');
        }

        System.assert(!sheet1.contains('Kilos Totales debe ser un entero mayor o igual a 20'),
            'Kilos Totales ya no debe imponer mínimo 20 kg en plantilla.');
        System.assert(!sheet1.contains('hidden="1"'),
            'No debe ocultar columnas: el SR ya define el layout A-J.');
    }

    @isTest
    static void referenciasProtegidaPermiteCopiarYReemplazaProteccionExistente() {
        String xml = '<worksheet><mergeCells count="1"/>'
            + '<sheetProtection sheet="1" selectLockedCells="1" selectUnlockedCells="1"/>'
            + '<pageMargins/></worksheet>';
        String patched = PlantillaVtasInfXlsxBuilder.patchSheetReferenciasProtegida(xml);

        System.assertEquals(1, patched.split('sheetProtection').size() - 1,
            'Debe quedar una sola etiqueta sheetProtection.');
        System.assert(patched.contains('selectLockedCells="0"'),
            'Debe permitir seleccionar celdas bloqueadas para copiar.');
        System.assert(patched.contains('insertRows="1"'),
            'Debe bloquear inserción de filas.');
    }
}