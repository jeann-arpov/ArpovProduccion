import { LightningElement, track, api, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import VENTAS_INFORMADAS_REFRESH from '@salesforce/messageChannel/VentasInformadasRefresh__c';

import saveFile from '@salesforce/apex/lwcVentasImportFromCsvController.saveFile';
import saveFileExcel from '@salesforce/apex/lwcVentasImportFromExcel.inserRecodrsFromExcel';


import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import xlsx from '@salesforce/resourceUrl/XLSX';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import SystemModstamp from '@salesforce/schema/AcceptedEventRelation.SystemModstamp';
import EMPTY_EXCEL from '@salesforce/resourceUrl/Vtas_Informadas_Vacio';
import generarPlantillaBase64 from '@salesforce/apex/PlantillaVtasInfXlsxBuilder.generarPlantillaBase64';
import VentaInformaedaModal from 'c/ventaInformadaModal';

/**
 * Columnas del Excel de errores: mismo orden y nombres que la plantilla (A–J) + Error.
 * keys: posibles nombres de columna en la fila devuelta por Apex (API o encabezado Excel).
 */
const RESULTADO_ERROR_COLUMNS = [
    { label: 'Campaña Agrícola', keys: ['Campana_de_Ventas__c', 'Campaña Agrícola', 'Campana Agricola', 'Campana de Ventas', 'Campaña de Ventas'] },
    { label: 'Kilos Totales', keys: ['Cantidad_de_Bolsas__c', 'Kilos Totales'] },
    { label: 'Categoría', keys: ['Categoria__c', 'Categoría', 'Categoria'] },
    { label: 'CUIT Destinatario', keys: ['CUIT_Destinatario__c', 'CUIT Destinatario'] },
    { label: 'Razón Social Destinatario', keys: ['Razon_Social_Destinatario__c', 'Razón Social Destinatario', 'Razon Social Destinatario'] },
    { label: 'Fecha Comprobante', keys: ['Fecha_de_Facturacion__c', 'Fecha Comprobante', 'Fecha de Comprobante', 'Fecha de Facturación', 'Fecha de Facturacion'] },
    { label: 'Línea del Comprobante', keys: ['Linea_Facturacion__c', 'Línea del Comprobante', 'Linea del Comprobante', 'Línea Facturación', 'Linea Facturacion'] },
    { label: 'N° de Comprobante', keys: ['N_de_Comprobante__c', 'N° de Comprobante', 'Nº de Comprobante', 'N de Comprobante', 'N° Comprobante', 'Nº Comprobante', 'N Comprobante'] },
    { label: 'Tipo de Comprobante', keys: ['Tipo_Comprobante_Externo__c', 'Tipo_de_Comprobante__c', 'Tipo de Comprobante'] },
    { label: 'Variedad', keys: ['Variedad__c', 'Variedad'] },
    { label: 'Provincia Destino', keys: ['Provincia_Destino__c', 'Provincia Destino'] },
    { label: 'Localidad Destino', keys: ['Localidad_Destino__c', 'Localidad Destino'] }
];

const RESULTADO_ERROR_HEADERS = [...RESULTADO_ERROR_COLUMNS.map((c) => c.label), 'Error'];

/** Fecha: serial numérico de Excel (Apex parseFlexibleDate). Resto: texto formateado (cell.w). */
const FECHA_HEADER_KEYS = new Set([
    'Fecha Comprobante',
    'Fecha de Comprobante',
    'Fecha de Facturación',
    'Fecha de Facturacion',
    'Fecha_de_Facturacion__c'
]);


export default class LwcCSVUploader extends LightningElement {

    @wire(MessageContext)
    messageContext;

    /** Cuenta originante elegida en Salesforce core (obligatoria fuera de comunidad). */
    @api originanteAccountId;
    /** true: oculta la barra de botones (la muestra el contenedor padre). */
    @api suppressActionBar = false;
    /** true: import en Salesforce core (exige originanteAccountId). */
    @api coreImportMode = false;

    @track fileName = '';

  

    @track showLoadingSpinner = false;

  

    // Lo que yo uso

    selectedRecords;

    filesUploaded = [];

    file;

    fileContents;

    fileReader;

    content;

    MAX_FILE_SIZE = 1500000;

    XlsxPromise;

    fileReaderText;

    step = "1";
    stepError = false;

    /** true cuando la última importación terminó OK: al cerrar refrescamos para ver los registros. */
    importSucceeded = false;

    get header(){

        if(this.step === "1") return "Adjuntar el archivo Excel a importar"
        if(this.step === "2") return "Confirmar la importación del archivo"
        if(this.step === "3") return "Finalizado"
    }

    get comenzo(){
        return this.step === "1";
    }

    get confirmar(){
        return this.step === "2";
    }

    get finalizo(){
        return this.step === "3";
    }

    get fileSize(){
        var i = Math.floor(Math.log(this.file.size) / Math.log(1024));
        return " (" + ((this.file.size / Math.pow(1024, i)).toFixed(2) * 1 + ' ' + ['B', 'kB', 'MB', 'GB', 'TB'][i] + ")");
    }

    get acceptedFormats() {
        return ['.xlsx', '.csv'];
    }

    get showActionBar() {
        return !this.suppressActionBar;
    }


    channelName = '/event/Notificacion_Batch_Apex__e';
    saveFileExcelPromise;

    connectedCallback() {
        // XLSX se usa para LEER el archivo .xlsx que sube el usuario al importar.
        // La generación de la plantilla (downloadClick) la hace Apex server-side
        // para evitar las restricciones del Locker Service de Experience Cloud.
        loadScript(this, xlsx).catch(err => {
            console.error('[ventasImportFromCsv] Error cargando XLSX', err);
        });
    }

    handleFilesChange(event) {

        if (event.target.files.length > 0) {

            this.filesUploaded = event.target.files;

            this.fileName = event.target.files[0].name;

            this.file = this.filesUploaded[0];

            this.step = "2";

        }
    }

    handleSave() {

        if (this.filesUploaded.length > 0) {

            this.uploadHelper();

        }

        else {

            this.fileName = 'Please select a CSV file to upload!!';

        }
    }

    

    uploadHelper() {

        

        if (this.file.size > this.MAX_FILE_SIZE) {

            window.console.log('File Size is to long');

            return;

        }

        this.showLoadingSpinner = true;

        this.fileReader = new FileReader();
        this.fileContents = null;
        this.fileReader.onloadend = (() => {
          
            if( this.fileContents == null){
               
                this.fileContents = this.fileReader.result;
                let base64 = 'base64,';
                this.content = this.fileContents.indexOf(base64) + base64.length;
                this.fileContents = this.fileContents.substring(this.content);
                this.fileReader.readAsArrayBuffer(this.file);
                
            }else {
                var workbook = XLSX.read(new Uint8Array(this.fileReader.result), {
                    type: 'array',
                    cellText: true,
                    cellNF: true
                });
                const sheetName = this.resolveImportSheetName(workbook);
                const rawRows = this.parseSheetToRows(workbook.Sheets[sheetName]);
                this.uploadFile(this.filterFilasDatosVentas(rawRows));
              
            }
        });

        this.fileReader.readAsDataURL(this.file);
    }

    

    /**
     * Hoja de datos: CARGA (modelo nuevo), Planilla/Datos (legacy) o Pegar datos.
     */
    resolveImportSheetName(workbook) {
        const names = workbook.SheetNames || [];
        const carga = names.find((n) => /^carga$/i.test(String(n).trim()));
        if (carga) {
            return carga;
        }
        const planilla = names.find((n) => /^planilla$/i.test(String(n).trim()));
        if (planilla) {
            return planilla;
        }
        const datos = names.find((n) => /^datos$/i.test(String(n).trim()));
        if (datos) {
            return datos;
        }
        const pegarName = names.find((n) => /^pegar\s*datos$/i.test(String(n).trim()));
        if (pegarName) {
            const pegarRows = this.parseSheetToRows(workbook.Sheets[pegarName]);
            if (this.filterFilasDatosVentas(pegarRows).length > 0) {
                return pegarName;
            }
        }
        return names[0];
    }

    /**
     * Detecta la fila de encabezados (modelo nuevo: fila 3; legacy: fila 1).
     */
    parseSheetToRows(ws) {
        if (!ws) {
            return [];
        }
        const headerRow = this.detectHeaderRowIndex(ws);
        const rows = XLSX.utils.sheet_to_json(ws, { range: headerRow, raw: false, defval: '' });
        if (!rows.length) {
            return rows;
        }
        const rawRows = XLSX.utils.sheet_to_json(ws, { range: headerRow, raw: true, defval: '' });
        this.enrichRowsFromWorksheetCells(ws, headerRow, rows, rawRows);
        return rows;
    }

    /**
     * Lee cada celda desde el worksheet: fecha con serial numérico; demás columnas con el
     * texto formateado (cell.w) para no perder separadores de miles, ceros a la izquierda,
     * barras en campaña (2025/26), guiones en CUIT, etc.
     */
    enrichRowsFromWorksheetCells(ws, headerRowIndex, rows, rawRows) {
        if (!ws || !rows || !rows.length) {
            return;
        }

        const headerMap = this.buildHeaderColumnMap(ws, headerRowIndex);
        if (!Object.keys(headerMap).length) {
            return;
        }

        for (let i = 0; i < rows.length; i++) {
            const dataRow = headerRowIndex + 1 + i;
            const rawRow = rawRows[i] || {};

            for (const headerKey of Object.keys(rows[i])) {
                const colIndex = headerMap[headerKey];
                if (colIndex == null) {
                    continue;
                }

                const cell = ws[XLSX.utils.encode_cell({ r: dataRow, c: colIndex })];
                if (!cell) {
                    continue;
                }

                const rawVal = rawRow[headerKey];
                let value;
                if (this.isFechaHeaderKey(headerKey) && typeof rawVal === 'number' && Number.isFinite(rawVal)) {
                    value = rawVal;
                } else {
                    value = this.getCellDisplayValue(cell, rows[i][headerKey]);
                }

                if (value != null && value !== '') {
                    rows[i][headerKey] = value;
                }
            }
        }
    }

    buildHeaderColumnMap(ws, headerRowIndex) {
        const map = {};
        const ref = ws['!ref'];
        if (!ref) {
            return map;
        }
        const range = XLSX.utils.decode_range(ref);
        for (let c = range.s.c; c <= range.e.c; c++) {
            const cell = ws[XLSX.utils.encode_cell({ r: headerRowIndex, c })];
            if (!cell || cell.v == null) {
                continue;
            }
            map[String(cell.v).trim()] = c;
        }
        return map;
    }

    isFechaHeaderKey(headerKey) {
        return FECHA_HEADER_KEYS.has(headerKey);
    }

    getCellDisplayValue(cell, existingFormatted) {
        const existing = existingFormatted != null ? String(existingFormatted).trim() : '';

        if (cell.w != null && String(cell.w).trim()) {
            return String(cell.w).trim();
        }

        // sheet_to_json (raw:false) puede traer "1.600"; no degradar a "1.6" si cell.w falta.
        if (existing && this.looksLikeFormattedNumber(existing)) {
            return existing;
        }

        if (cell.v != null && typeof cell.v === 'number' && Number.isFinite(cell.v) && cell.z && XLSX.SSF) {
            try {
                const formatted = XLSX.SSF.format(cell.z, cell.v);
                if (formatted != null && String(formatted).trim()) {
                    return String(formatted).trim();
                }
            } catch (e) {
                // fallback abajo
            }
        }

        if (cell.v == null) {
            return existing || null;
        }
        if (typeof cell.v === 'number' && Number.isFinite(cell.v)) {
            return this.numberToPlainString(cell.v);
        }
        return String(cell.v).trim();
    }

    looksLikeFormattedNumber(value) {
        if (!value) {
            return false;
        }
        if (/^\d{1,3}(\.\d{3})+$/.test(value)) {
            return true;
        }
        if (/^\d{1,3}(,\d{3})+(\.\d+)?$/.test(value)) {
            return true;
        }
        if (value.includes(',') && /^\d+(,\d+)?$/.test(value)) {
            return true;
        }
        return false;
    }

    /**
     * Normaliza Kilos Totales antes de enviar a Apex (misma lógica que parseKilosTotales).
     * Devuelve string canónico para que JSON no mande 1.6 en lugar de 1600.
     */
    parseKilosTotalesForUpload(raw) {
        if (raw == null || raw === '') {
            return raw;
        }
        if (typeof raw === 'number' && Number.isFinite(raw)) {
            if (Number.isInteger(raw)) {
                return String(raw);
            }
            return String(raw);
        }

        let s = String(raw).trim().replace(/[^0-9.,-]/g, '');
        if (!s) {
            return raw;
        }

        const lastComma = s.lastIndexOf(',');
        const lastDot = s.lastIndexOf('.');

        if (lastComma >= 0 && lastDot >= 0) {
            if (lastComma > lastDot) {
                s = s.replace(/\./g, '').replace(',', '.');
            } else {
                s = s.replace(/,/g, '');
            }
        } else if (lastComma >= 0) {
            if ((s.match(/,/g) || []).length > 1) {
                s = s.replace(/,/g, '');
            } else if (this.isUsThousandsComma(s)) {
                s = s.replace(',', '');
            } else {
                s = s.replace(',', '.');
            }
        } else if (lastDot >= 0) {
            if ((s.match(/\./g) || []).length > 1) {
                s = s.replace(/\./g, '');
            } else {
                const after = s.length - lastDot - 1;
                if (after === 3) {
                    s = s.replace('.', '');
                }
            }
        }

        const n = parseFloat(s);
        if (!Number.isFinite(n)) {
            return raw;
        }
        if (Number.isInteger(n)) {
            return String(n);
        }
        return String(n);
    }

    isUsThousandsComma(s) {
        const idx = s.lastIndexOf(',');
        if (idx < 0) {
            return false;
        }
        const after = s.substring(idx + 1);
        return after.length === 3 && /^\d+$/.test(after);
    }

    normalizeRowsBeforeUpload(rows) {
        if (!rows || !rows.length) {
            return rows;
        }
        return rows.map((row) => {
            const copy = { ...row };
            for (const key of Object.keys(copy)) {
                if (/kilos\s*totales/i.test(key) || key === 'Cantidad_de_Bolsas__c') {
                    copy[key] = this.parseKilosTotalesForUpload(copy[key]);
                }
            }
            return copy;
        });
    }

    numberToPlainString(value) {
        if (!Number.isFinite(value)) {
            return '';
        }
        if (Number.isInteger(value)) {
            try {
                return value.toLocaleString('fullwide', { useGrouping: false, maximumFractionDigits: 0 });
            } catch (e) {
                return String(value);
            }
        }
        return String(value);
    }

    detectHeaderRowIndex(ws) {
        const ref = ws['!ref'];
        if (!ref) {
            return 0;
        }
        const range = XLSX.utils.decode_range(ref);
        const markers = [
            'kilos totales', 'cuit destinatario', 'cuit_destinatario', 'variedad',
            'campana agricola', 'campaña agrícola', 'campana_de_ventas',
            'categoria', 'tipo_de_comprobante', 'tipo de comprobante'
        ];
        for (let r = range.s.r; r <= Math.min(range.s.r + 8, range.e.r); r++) {
            let text = '';
            for (let c = range.s.c; c <= range.e.c; c++) {
                const cell = ws[XLSX.utils.encode_cell({ r, c })];
                if (cell && cell.v != null) {
                    text += ' ' + String(cell.v).toLowerCase();
                }
            }
            const hits = markers.filter((m) => text.includes(m)).length;
            if (hits >= 2) {
                return r;
            }
        }
        return 0;
    }

    /**
     * Omite banners, encabezados y leyenda inferior de la plantilla.
     */
    filterFilasDatosVentas(rows) {
        if (!rows || !rows.length) return [];

        const leyendaCampos = new Set([
            'Campana_de_Ventas__c', 'Campaña Agrícola', 'Campana Agricola', 'Kilos Totales', 'Categoria__c', 'Categoría', 'Categoria',
            'CUIT_Destinatario__c', 'CUIT_Originante__c', 'CUIT Originante',
            'Fecha_de_Facturacion__c', 'Fecha Comprobante', 'Fecha de Facturación', 'Fecha de Facturacion',
            'Kilos_por_Bolsa__c', 'Linea_Facturacion__c', 'Línea del Comprobante', 'Linea del Comprobante',
            'N_de_Comprobante__c', 'Razon_Social_Destinatario__c', 'Tipo_Comprobante_Externo__c', 'Tipo_de_Comprobante__c', 'Variedad__c'
        ]);
        const marcadoresLeyenda = [
            /por favor elimine/i,
            /elimine las l[ií]neas/i,
            /elimin[aá] estas l[ií]neas/i,
            /detalle de las columnas/i,
            /no enviar estas l[ií]neas/i,
            /planilla de ventas informadas/i,
            /completar una fila por l[ií]nea/i,
            /todos los campos.*obligatorios/i,
            /no modificar encabezados/i
        ];
        const textosAyuda = [
            /año de la campaña/i,
            /sembra evoluci/i,
            /instrucciones de carga/i,
            /pasos para completar/i,
            /no colocar valores en negativo/i,
            /alguno de los siguientes valores/i,
            /cuit destinatario del movimiento/i,
            /informar siempre 1/i,
            /n[uú]mero correlativo/i,
            /corresponde al cultivar inase/i,
            /peg[aá] aqu[ií] los datos/i,
            /no pegues en la hoja datos/i,
            /excel borra los desplegables/i
        ];

        const out = [];
        let omitirResto = false;

        for (const row of rows) {
            if (!row || omitirResto) continue;

            const valores = Object.values(row)
                .map(v => (v == null ? '' : String(v).trim()))
                .filter(Boolean);
            if (!valores.length) continue;

            const joined = valores.join(' ');
            if (marcadoresLeyenda.some(rx => rx.test(joined))) {
                omitirResto = true;
                continue;
            }
            if (valores.some(v => leyendaCampos.has(v))) continue;
            if (valores.some(v => textosAyuda.some(rx => rx.test(v)))) continue;

            out.push(row);
        }
        return out;
    }

    uploadFile(rows) {
       
       const payload = this.normalizeRowsBeforeUpload(rows);
       console.log(payload);
        //console.log(JSON.stringify(this.fileReaderText));
        this.importSucceeded = false;

        this.saveFileExcelPromise = saveFileExcel({
            fileRows: payload,
            base64Data: encodeURIComponent(this.fileContents),
            fileTitle: this.fileName,
            originanteAccountId: this.originanteAccountId || null
        }).then(result => {
            
            this.generateFileResults(result);
            this.showLoadingSpinner = false;
            
        }).then(_ => this.saveFileExcelPromise = null ).catch(error => {
            console.log(error);
            this.showLoadingSpinner = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Importing',
                    message: error.body.message ? error.body.message : JSON.stringify(error),
                    variant: 'error',
                }),
            );
        });
        //this.generateFileResults(rows);
    }

   

    generateFileResults(data){
        if(!data[0].isSucces){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error al importar Ventas Inforadas',
                    message: 'Revisar errores en Excel y volver a importar',
                    variant: 'error',
                }),
            );
            this.backStep();
            console.log("Error en el excel");

            const exportRows = this.buildErrorExportRows(data);
            const ws = XLSX.utils.json_to_sheet(exportRows, { header: RESULTADO_ERROR_HEADERS });
            const wb = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(wb, ws, 'Errores');
            XLSX.writeFile(wb, 'Resultados_Ventas_Informadas.xlsx');
        }else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Las Ventas Informadas fueron importadas con éxito',
                    variant: 'success',
                }),
            );

            this.step = "3";
            this.importSucceeded = true;
            console.log("Success");
        }
    }

    /**
     * Arma filas para el Excel de errores con columnas de la plantilla actual (A–J) + Error.
     * Solo incluye filas que tengan mensaje de error; omite filas internas (debug, isSucces).
     */
    buildErrorExportRows(data) {
        if (!data || !data.length) {
            return [];
        }

        return data
            .filter((row) => row && !row.debug)
            .filter((row) => row.Error != null && String(row.Error).trim() !== '')
            .map((row) => {
                const out = {};
                for (const col of RESULTADO_ERROR_COLUMNS) {
                    out[col.label] = this.pickRowValue(row, col.keys);
                }
                out.Error = String(row.Error);
                return out;
            });
    }

    pickRowValue(row, keys) {
        for (const key of keys) {
            if (row[key] != null && String(row[key]).trim() !== '') {
                return row[key];
            }
        }
        return '';
    }

    backStep(){
        this.step = "1";
    }
    closeModal() {
        this.template.querySelector('c-modal').hide();
        this.backStep();
        // Tras una importación exitosa, pedimos a la tabla del portal que recargue datos.
        if (this.importSucceeded) {
            this.importSucceeded = false;
            this.notifyVentasListRefresh();
        }
    }

    notifyVentasListRefresh() {
        if (!this.messageContext) return;
        publish(this.messageContext, VENTAS_INFORMADAS_REFRESH, { action: 'refresh' });
    }

    @api
    openModal() {
        if (this.coreImportMode && !this.originanteAccountId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Cuenta originante',
                message: 'Seleccioná la cuenta originante antes de importar.',
                variant: 'warning'
            }));
            return;
        }
        this.template.querySelector('c-modal').show();
    }

   
    /**
     * Descarga la plantilla XLSX generada en Apex con variedades/campañas desde Salesforce.
     * Si falla el Apex, hace fallback al static resource (sin listas dinámicas de variedad).
     */
    @api
    downloadClick() {
        if (this.coreImportMode && !this.originanteAccountId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Cuenta originante',
                message: 'Seleccioná la cuenta originante antes de descargar la plantilla.',
                variant: 'warning'
            }));
            return;
        }
        this.showLoadingSpinner = true;
        generarPlantillaBase64({ sinCuitOriginante: true })
            .then((base64) => {
                if (!base64) {
                    throw new Error('Apex devolvió base64 vacío.');
                }
                this.descargarBase64ComoXlsx(base64, 'Plantilla_Ventas_Informadas.xlsx');
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Plantilla descargada',
                    message: 'Usá los desplegables en Variedad, Categoría, Tipo de Comprobante y Campaña.',
                    variant: 'success'
                }));
            })
            .catch((err) => {
                console.error('[ventasImportFromCsv] Error generando plantilla dinámica, fallback a estática.', err);
                this.descargarRecursoEstatico('Plantilla_Ventas_Informadas.xlsx');
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Plantilla con limitaciones',
                    message: 'Se descargó la plantilla estática sin variedades dinámicas. Reintentá o contactá soporte.',
                    variant: 'warning'
                }));
            })
            .finally(() => {
                this.showLoadingSpinner = false;
            });
    }

    /** Descarga el .xlsx del static resource sin pasar por Apex. */
    descargarRecursoEstatico(fileName) {
        const a = document.createElement('a');
        a.href = EMPTY_EXCEL;
        a.download = fileName;
        a.style.display = 'none';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    /** Convierte un base64 en archivo descargable.
     *  Usa data URL en lugar de Blob para esquivar la whitelist de MIME types
     *  del Locker Service de Experience Cloud (rechaza el MIME oficial de xlsx).
     *  El nombre del archivo (.xlsx) hace que Excel lo abra correctamente. */
    descargarBase64ComoXlsx(base64, fileName) {
        const a = document.createElement('a');
        a.href = 'data:application/octet-stream;base64,' + base64;
        a.download = fileName;
        a.style.display = 'none';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    descargarPlantillaEstatica() {
        this.descargarRecursoEstatico('ventas informadas plantilla.xlsx');
    }
  
    @api
    openVentaModal() {
        if (this.coreImportMode && !this.originanteAccountId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Cuenta originante',
                message: 'Seleccioná la cuenta originante antes de crear una venta.',
                variant: 'warning'
            }));
            return;
        }
        VentaInformaedaModal.open({
            size: 'large',
            originanteAccountId: this.originanteAccountId || undefined
        });
    }

}