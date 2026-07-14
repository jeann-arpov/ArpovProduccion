/**
 * Genera la plantilla XLSX de Ventas Informadas SERVER-SIDE.
 *
 * Base: StaticResource "Vtas_Informadas_Vacio" (planilla actualizada PLANIL-1).
 * Hojas: CARGA (datos), INSTRUCCIONES, REFERENCIAS (listas para desplegables).
 *
 * REFERENCIAS usa columnas B–E (Campaña, Categoría, Tipo, Variedad). La hoja queda protegida
 * (sin editar) pero permite seleccionar y copiar valores.
 *   - REFERENCIAS (sheet3): campañas, categorías, tipos de comprobante y variedades INASE.
 *   - CARGA (sheet1): rangos de data validation que apuntan a REFERENCIAS.
 */
public without sharing class PlantillaVtasInfXlsxBuilder {

    @TestVisible private static final String NOMBRE_STATIC_RESOURCE = 'Vtas_Informadas_Vacio';
    /** Fila de encabezados en hoja CARGA (1-based). */
    @TestVisible private static final Integer FILA_ENCABEZADOS_CARGA = 3;
    /** Primera fila de datos en hoja CARGA. */
    @TestVisible private static final Integer FILA_INICIO_DATOS = 4;
    /** Última fila con validaciones en CARGA legacy (1-based). */
    @TestVisible private static final Integer ULT_FILA_DATOS_LEGACY = 23;
    /** Última fila con validaciones en CARGA modelo nuevo (1-based). */
    @TestVisible private static final Integer ULT_FILA_DATOS = 503;
    @TestVisible private static final String ULT_COL_DATOS = 'J';
    @TestVisible private static final Integer REF_FILA_ENCABEZADO = 2;
    /** Columnas en REFERENCIAS: B=Campaña, C=Categoría, D=Tipo, E=Variedad. */
    @TestVisible private static final String REF_COL_CAMPANA = 'B';
    @TestVisible private static final String REF_COL_CATEGORIA = 'C';
    @TestVisible private static final String REF_COL_TIPO = 'D';
    @TestVisible private static final String REF_COL_VARIEDAD = 'E';
    /** Primera fila de valores en REFERENCIAS. */
    @TestVisible private static final Integer REF_FILA_INICIO = 3;

    @AuraEnabled
    public static String generarPlantillaBase64(Boolean sinCuitOriginante) {
        try {
            return buildXlsxBase64();
        } catch (Exception e) {
            throw new AuraHandledException('No se pudo generar la plantilla: ' + e.getMessage());
        }
    }

    @TestVisible
    private static String buildXlsxBase64() {
        StaticResource sr = [
            SELECT Id, Body FROM StaticResource WHERE Name = :NOMBRE_STATIC_RESOURCE LIMIT 1
        ];

        Compression.ZipReader zr = new Compression.ZipReader(sr.Body);
        Map<String, Blob> entradas = new Map<String, Blob>();
        for (Compression.ZipEntry entrada : zr.getEntries()) {
            String nombre = entrada.getName();
            if (!nombre.endsWith('/')) {
                entradas.put(nombre, entrada.getContent());
            }
        }

        Map<String, List<String>> dicc = loadDiccionarios();

        if (entradas.containsKey('xl/worksheets/sheet3.xml')) {
            String sheet3Xml = patchReferenciasSheet(
                entradas.get('xl/worksheets/sheet3.xml').toString(),
                dicc
            );
            sheet3Xml = patchSheetQuitarTabSelected(sheet3Xml);
            entradas.put(
                'xl/worksheets/sheet3.xml',
                Blob.valueOf(patchSheetReferenciasProtegida(sheet3Xml))
            );
        } else if (entradas.containsKey('xl/worksheets/sheet2.xml')) {
            entradas.put(
                'xl/worksheets/sheet2.xml',
                Blob.valueOf(patchReferenciasSheetLegacy(entradas.get('xl/worksheets/sheet2.xml').toString(), dicc))
            );
        }

        String sheet1Key = entradas.containsKey('xl/worksheets/sheet1.xml')
            ? 'xl/worksheets/sheet1.xml'
            : null;
        if (sheet1Key != null) {
            String sheet1Modificado = patchSheet1DataValidations(
                entradas.get(sheet1Key).toString(),
                dicc
            );
            entradas.put(sheet1Key, Blob.valueOf(patchSheetCargaActiva(sheet1Modificado)));
        }

        if (entradas.containsKey('xl/worksheets/sheet2.xml') && entradas.containsKey('xl/worksheets/sheet3.xml')) {
            entradas.put(
                'xl/worksheets/sheet2.xml',
                Blob.valueOf(patchSheetQuitarTabSelected(entradas.get('xl/worksheets/sheet2.xml').toString()))
            );
        }

        if (entradas.containsKey('xl/workbook.xml')) {
            entradas.put(
                'xl/workbook.xml',
                Blob.valueOf(patchWorkbookActiveTab(entradas.get('xl/workbook.xml').toString(), 0))
            );
        }

        Compression.ZipWriter zw = new Compression.ZipWriter();
        for (String nombre : entradas.keySet()) {
            zw.addEntry(nombre, entradas.get(nombre));
        }

        return EncodingUtil.base64Encode(zw.getArchive());
    }

    @TestVisible
    private static Map<String, List<String>> loadDiccionarios() {
        Map<String, List<String>> out = new Map<String, List<String>>();

        Set<String> variedadesSet = new Set<String>();
        for (Variedad__c v : [
            SELECT Cultivar_Inase__c FROM Variedad__c
            WHERE Cultivar_Inase__c != null
            ORDER BY Cultivar_Inase__c ASC
            LIMIT 5000
        ]) {
            if (String.isNotBlank(v.Cultivar_Inase__c)) variedadesSet.add(v.Cultivar_Inase__c);
        }
        List<String> variedades = new List<String>(variedadesSet);
        variedades.sort();
        out.put('VARIEDADES', variedades);

        out.put('CATEGORIAS', new List<String>{
            'Pre Básica',
            'Original o Fundadora',
            'Primera Multiplicación',
            'Segunda Multiplicación',
            'Tercera Multiplicación'
        });

        out.put('TIPO_COMP', new List<String>{
            'FC', 'NC', 'Remito', 'Remito de Devolución'
        });

        out.put('CAMPANAS', buildAnosCampanaLista());

        return out;
    }

    /**
     * Parchea solo los valores de REFERENCIAS conservando formato, colores y estructura del SR.
     */
    @TestVisible
    private static String patchReferenciasSheet(String sheetXml, Map<String, List<String>> dicc) {
        if (String.isBlank(sheetXml)) {
            return buildReferenciasSheet(dicc);
        }

        Integer idxData = sheetXml.indexOf('<sheetData>');
        Integer idxEndData = sheetXml.indexOf('</sheetData>');
        if (idxData < 0 || idxEndData < 0) {
            return buildReferenciasSheet(dicc);
        }

        List<String> campanas = dicc.get('CAMPANAS');
        List<String> categorias = dicc.get('CATEGORIAS');
        List<String> tiposComp = dicc.get('TIPO_COMP');
        List<String> variedades = dicc.get('VARIEDADES');

        Integer maxItems = Math.max(
            Math.max(campanas.size(), categorias.size()),
            Math.max(tiposComp.size(), variedades.size())
        );
        Integer ultRow = REF_FILA_INICIO + Math.max(1, maxItems) - 1;

        String header = sheetXml.substring(0, idxData);
        String footer = sheetXml.substring(idxEndData + '</sheetData>'.length());
        String originalData = sheetXml.substring(idxData + '<sheetData>'.length(), idxEndData);

        header = header.replaceAll('<dimension ref="B1:E\\d+"', '<dimension ref="B1:E' + ultRow + '"');
        header = header.replaceAll('<dimension ref="A1:D\\d+"', '<dimension ref="B1:E' + ultRow + '"');

        String row1 = extraerFilaSheet(originalData, 1);
        String row2 = extraerFilaSheet(originalData, 2);
        if (row1 == null) {
            row1 = '<row r="1" ht="27.75" customHeight="1" spans="2:5">'
                + inlineStrCell('C1', '31', 'VALORES DE REFERENCIA — No modificar este listado')
                + '</row>';
        }
        if (row2 == null) {
            row2 = '<row r="2" ht="24" customHeight="1" spans="2:5">'
                + inlineStrCell('B2', '2', 'CampanaAgricola')
                + inlineStrCell('C2', '2', 'Categoria')
                + inlineStrCell('D2', '2', 'Tipo de Comprobante')
                + inlineStrCell('E2', '2', 'Variedad')
                + '</row>';
        }

        String dataRows = '';
        for (Integer i = 0; i < maxItems; i++) {
            Integer r = REF_FILA_INICIO + i;
            dataRows += '<row r="' + r + '" spans="2:5">';
            if (i < campanas.size()) {
                dataRows += inlineStrCell(REF_COL_CAMPANA + r, '20', campanas[i]);
            } else {
                dataRows += '<c r="' + REF_COL_CAMPANA + r + '" s="20"/>';
            }
            if (i < categorias.size()) {
                dataRows += inlineStrCell(REF_COL_CATEGORIA + r, '1', categorias[i]);
            }
            if (i < tiposComp.size()) {
                dataRows += inlineStrCell(REF_COL_TIPO + r, '1', tiposComp[i]);
            }
            if (i < variedades.size()) {
                dataRows += inlineStrCell(REF_COL_VARIEDAD + r, '1', variedades[i]);
            }
            dataRows += '</row>';
        }

        return header + '<sheetData>' + row1 + row2 + dataRows + '</sheetData>' + footer;
    }

    @TestVisible
    private static String patchReferenciasSheetLegacy(String sheetXml, Map<String, List<String>> dicc) {
        if (String.isBlank(sheetXml)) {
            return buildReferenciasSheetLegacy(dicc);
        }
        Integer idxData = sheetXml.indexOf('<sheetData>');
        Integer idxEndData = sheetXml.indexOf('</sheetData>');
        if (idxData < 0 || idxEndData < 0) {
            return buildReferenciasSheetLegacy(dicc);
        }

        List<String> categorias = dicc.get('CATEGORIAS');
        List<String> tiposComp = dicc.get('TIPO_COMP');
        List<String> variedades = dicc.get('VARIEDADES');
        List<String> campanas = dicc.get('CAMPANAS');

        Integer maxRow = Math.max(
            Math.max(5 + variedades.size() - 1, 5 + campanas.size() - 1),
            Math.max(5 + categorias.size() - 1, 5 + tiposComp.size() - 1)
        );

        String header = sheetXml.substring(0, idxData);
        String footer = sheetXml.substring(idxEndData + '</sheetData>'.length());
        String originalData = sheetXml.substring(idxData + '<sheetData>'.length(), idxEndData);

        String rowHeader = extraerFilaSheet(originalData, 4);
        if (rowHeader == null) {
            rowHeader = '<row r="4">'
                + inlineStrCell('B4', '4', 'Categoria__c')
                + inlineStrCell('D4', '4', 'Tipo_de_Comprobante__c')
                + inlineStrCell('E4', '4', 'Variedad__c')
                + inlineStrCell('F4', '4', 'Campana_Agricola__c')
                + '</row>';
        }

        String dataRows = '';
        for (Integer r = 5; r <= maxRow; r++) {
            Integer idx = r - 5;
            dataRows += '<row r="' + r + '">';
            if (idx < categorias.size()) dataRows += inlineStrCell('B' + r, null, categorias[idx]);
            if (idx < tiposComp.size()) dataRows += inlineStrCell('D' + r, null, tiposComp[idx]);
            if (idx < variedades.size()) dataRows += inlineStrCell('E' + r, null, variedades[idx]);
            if (idx < campanas.size()) dataRows += inlineStrCell('F' + r, null, campanas[idx]);
            dataRows += '</row>';
        }

        return header + '<sheetData>' + rowHeader + dataRows + '</sheetData>' + footer;
    }

    @TestVisible
    private static String extraerFilaSheet(String sheetDataInner, Integer rowNum) {
        if (String.isBlank(sheetDataInner) || rowNum == null) {
            return null;
        }
        Pattern p = Pattern.compile('<row r="' + rowNum + '"[^>]*>.*?</row>');
        Matcher m = p.matcher(sheetDataInner);
        return m.find() ? m.group() : null;
    }

    @TestVisible
    private static String patchWorkbookActiveTab(String workbookXml, Integer tabIndex) {
        if (String.isBlank(workbookXml) || tabIndex == null) {
            return workbookXml;
        }
        if (workbookXml.contains('activeTab="')) {
            return workbookXml.replaceAll('activeTab="\\d+"', 'activeTab="' + tabIndex + '"');
        }
        return workbookXml.replace(
            '<workbookView ',
            '<workbookView activeTab="' + tabIndex + '" '
        );
    }

    @TestVisible
    private static String patchSheetCargaActiva(String sheetXml) {
        if (String.isBlank(sheetXml) || sheetXml.contains('tabSelected="1"')) {
            return sheetXml;
        }
        return sheetXml.replace('<sheetView ', '<sheetView tabSelected="1" ');
    }

    /**
     * Protección OOXML: atributo="1" restringe la acción; "0" la permite.
     * selectLockedCells="0" → el usuario puede seleccionar y copiar celdas bloqueadas.
     */
    @TestVisible
    private static String buildReferenciasSheetProtection() {
        return '<sheetProtection sheet="1" objects="1" scenarios="1"'
            + ' formatCells="1" formatColumns="1" formatRows="1"'
            + ' insertColumns="1" insertRows="1" insertHyperlinks="1"'
            + ' deleteColumns="1" deleteRows="1" selectLockedCells="0"'
            + ' sort="1" autoFilter="1" pivotTables="1" selectUnlockedCells="0"/>';
    }

    @TestVisible
    private static String patchSheetReferenciasProtegida(String sheetXml) {
        if (String.isBlank(sheetXml)) {
            return sheetXml;
        }
        String protection = buildReferenciasSheetProtection();
        if (sheetXml.contains('<sheetProtection')) {
            return sheetXml.replaceAll('<sheetProtection[^>]*/>', protection);
        }
        if (sheetXml.contains('<mergeCells')) {
            return sheetXml.replace('<mergeCells', protection + '<mergeCells');
        }
        if (sheetXml.contains('<pageMargins')) {
            return sheetXml.replace('<pageMargins', protection + '<pageMargins');
        }
        return sheetXml.replace('</worksheet>', protection + '</worksheet>');
    }

    @TestVisible
    private static String patchSheetQuitarTabSelected(String sheetXml) {
        if (String.isBlank(sheetXml)) {
            return sheetXml;
        }
        return sheetXml.replace(' tabSelected="1"', '');
    }

    /**
     * Fallback si no hay XML base (tests unitarios aislados).
     */
    @TestVisible
    private static String buildReferenciasSheet(Map<String, List<String>> dicc) {
        List<String> campanas = dicc.get('CAMPANAS');
        List<String> categorias = dicc.get('CATEGORIAS');
        List<String> tiposComp = dicc.get('TIPO_COMP');
        List<String> variedades = dicc.get('VARIEDADES');

        Integer maxItems = Math.max(
            Math.max(campanas.size(), categorias.size()),
            Math.max(tiposComp.size(), variedades.size())
        );
        Integer ultRow = REF_FILA_INICIO + Math.max(1, maxItems) - 1;

        String rows = '';
        rows += '<row r="1" ht="27.75" customHeight="1" spans="2:5">';
        rows += inlineStrCell('C1', null, 'VALORES DE REFERENCIA — No modificar este listado');
        rows += '</row>';

        rows += '<row r="2" ht="24" customHeight="1" spans="2:5">';
        rows += inlineStrCell('B2', null, 'CampanaAgricola');
        rows += inlineStrCell('C2', null, 'Categoria');
        rows += inlineStrCell('D2', null, 'Tipo de Comprobante');
        rows += inlineStrCell('E2', null, 'Variedad');
        rows += '</row>';

        for (Integer i = 0; i < maxItems; i++) {
            Integer r = REF_FILA_INICIO + i;
            rows += '<row r="' + r + '" spans="2:5">';
            if (i < campanas.size()) rows += inlineStrCell(REF_COL_CAMPANA + r, null, campanas[i]);
            if (i < categorias.size()) rows += inlineStrCell(REF_COL_CATEGORIA + r, null, categorias[i]);
            if (i < tiposComp.size()) rows += inlineStrCell(REF_COL_TIPO + r, null, tiposComp[i]);
            if (i < variedades.size()) rows += inlineStrCell(REF_COL_VARIEDAD + r, null, variedades[i]);
            rows += '</row>';
        }

        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            + '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            + '<dimension ref="B1:E' + ultRow + '"/>'
            + '<sheetViews><sheetView workbookViewId="0"/></sheetViews>'
            + '<sheetFormatPr defaultRowHeight="12.5"/>'
            + '<cols>'
            + '<col min="2" max="3" width="22" customWidth="1"/>'
            + '<col min="4" max="4" width="23.5" customWidth="1"/>'
            + '<col min="5" max="5" width="21" customWidth="1"/>'
            + '</cols>'
            + '<sheetData>' + rows + '</sheetData>'
            + '<mergeCells count="1"><mergeCell ref="C1:E1"/></mergeCells>'
            + buildReferenciasSheetProtection()
            + '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>'
            + '</worksheet>';
    }

    /** Layout legacy Comentarios (B/D/E/F, fila 4 encabezados). */
    @TestVisible
    private static String buildReferenciasSheetLegacy(Map<String, List<String>> dicc) {
        List<String> categorias = dicc.get('CATEGORIAS');
        List<String> tiposComp = dicc.get('TIPO_COMP');
        List<String> variedades = dicc.get('VARIEDADES');
        List<String> campanas = dicc.get('CAMPANAS');

        Integer ultRowVar = 5 + Math.max(1, variedades.size()) - 1;
        Integer ultRowCam = 5 + Math.max(1, campanas.size()) - 1;
        Integer ultRowCat = 5 + categorias.size() - 1;
        Integer ultRowTc = 5 + tiposComp.size() - 1;
        Integer maxRow = Math.max(Math.max(ultRowVar, ultRowCam), Math.max(ultRowCat, ultRowTc));

        String rows = '';
        rows += '<row r="4">';
        rows += inlineStrCell('B4', '4', 'Categoria__c');
        rows += inlineStrCell('D4', '4', 'Tipo_de_Comprobante__c');
        rows += inlineStrCell('E4', '4', 'Variedad__c');
        rows += inlineStrCell('F4', '4', 'Campana_Agricola__c');
        rows += '</row>';

        for (Integer r = 5; r <= maxRow; r++) {
            rows += '<row r="' + r + '">';
            Integer idx = r - 5;
            if (idx < categorias.size()) rows += inlineStrCell('B' + r, null, categorias[idx]);
            if (idx < tiposComp.size()) rows += inlineStrCell('D' + r, null, tiposComp[idx]);
            if (idx < variedades.size()) rows += inlineStrCell('E' + r, null, variedades[idx]);
            if (idx < campanas.size()) rows += inlineStrCell('F' + r, null, campanas[idx]);
            rows += '</row>';
        }

        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            + '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            + '<dimension ref="B4:F' + maxRow + '"/>'
            + '<sheetViews><sheetView workbookViewId="0"/></sheetViews>'
            + '<sheetFormatPr defaultRowHeight="13.2"/>'
            + '<cols>'
            + '<col min="2" max="2" width="22" customWidth="1"/>'
            + '<col min="4" max="4" width="26" customWidth="1"/>'
            + '<col min="5" max="5" width="32" customWidth="1"/>'
            + '<col min="6" max="6" width="22" customWidth="1"/>'
            + '</cols>'
            + '<sheetData>' + rows + '</sheetData>'
            + '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>'
            + '</worksheet>';
    }

    /** Alias de tests legacy. */
    @TestVisible
    private static String buildComentariosSheet(Map<String, List<String>> dicc) {
        return buildReferenciasSheetLegacy(dicc);
    }

    @TestVisible
    private static String patchSheet1DataValidations(String sheet1, Map<String, List<String>> dicc) {
        if (esPlantillaNuevoModelo(sheet1)) {
            return patchSheet1DataValidationsNuevo(sheet1, dicc);
        }
        return patchSheet1DataValidationsLegacy(sheet1, dicc);
    }

    @TestVisible
    private static Boolean esPlantillaNuevoModelo(String sheet1) {
        return sheet1 != null && sheet1.contains('REFERENCIAS!');
    }

  /**
     * CARGA (Modelo Nuevo V.1) — encabezados fila 3, datos desde fila 4:
     *   A=Campaña  B=Kilos  C=Categoría  D=CUIT  E=Razón Social  F=Fecha
     *   G=Línea  H=N° Comprobante  I=Tipo  J=Variedad
     */
    @TestVisible
    private static String patchSheet1DataValidationsNuevo(String sheet1, Map<String, List<String>> dicc) {
        Integer ultRowVar = REF_FILA_INICIO + Math.max(1, dicc.get('VARIEDADES').size()) - 1;
        Integer ultRowCam = REF_FILA_INICIO + Math.max(1, dicc.get('CAMPANAS').size()) - 1;
        Integer ultRowCat = REF_FILA_INICIO + dicc.get('CATEGORIAS').size() - 1;
        Integer ultRowTc = REF_FILA_INICIO + dicc.get('TIPO_COMP').size() - 1;

        sheet1 = sheet1.replaceAll('sqref="D4:E(\\d+)"', 'sqref="D4:D$1"');
        sheet1 = reemplazarRangoReferencias(sheet1, REF_COL_CAMPANA, ultRowCam);
        sheet1 = reemplazarRangoReferencias(sheet1, REF_COL_CATEGORIA, ultRowCat);
        sheet1 = reemplazarRangoReferencias(sheet1, REF_COL_TIPO, ultRowTc);
        sheet1 = reemplazarRangoReferencias(sheet1, REF_COL_VARIEDAD, ultRowVar);

        return sheet1;
    }

    private static String reemplazarRangoReferencias(String sheet1, String col, Integer ultRow) {
        String patron = 'REFERENCIAS!\\$' + col + '\\$3:\\$' + col + '\\$\\d+';
        String reemplazo = Matcher.quoteReplacement('REFERENCIAS!$' + col + '$3:$' + col + '$' + ultRow);
        return Pattern.compile(patron).matcher(sheet1).replaceAll(reemplazo);
    }

    @TestVisible
    private static String patchSheet1DataValidationsLegacy(String sheet1, Map<String, List<String>> dicc) {
        sheet1 = remapValidacionesLayoutAJ(sheet1);
        Integer ultRowVar = 5 + Math.max(1, dicc.get('VARIEDADES').size()) - 1;
        Integer ultRowCam = 5 + Math.max(1, dicc.get('CAMPANAS').size()) - 1;
        Integer ultRowTc = 5 + dicc.get('TIPO_COMP').size() - 1;

        for (String colFecha : new List<String>{ 'E', 'F' }) {
            sheet1 = sheet1.replaceAll(
                '<dataValidation[^>]*sqref="' + colFecha + '2:' + colFecha + '\\d+"[^>]*/>',
                ''
            );
            sheet1 = sheet1.replaceAll(
                '<dataValidation[^>]*sqref="' + colFecha + '2:' + colFecha + '\\d+"[^>]*>\\s*<formula1>[^<]*</formula1>\\s*</dataValidation>',
                ''
            );
        }

        String sqD = 'D2:D' + ULT_FILA_DATOS_LEGACY;
        if (!Pattern.compile('sqref="D2:D\\d+"').matcher(sheet1).find()) {
            sheet1 = sheet1.replace(
                '</dataValidations>',
                '<dataValidation type="whole" operator="between" allowBlank="1" showInputMessage="1" showErrorMessage="1"'
                + ' prompt="CUIT Destinatario (solo n&#250;meros)" sqref="' + sqD + '">'
                + '<formula1>10000000000</formula1><formula2>99999999999</formula2></dataValidation></dataValidations>'
            );
            Pattern pCnt = Pattern.compile('<dataValidations count="(\\d+)"');
            Matcher mCnt = pCnt.matcher(sheet1);
            if (mCnt.find()) {
                Integer c = Integer.valueOf(mCnt.group(1)) + 1;
                sheet1 = mCnt.replaceFirst('<dataValidations count="' + c + '"');
            }
        }

        sheet1 = sheet1.replace(
            '<xm:f>Comentarios!$D$5:$D$7</xm:f>',
            '<xm:f>Comentarios!$D$5:$D$' + ultRowTc + '</xm:f>'
        );

        String sqA = 'A2:A' + ULT_FILA_DATOS_LEGACY;
        String sqJ = 'J2:J' + ULT_FILA_DATOS_LEGACY;
        String nuevasX14 =
              '<x14:dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1"'
            + ' errorTitle="Campa&#241;a no v&#225;lida" error="Seleccion&#225; una campa&#241;a de la lista">'
            +   '<x14:formula1><xm:f>Comentarios!$F$5:$F$' + ultRowCam + '</xm:f></x14:formula1>'
            +   '<xm:sqref>' + sqA + '</xm:sqref>'
            + '</x14:dataValidation>'
            + '<x14:dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1"'
            + ' errorTitle="Variedad no v&#225;lida" error="Seleccion&#225; una variedad de la lista (cultivar INASE)">'
            +   '<x14:formula1><xm:f>Comentarios!$E$5:$E$' + ultRowVar + '</xm:f></x14:formula1>'
            +   '<xm:sqref>' + sqJ + '</xm:sqref>'
            + '</x14:dataValidation>';

        if (sheet1.contains('<x14:dataValidations count="2"')) {
            sheet1 = sheet1.replace(
                '<x14:dataValidations count="2" xmlns:xm="http://schemas.microsoft.com/office/excel/2006/main">',
                '<x14:dataValidations count="4" xmlns:xm="http://schemas.microsoft.com/office/excel/2006/main">'
            );
            sheet1 = sheet1.replace('</x14:dataValidations>', nuevasX14 + '</x14:dataValidations>');
        } else if (!sheet1.contains('<xm:sqref>A2:A')) {
            sheet1 = sheet1.replace('</x14:dataValidations>', nuevasX14 + '</x14:dataValidations>');
            Pattern pX14 = Pattern.compile('<x14:dataValidations count="(\\d+)"');
            Matcher mX14 = pX14.matcher(sheet1);
            if (mX14.find()) {
                Integer c = Integer.valueOf(mX14.group(1)) + 2;
                sheet1 = mX14.replaceFirst('<x14:dataValidations count="' + c + '"');
            }
        }

        return sheet1;
    }

    @TestVisible
    private static String patchSheet1Headers(String sheet1) {
        if (sheet1 == null) return sheet1;
        String patched = sheet1
            .replace('>Campana_de_Ventas__c<', '>Campaña Agrícola<')
            .replace('>Campana_de_Ventas__c</t>', '>Campaña Agrícola</t>')
            .replace('>Fecha_de_Facturacion__c<', '>Fecha Comprobante<')
            .replace('>Fecha_de_Facturacion__c</t>', '>Fecha Comprobante</t>')
            .replace('>Fecha de Facturación<', '>Fecha Comprobante<')
            .replace('>Fecha de Facturacion<', '>Fecha Comprobante<')
            .replace('>Fecha de Facturación</t>', '>Fecha Comprobante</t>')
            .replace('>Fecha de Facturacion</t>', '>Fecha Comprobante</t>')
            .replace('>Linea_Facturacion__c<', '>Línea del Comprobante<')
            .replace('>Linea_Facturacion__c</t>', '>Línea del Comprobante</t>')
            .replace('>Linea Facturacion<', '>Línea del Comprobante<')
            .replace('>Linea Facturacion</t>', '>Línea del Comprobante</t>')
            .replace('>Línea Facturación<', '>Línea del Comprobante<')
            .replace('>Línea Facturación</t>', '>Línea del Comprobante</t>')
            .replace('>Línea Facturacion<', '>Línea del Comprobante<')
            .replace('>Línea Facturacion</t>', '>Línea del Comprobante</t>');
        return patched;
    }

    @TestVisible
    private static String remapValidacionesLayoutAJ(String sheet1) {
        if (sheet1 == null) return sheet1;
        String s = sheet1;

        s = s.replaceAll('<dataValidation[^>]*sqref="G2:G\\d+"[^>]*operator="equal"[^>]*/>', '');
        s = s.replaceAll(
            '<dataValidation type="whole" operator="equal"[^>]*sqref="G2:G\\d+"[^>]*>\\s*<formula1>1</formula1>\\s*</dataValidation>',
            ''
        );

        s = s.replaceAll('sqref="D2:E(\\d+)"', 'sqref="D2:D$1"');
        s = s.replaceAll('<dataValidation type="textLength"[^>]*/>', '');
        s = s.replaceAll('<dataValidation type="textLength"[^>]*>\\s*<formula1>[^<]*</formula1>\\s*</dataValidation>', '');
        s = s.replaceAll('sqref="K2:K(\\d+)"', 'sqref="I2:I$1"');
        s = s.replaceAll('<xm:sqref>K2:K(\\d+)</xm:sqref>', '<xm:sqref>I2:I$1</xm:sqref>');
        s = s.replaceAll('sqref="L2:L(\\d+)"', 'sqref="J2:J$1"');
        s = s.replaceAll('<xm:sqref>L2:L(\\d+)</xm:sqref>', '<xm:sqref>J2:J$1</xm:sqref>');

        return s;
    }

    @TestVisible
    private static String buildPegarDatosSheet() {
        String instruccion =
            'Pegá aquí los datos copiados de otro Excel (desde A3, sin encabezados). '
            + 'No pegues en la hoja CARGA: Excel borra los desplegables al pegar desde afuera.';

        List<String> headers = new List<String>{
            'Campaña Agrícola', 'Kilos Totales', 'Categoría', 'CUIT Destinatario',
            'Razón Social Destinatario', 'Fecha Comprobante', 'Línea del Comprobante', 'N° de Comprobante',
            'Tipo de Comprobante', 'Variedad'
        };
        List<String> cols = new List<String>{ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J' };

        String rows = '';
        rows += '<row r="1" ht="28" customHeight="1">';
        rows += inlineStrCell('A1', '4', instruccion);
        rows += '</row>';

        rows += '<row r="2">';
        for (Integer i = 0; i < headers.size(); i++) {
            rows += inlineStrCell(cols[i] + '2', '4', headers[i]);
        }
        rows += '</row>';

        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            + '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            + '<dimension ref="A1:' + ULT_COL_DATOS + ULT_FILA_DATOS + '"/>'
            + '<sheetViews><sheetView tabSelected="1" workbookViewId="0">'
            + '<selection activeCell="A3" sqref="A3"/></sheetView></sheetViews>'
            + '<sheetFormatPr defaultRowHeight="13.2"/>'
            + '<cols>'
            + '<col min="1" max="5" width="22" customWidth="1"/>'
            + '<col min="6" max="10" width="22" customWidth="1"/>'
            + '</cols>'
            + '<sheetData>' + rows + '</sheetData>'
            + '<mergeCells count="1"><mergeCell ref="A1:' + ULT_COL_DATOS + '1"/></mergeCells>'
            + '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>'
            + '</worksheet>';
    }

    @TestVisible
    private static void addPegarDatosToWorkbook(Map<String, Blob> entradas) {
        if (entradas == null) {
            return;
        }
        if (entradas.containsKey('xl/worksheets/sheet3.xml')) {
            String s3 = entradas.get('xl/worksheets/sheet3.xml').toString();
            if (s3.contains('CampanaAgricola') || s3.contains('VALORES DE REFERENCIA')) {
                return;
            }
        }
    }

    @TestVisible
    public static List<String> buildAnosCampanaLista() {
        Integer anioActual = Date.today().year();
        List<String> anos = new List<String>();
        for (Integer y = anioActual - 2; y <= anioActual + 1; y++) {
            anos.add(String.valueOf(y));
        }
        return anos;
    }

    @TestVisible
    private static String inlineStrCell(String ref, String styleIdx, String texto) {
        String style = (styleIdx == null) ? '' : ' s="' + styleIdx + '"';
        return '<c r="' + ref + '"' + style + ' t="inlineStr"><is><t xml:space="preserve">'
            + escapeXml(texto) + '</t></is></c>';
    }

    @TestVisible
    private static String escapeXml(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&apos;');
    }
}