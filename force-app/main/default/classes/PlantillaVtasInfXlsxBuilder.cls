/**
 * Genera la plantilla XLSX de Ventas Informadas SERVER-SIDE.
 *
 * Base: StaticResource "Vtas_Informadas_Vacio" (planilla actualizada PLANIL-1).
 * Hojas: CARGA (datos), INSTRUCCIONES, REFERENCIAS (listas para desplegables).
 *
 * REFERENCIAS usa columnas B–F (Campaña, Categoría, Tipo, Variedad, Provincia Destino).
 * Geo estático: hoja LOCALIDADES (oculta) + desplegables K/L en CARGA vienen del Static Resource.
 * (sin editar) pero permite seleccionar y copiar valores.
 *   - REFERENCIAS (sheet3): campañas, categorías, tipos de comprobante y variedades INASE.
 *   - CARGA (sheet1): rangos de data validation que apuntan a REFERENCIAS.
 */
public without sharing class PlantillaVtasInfXlsxBuilder extends ApexErrorHandler {

    @TestVisible private static final String NOMBRE_STATIC_RESOURCE = 'Vtas_Informadas_Vacio';
    /** Fila de encabezados en hoja CARGA (1-based). */
    @TestVisible private static final Integer FILA_ENCABEZADOS_CARGA = 3;
    /** Primera fila de datos en hoja CARGA. */
    @TestVisible private static final Integer FILA_INICIO_DATOS = 4;
    /** Última fila con validaciones en CARGA legacy (1-based). */
    @TestVisible private static final Integer ULT_FILA_DATOS_LEGACY = 23;
    /** Última fila con validaciones en CARGA modelo nuevo (1-based). */
    @TestVisible private static final Integer ULT_FILA_DATOS = 503;
    @TestVisible private static final String ULT_COL_DATOS = 'L';
    @TestVisible private static final String REF_COL_PROVINCIA = 'F';
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
            throw handleException(e, 'ERR-SYS-009', 'PlantillaVtasInf');
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
        Boolean plantillaGeoEstatica = esPlantillaConGeoEstatica(entradas);

        if (entradas.containsKey('xl/worksheets/sheet3.xml')) {
            String sheet3Xml = patchReferenciasSheet(
                entradas.get('xl/worksheets/sheet3.xml').toString(),
                dicc
            );
            sheet3Xml = patchSheetQuitarTabSelected(sheet3Xml);
            // Siempre proteger REFERENCIAS (también con plantilla geo estática / sheet4).
            sheet3Xml = patchSheetReferenciasProtegida(sheet3Xml);
            entradas.put('xl/worksheets/sheet3.xml', Blob.valueOf(sheet3Xml));
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
            String sheet1Original = entradas.get(sheet1Key).toString();
            Boolean plantillaOpenpyxl = esPlantillaOpenpyxlBase(sheet1Original);
            String sheet1Modificado = patchSheet1DataValidations(sheet1Original, dicc);
            if (!plantillaGeoEstatica) {
                sheet1Modificado = patchSheet1ColumnasDestino(sheet1Modificado, dicc);
            }
            if (!plantillaOpenpyxl) {
                sheet1Modificado = patchSheet1MigrarX14Legacy(sheet1Modificado);
            }
            sheet1Modificado = patchSheet1SanitizarValidacionesLegacy(sheet1Modificado);
            entradas.put(sheet1Key, Blob.valueOf(patchSheetCargaActiva(sheet1Modificado)));
        }

        if (entradas.containsKey('xl/worksheets/sheet2.xml') && entradas.containsKey('xl/worksheets/sheet3.xml')) {
            entradas.put(
                'xl/worksheets/sheet2.xml',
                Blob.valueOf(patchSheetQuitarTabSelected(entradas.get('xl/worksheets/sheet2.xml').toString()))
            );
        }

        if (entradas.containsKey('xl/workbook.xml')) {
            String workbookXml = entradas.get('xl/workbook.xml').toString();
            workbookXml = patchWorkbookActiveTab(workbookXml, 0);
            if (!plantillaGeoEstatica) {
                workbookXml = patchWorkbookCompatibilidadLtsc(workbookXml);
            }
            entradas.put('xl/workbook.xml', Blob.valueOf(workbookXml));

            if (entradas.containsKey('docProps/app.xml')) {
                entradas.put(
                    'docProps/app.xml',
                    Blob.valueOf(patchDocPropsApp(entradas.get('docProps/app.xml').toString(), workbookXml))
                );
            }
        }

        stripRichDataFromPackage(entradas);

        Compression.ZipWriter zw = new Compression.ZipWriter();
        List<String> nombres = new List<String>(entradas.keySet());
        nombres.sort();
        for (String nombre : nombres) {
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

        String originalData = sheetXml.substring(idxData + '<sheetData>'.length(), idxEndData);

        Integer maxItems = Math.max(
            Math.max(campanas.size(), categorias.size()),
            Math.max(tiposComp.size(), variedades.size())
        );
        Integer maxProv = contarFilasConDatosColumna(originalData, REF_COL_PROVINCIA);
        maxItems = Math.max(maxItems, maxProv);
        Integer ultRow = REF_FILA_INICIO + Math.max(1, maxItems) - 1;

        String header = sheetXml.substring(0, idxData);
        String footer = sheetXml.substring(idxEndData + '</sheetData>'.length());

        header = header.replaceAll('<dimension ref="B1:F\\d+"', '<dimension ref="B1:F' + ultRow + '"');
        header = header.replaceAll('<dimension ref="B1:E\\d+"', '<dimension ref="B1:F' + ultRow + '"');
        header = header.replaceAll('<dimension ref="A1:D\\d+"', '<dimension ref="B1:F' + ultRow + '"');

        String row1 = extraerFilaSheet(originalData, 1);
        String row2 = extraerFilaSheet(originalData, 2);
        if (row1 == null) {
            row1 = '<row r="1" ht="27.75" customHeight="1" spans="2:5">'
                + inlineStrCell('C1', '31', 'VALORES DE REFERENCIA — No modificar este listado')
                + '</row>';
        }
        if (row2 == null) {
            row2 = '<row r="2" ht="24" customHeight="1" spans="2:6">'
                + inlineStrCell('B2', '2', 'CampanaAgricola')
                + inlineStrCell('C2', '2', 'Categoria')
                + inlineStrCell('D2', '2', 'Tipo de Comprobante')
                + inlineStrCell('E2', '2', 'Variedad')
                + inlineStrCell('F2', '2', 'Provincia Destino')
                + '</row>';
        } else if (
            !row2.contains('Provincia Destino')
            // Plantilla geo (sharedStrings): F2 ya existe aunque el texto no esté inline.
            && !row2.contains('r="F2"')
        ) {
            row2 = row2.replace('</row>', inlineStrCell('F2', '2', 'Provincia Destino') + '</row>');
        }

        String dataRows = '';
        for (Integer i = 0; i < maxItems; i++) {
            Integer r = REF_FILA_INICIO + i;
            String celdaProvincia = extraerCeldaColumna(originalData, r, REF_COL_PROVINCIA);
            Boolean tieneProvincia = String.isNotBlank(celdaProvincia);
            dataRows += '<row r="' + r + '" spans="' + (tieneProvincia ? '2:6' : '2:5') + '">';
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
            if (tieneProvincia) {
                dataRows += celdaProvincia;
            }
            dataRows += '</row>';
        }

        footer = footer.replace('mergeCell ref="C1:E1"', 'mergeCell ref="C1:F1"');

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
    private static String extraerCeldaColumna(String sheetDataInner, Integer rowNum, String col) {
        if (String.isBlank(sheetDataInner) || rowNum == null || String.isBlank(col)) {
            return null;
        }
        String row = extraerFilaSheet(sheetDataInner, rowNum);
        if (row == null) {
            return null;
        }
        Pattern p = Pattern.compile(
            '<c r="' + col + rowNum + '"[^>]*(?:/>|>.*?</c>)'
        );
        Matcher m = p.matcher(row);
        return m.find() ? m.group() : null;
    }

    @TestVisible
    private static Integer contarFilasConDatosColumna(String sheetDataInner, String col) {
        if (String.isBlank(sheetDataInner) || String.isBlank(col)) {
            return 0;
        }
        Integer maxRow = 0;
        Matcher m = Pattern.compile('<c r="' + col + '(\\d+)"').matcher(sheetDataInner);
        while (m.find()) {
            Integer rowNum = Integer.valueOf(m.group(1));
            if (rowNum >= REF_FILA_INICIO && rowNum > maxRow) {
                maxRow = rowNum;
            }
        }
        return maxRow >= REF_FILA_INICIO ? maxRow - REF_FILA_INICIO + 1 : 0;
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
     *   G=Línea  H=N° Comprobante  I=Tipo  J=Variedad  K=Provincia Destino  L=Localidad Destino
     */
    @TestVisible
    private static String patchSheet1ColumnasDestino(String sheet1, Map<String, List<String>> dicc) {
        if (sheet1 != null && sheet1.contains('INDIRECT("Loc_"')) {
            return sheet1;
        }
        if (!esPlantillaNuevoModelo(sheet1)) {
            return sheet1;
        }
        sheet1 = patchSheet1EncabezadosDestino(sheet1);
        List<String> provincias = dicc != null && dicc.containsKey('PROVINCIAS')
            ? dicc.get('PROVINCIAS')
            : new List<String>();
        if (provincias.isEmpty()) {
            return sheet1;
        }
        Integer ultRowProv = REF_FILA_INICIO + provincias.size() - 1;
        String sqK = 'K' + FILA_INICIO_DATOS + ':K' + ULT_FILA_DATOS;
        String formulaProv = 'REFERENCIAS!$' + REF_COL_PROVINCIA + '$' + REF_FILA_INICIO
            + ':$' + REF_COL_PROVINCIA + '$' + ultRowProv;
        if (!sheet1.contains('sqref="' + sqK + '"')) {
            String dv = '<dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1"'
                + ' prompt="Provincia de destino de la semilla" sqref="' + sqK + '">'
                + '<formula1>' + escapeXml(formulaProv) + '</formula1></dataValidation>';
            if (sheet1.contains('</dataValidations>')) {
                sheet1 = sheet1.replace('</dataValidations>', dv + '</dataValidations>');
                Pattern pCnt = Pattern.compile('<dataValidations count="(\\d+)"');
                Matcher mCnt = pCnt.matcher(sheet1);
                if (mCnt.find()) {
                    Integer c = Integer.valueOf(mCnt.group(1)) + 1;
                    sheet1 = mCnt.replaceFirst('<dataValidations count="' + c + '"');
                }
            }
        }
        return sheet1;
    }

    @TestVisible
    private static String patchSheet1EncabezadosDestino(String sheet1) {
        if (sheet1 == null || sheet1.contains('Provincia Destino')) {
            return sheet1;
        }
        Integer idxData = sheet1.indexOf('<sheetData>');
        Integer idxEnd = sheet1.indexOf('</sheetData>');
        if (idxData < 0 || idxEnd < 0) {
            return sheet1;
        }
        String row3 = extraerFilaSheet(
            sheet1.substring(idxData + '<sheetData>'.length(), idxEnd),
            FILA_ENCABEZADOS_CARGA
        );
        if (row3 == null) {
            return sheet1;
        }
        String row3Nuevo = row3.replace(
            '</row>',
            inlineStrCell('K3', '4', 'Provincia Destino')
            + inlineStrCell('L3', '4', 'Localidad Destino')
            + '</row>'
        );
        return sheet1.replace(row3, row3Nuevo);
    }

    @TestVisible
    private static Boolean esPlantillaConGeoEstatica(Map<String, Blob> entradas) {
        return entradas != null && entradas.containsKey('xl/worksheets/sheet4.xml');
    }

    /** Plantilla base openpyxl: geo en SR + listas x14 en extLst (no migrar a legacy). */
    @TestVisible
    private static Boolean esPlantillaOpenpyxlBase(String sheet1) {
        return sheet1 != null && sheet1.contains('INDIRECT("Loc_"');
    }

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
        sheet1 = reemplazarRangoReferenciasXmF(sheet1, REF_COL_CAMPANA, ultRowCam);
        sheet1 = reemplazarRangoReferenciasXmF(sheet1, REF_COL_CATEGORIA, ultRowCat);
        sheet1 = reemplazarRangoReferenciasXmF(sheet1, REF_COL_TIPO, ultRowTc);
        sheet1 = reemplazarRangoReferenciasXmF(sheet1, REF_COL_VARIEDAD, ultRowVar);

        return sheet1;
    }

    @TestVisible
    private static String reemplazarRangoReferenciasXmF(String sheet1, String col, Integer ultRow) {
        String patron = '<xm:f>REFERENCIAS!\\$' + col + '\\$3:\\$' + col + '\\$\\d+</xm:f>';
        String reemplazo = Matcher.quoteReplacement(
            '<xm:f>REFERENCIAS!$' + col + '$3:$' + col + '$' + ultRow + '</xm:f>'
        );
        return Pattern.compile(patron).matcher(sheet1).replaceAll(reemplazo);
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
            'Tipo de Comprobante', 'Variedad', 'Provincia Destino', 'Localidad Destino'
        };
        List<String> cols = new List<String>{
            'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'
        };

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

    /**
     * Office LTSC no tolera bien x14:dataValidations tras reempaquetar el ZIP.
     * Migra listas a dataValidations estándar y elimina la extensión x14.
     */
    @TestVisible
    private static String patchSheet1MigrarX14Legacy(String sheet1) {
        if (String.isBlank(sheet1) || !sheet1.contains('<x14:dataValidation')) {
            return recalcularDataValidationsCount(sheet1);
        }

        List<String> migradas = new List<String>();
        Pattern blockPat = Pattern.compile(
            '<x14:dataValidation type="list"([^>]*)>\\s*<x14:formula1><xm:f>([^<]*)</xm:f></x14:formula1>\\s*<xm:sqref>([^<]*)</xm:sqref>\\s*</x14:dataValidation>'
        );
        Matcher blockMatcher = blockPat.matcher(sheet1);
        while (blockMatcher.find()) {
            String attrs = blockMatcher.group(1).replaceAll(' xr:uid="\\{[^}]*\\}"', '');
            migradas.add(
                '<dataValidation type="list"' + attrs
                + ' sqref="' + blockMatcher.group(3) + '">'
                + '<formula1>' + blockMatcher.group(2) + '</formula1></dataValidation>'
            );
        }

        Pattern extPat = Pattern.compile(
            '<extLst>\\s*<ext uri="\\{CCE6A557-97BC-4b89-ADB6-D9C93CAAB3DF\\}"[\\s\\S]*?</ext>\\s*</extLst>'
        );
        sheet1 = extPat.matcher(sheet1).replaceAll('');

        if (!migradas.isEmpty()) {
            if (sheet1.contains('</dataValidations>')) {
                sheet1 = sheet1.replace('</dataValidations>', String.join(migradas, '') + '</dataValidations>');
            } else {
                sheet1 = sheet1.replace(
                    '<pageMargins',
                    '<dataValidations count="' + migradas.size() + '">'
                    + String.join(migradas, '')
                    + '</dataValidations><pageMargins'
                );
            }
        }

        return recalcularDataValidationsCount(sheet1);
    }

    /** Quita atributos x14/uid y validaciones mal formadas que Office LTSC rechaza. */
    @TestVisible
    private static String patchSheet1SanitizarValidacionesLegacy(String sheet1) {
        if (String.isBlank(sheet1)) {
            return sheet1;
        }
        sheet1 = sheet1.replaceAll(' xr:uid="\\{[^}]*\\}"', '');
        sheet1 = sheet1.replaceAll(
            '<dataValidation allowBlank="1" showInputMessage="1" showErrorMessage="1" prompt="Kilos[^"]*" sqref="B4:B\\d+"[^>]*/>',
            ''
        );
        sheet1 = sheet1.replace(' horizontalDpi="4294967292"', '');
        sheet1 = sheet1.replace(' verticalDpi="4294967292"', '');
        return recalcularDataValidationsCount(sheet1);
    }

    /** Sincroniza docProps/app.xml con las hojas reales del workbook (incl. ocultas). */
    @TestVisible
    private static String patchDocPropsApp(String appXml, String workbookXml) {
        if (String.isBlank(appXml) || String.isBlank(workbookXml)) {
            return appXml;
        }
        List<String> sheetNames = new List<String>();
        Matcher sheetMatcher = Pattern.compile('<sheet name="([^"]+)"').matcher(workbookXml);
        while (sheetMatcher.find()) {
            sheetNames.add(sheetMatcher.group(1));
        }
        if (sheetNames.isEmpty()) {
            return appXml;
        }

        if (esAppXmlPlantillaOpenpyxl(appXml)) {
            return appXml.replaceAll(
                '(<HeadingPairs>[\\s\\S]*?<vt:i4>)\\d+(</vt:i4>)',
                '$1' + sheetNames.size() + '$2'
            );
        }

        String titles = '';
        for (String name : sheetNames) {
            titles += '<vt:lpstr>' + escapeXml(name) + '</vt:lpstr>';
        }

        String patched = appXml.replaceAll('<vt:i4>\\d+</vt:i4>', '<vt:i4>' + sheetNames.size() + '</vt:i4>');
        return Pattern.compile(
            '<TitlesOfParts><vt:vector size="\\d+" baseType="lpstr">[\\s\\S]*?</vt:vector></TitlesOfParts>'
        ).matcher(patched).replaceAll(
            Matcher.quoteReplacement(
                '<TitlesOfParts><vt:vector size="' + sheetNames.size() + '" baseType="lpstr">'
                + titles + '</vt:vector></TitlesOfParts>'
            )
        );
    }

    /** app.xml openpyxl incluye rangos Loc_* en TitlesOfParts: no reemplazar todo el bloque. */
    @TestVisible
    private static Boolean esAppXmlPlantillaOpenpyxl(String appXml) {
        return appXml != null
            && appXml.contains('<vt:lpstr>LOCALIDADES</vt:lpstr>')
            && appXml.contains('Loc_BUENOS_AIRES');
    }

    /** Elimina extensiones Excel 365 que Office LTSC no tolera tras re-zip. */
    @TestVisible
    private static String patchWorkbookCompatibilidadLtsc(String workbookXml) {
        if (String.isBlank(workbookXml)) {
            return workbookXml;
        }
        workbookXml = Pattern.compile('<mc:AlternateContent[\\s\\S]*?</mc:AlternateContent>')
            .matcher(workbookXml).replaceAll('');
        workbookXml = Pattern.compile('<ext uri="\\{B58B0392-4F1F-4190-BB64-5DF3571DCE5F\\}"[\\s\\S]*?</ext>')
            .matcher(workbookXml).replaceAll('');
        workbookXml = Pattern.compile('<ext uri="\\{D14903EA-33C4-47F7-8F05-3474C54BE107\\}"[\\s\\S]*?</ext>')
            .matcher(workbookXml).replaceAll('');
        return workbookXml;
    }

    @TestVisible
    private static String recalcularDataValidationsCount(String sheet1) {
        if (String.isBlank(sheet1) || !sheet1.contains('<dataValidations')) {
            return sheet1;
        }
        Integer total = 0;
        Matcher m = Pattern.compile('<dataValidation ').matcher(sheet1);
        while (m.find()) {
            total++;
        }
        return Pattern.compile('<dataValidations count="\\d+"')
            .matcher(sheet1)
            .replaceFirst('<dataValidations count="' + total + '"');
    }

    /** Quita richData/metadata (Excel 365) que rompe la apertura en Office LTSC tras re-zip. */
    @TestVisible
    private static void stripRichDataFromPackage(Map<String, Blob> entradas) {
        if (entradas == null || entradas.isEmpty()) {
            return;
        }
        List<String> toRemove = new List<String>();
        for (String key : entradas.keySet()) {
            if (key.startsWith('xl/richData/') || key == 'xl/metadata.xml') {
                toRemove.add(key);
            }
        }
        for (String key : toRemove) {
            entradas.remove(key);
        }
        if (entradas.containsKey('[Content_Types].xml')) {
            String ct = entradas.get('[Content_Types].xml').toString();
            ct = ct.replaceAll('<Override PartName="/xl/metadata\\.xml"[^>]*/>', '');
            ct = ct.replaceAll('<Override PartName="/xl/richData/[^"]*"[^>]*/>', '');
            entradas.put('[Content_Types].xml', Blob.valueOf(ct));
        }
        if (entradas.containsKey('xl/_rels/workbook.xml.rels')) {
            String rels = entradas.get('xl/_rels/workbook.xml.rels').toString();
            rels = rels.replaceAll('<Relationship[^>]*richValue[^>]*/>', '');
            rels = rels.replaceAll('<Relationship[^>]*sheetMetadata[^>]*/>', '');
            rels = rels.replaceAll('<Relationship[^>]*rdRichValue[^>]*/>', '');
            entradas.put('xl/_rels/workbook.xml.rels', Blob.valueOf(rels));
        }
    }

    @TestVisible
    private static String sanitizeXmlText(String s) {
        if (s == null) {
            return '';
        }
        String out = '';
        for (Integer i = 0; i < s.length(); i++) {
            Integer cp = s.charAt(i);
            if (
                cp == 9
                || cp == 10
                || cp == 13
                || (cp >= 32 && cp <= 55295)
                || (cp >= 57344 && cp <= 65533)
            ) {
                out += s.substring(i, i + 1);
            }
        }
        return out;
    }

    @TestVisible
    private static String escapeXml(String s) {
        if (s == null) {
            return '';
        }
        String clean = sanitizeXmlText(s);
        return clean.replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&apos;');
    }
}