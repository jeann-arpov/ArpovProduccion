import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { loadScript } from 'lightning/platformResourceLoader';
import getRecordDataForExcel from '@salesforce/apex/ExcelDownloadController.getRecordDataForExcel';
import SHEETJS from '@salesforce/resourceUrl/sheetjs';
import getVentasHT from '@salesforce/apex/VentasHTController.getVentasHT';
import getEstadosVentaHT from '@salesforce/apex/VentasHTController.getEstadosVentaHT';
import getCultivosVentaHT from '@salesforce/apex/VentasHTController.getCultivosVentaHT';
import getProductoresVentaHT from '@salesforce/apex/VentasHTController.getProductoresVentaHT';
import updateOpportunity from '@salesforce/apex/CrearVentaController.updateOpportunity';
import getAttachments from '@salesforce/apex/UtilsContentDocumentLink.getAttachments';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import getAccountFromUserByVentas from '@salesforce/apex/UtilsVentaHt.getAccountFromUserByVentas';

const ESTADO_HT_VENDIDAS = 'Pagada';
const ESTADOS_SIN_SUBIR_FACTURA = new Set(['Pagada', 'Facturada']);

export default class VentasHTList extends NavigationMixin(LightningElement) {
    iconVenderHTUrl = `${resourcePortal}/resourcePortal/images/icon-vender-ht.svg`;
    @track ventasAll = [];
    @track ventasFiltradas = [];
    @track ventas = [];

    @track estados = [];
    @track cultivos = [];
    @track productores = [];

    @track showFileUploadModal = false;
    @track selectedRowId = null;
    @track uploadFactura = true;
    formattedDate = null;
    customCode = null;

    @track filtros = {
        estado: '',
        grupo: '',
        cultivo: '',
        productor: '',
        search: ''
    };

    pageSize = 10;
    currentPage = 1;

    sheetJSInitialized = false;
    isLoading = false;

    wiredVentasResult;

    async connectedCallback() {
        await this.initializeSheetJS();
    }

    async initializeSheetJS() {
        if (this.sheetJSInitialized) return;

        try {
            await loadScript(this, SHEETJS + '/xlsx.full.min.js');
            if (window.XLSX && window.XLSX.version) {
                this.sheetJSInitialized = true;
                console.log('SheetJS cargado. Versión:', window.XLSX.version);
            } else {
                throw new Error('XLSX no está disponible después de cargar.');
            }
        } catch (error) {
            console.error('Error cargando SheetJS:', error);
            this.sheetJSInitialized = false;
        }
    }

    async handleDescargarPF(event) {
        const ventaId = event.currentTarget.dataset.id; 
        console.log('ventaId recibido:', ventaId);
        try {
            if (!this.sheetJSInitialized) {
                await this.initializeSheetJS();
            }

            const recordData = await getRecordDataForExcel({ recordId: ventaId });
            if (!recordData) {
                this.showErrorToast('No hay datos para generar el Excel');
                return;
            }
            await this.generateAndDownloadExcel(recordData, ventaId);
            this.showSuccessToast('Excel generado correctamente');
        } catch (error) {
            this.showErrorToast('Error al generar Excel: ' + (error.body?.message || error.message));
            console.error(error);
        }
    }

    async generateAndDownloadExcel(data, recordId) {
        try {
            console.log('=== INICIO generateAndDownloadExcel ===');
            
            // Verificar que SheetJS esté disponible
            if (!window.XLSX || typeof window.XLSX.utils === 'undefined') {
                throw new Error('SheetJS no está disponible o no se cargó correctamente');
            }
            
            const wb = window.XLSX.utils.book_new();
            const worksheetData = this.prepareWorksheetData(data);
            console.log('Datos preparados:', worksheetData.length, 'filas');
            
            if (!worksheetData || worksheetData.length === 0) {
                throw new Error('No hay datos para generar el Excel');
            }
            
            // Crear la hoja de trabajo
            const ws = window.XLSX.utils.aoa_to_sheet(worksheetData);
            window.XLSX.utils.book_append_sheet(wb, ws, 'Datos del Registro');
            
            console.log('Generando archivo Excel...');
            
            const wbout = window.XLSX.write(wb, { 
                bookType: 'xlsx', 
                type: 'base64',  
                compression: false
            });
            
            console.log('Archivo generado como base64, longitud:', wbout ? wbout.length : 'undefined');
            
            if (!wbout || wbout.length === 0) {
                throw new Error('Error al generar el contenido del archivo Excel');
            }
            
            const fileName = `Venta_${recordId}_${new Date().getTime()}.xlsx`;
            const dataUrl = `data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,${wbout}`;
            
            console.log('Creando enlace de descarga...');
            
            const link = document.createElement('a');
            link.href = dataUrl;
            link.download = fileName;
            link.style.display = 'none';
            
            document.body.appendChild(link);
            console.log('Iniciando descarga:', fileName);
            
            try {
                link.click();
                console.log('Click ejecutado exitosamente');
            } catch (clickError) {
                console.error('Error en click:', clickError);
                this.fallbackDownload(dataUrl, fileName);
            }
            
            // Limpiar
            setTimeout(() => {
                if (document.body.contains(link)) {
                    document.body.removeChild(link);
                }
                console.log('Limpieza completada');
            }, 1000);
            
            console.log('=== Excel generado correctamente ===');
            
        } catch (error) {
            console.error('=== ERROR EN generateAndDownloadExcel ===');
            console.error('Error:', error.message);
            console.error('Stack:', error.stack);
            throw error;
        }
    }

    // Método de respaldo para descargas
    fallbackDownload(dataUrl, fileName) {
        try {
            console.log('Usando método de descarga alternativo...');
            
            const newWindow = window.open();
            if (newWindow) {
                newWindow.document.write(`
                    <html>
                    <head><title>Descarga Excel</title></head>
                    <body>
                        <h3>Descarga del archivo Excel</h3>
                        <p>Si la descarga no inicia automáticamente, haz clic en el enlace:</p>
                        <a href="${dataUrl}" download="${fileName}">Descargar ${fileName}</a>
                        <script>
                            setTimeout(function() {
                                var link = document.querySelector('a');
                                link.click();
                            }, 1000);
                        </script>
                    </body>
                    </html>
                `);
            } else {
                throw new Error('No se puede abrir ventana emergente. Por favor verifica los permisos del navegador.');
            }
        } catch (fallbackError) {
            console.error('Error en método de respaldo:', fallbackError);
            throw new Error('No se pudo completar la descarga. Intenta con otro navegador.');
        }
    }

    prepareWorksheetData(data) {
        console.log('=== INICIO prepareWorksheetData ===');
        
        try {
            const worksheetData = [];
            
            // Verificar que tenemos datos
            if (!data) {
                console.warn('No hay datos para procesar');
                return [['No hay datos disponibles']];
            }
            
            // === LÍNEAS DE COMPRA HT ===
            if (data.relatedRecords && Array.isArray(data.relatedRecords) && data.relatedRecords.length > 0) {
                const headers = [
                    'Compra HT','Marca','CUIT', 'Razón Social', 'Mail Cliente', 'Tipo Comprobante', 'Fecha', 
                    'Campaña', 'Cultivo', 'Producto', 'Unidad Medida', 'Cantidad','CUIT Comercio', 'Comercio', 'Usuario'
                ];
                worksheetData.push(headers);
                
                data.relatedRecords.forEach((linea, index) => {
                    try {
                        const row = [
                            String(this.getNestedValue(linea, 'Name') || ''),
                            String(this.getNestedValue(linea, 'Compra_HT__r.Obtentor__r.Nombre_Obtentor__c') || ''),
                            String(this.getNestedValue(linea, 'Compra_HT__r.Cuenta_Productor__r.N_CUIT__c') || ''),
                            String(this.getNestedValue(linea, 'Compra_HT__r.Cuenta_Productor__r.Name') || ''),
                            String(this.getNestedValue(linea, 'Compra_HT__r.Cuenta_Productor__r.Direccion_de_Correo_electronico_del_CUIT__c') || ''),
                            //String(this.getNestedValue(linea, 'Compra_HT__r.Es_NC__c') || ''),
                            this.getNestedValue(linea, 'Compra_HT__r.Es_NC__c') === true ? 'NC' : 'FC',
                            new Date().toISOString().split('T')[0],
                            (() => {
                                const tipoCompra = this.getNestedValue(linea, 'Producto__r.Tipo_de_Compra__c');
                                const createdDate = new Date(this.getNestedValue(linea, 'CreatedDate'));
                                const year = createdDate.getFullYear();
                                return String(tipoCompra === 'Futura' ? year : year - 1);
                            })(),
                            String(this.getNestedValue(linea, 'Producto__r.Variedad2__r.Cultivo__r.Name') || ''),
                            String(this.getNestedValue(linea, 'Producto__r.Name') || ''),
                            'HT',
                            String((this.getNestedValue(linea, 'Compra_HT__r.Es_NC__c') === true ? -1 : 1) * (this.getNestedValue(linea, 'Cantidad__c') || 0)),
                            String(this.getNestedValue(linea, 'Linea_de_Venta_HT__r.Venta_HT__r.Comercio__r.N_CUIT__c') || ''),
                            String(this.getNestedValue(linea, 'Linea_de_Venta_HT__r.Venta_HT__r.Comercio__r.Name') || ''),
                            String(this.getNestedValue(linea, 'CreatedBy.Name') || '')                        
                        ];
                        worksheetData.push(row);
                    } catch (rowError) {
                        console.error(`Error procesando fila ${index}:`, rowError);
                        worksheetData.push(['Error procesando datos', '', '', '', '', '', '', '', '', '', '', '', '']);
                    }
                });
            } else {
                worksheetData.push(['No se encontraron líneas de compra HT relacionadas']);
            }
            
            console.log('Worksheet preparado con', worksheetData.length, 'filas');
            return worksheetData;
            
        } catch (error) {
            console.error('Error en prepareWorksheetData:', error);
            return [['Error preparando datos para Excel']];
        }
    }

    getNestedValue(obj, path) {
        return path.split('.').reduce((current, key) => {
            return current && current[key] !== undefined ? current[key] : null;
        }, obj);
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        
        try {
            const date = new Date(dateValue);
            return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
        } catch (error) {
            return dateValue.toString();
        }
    }

    renderedCallback() {
        if (this.hasRendered) return;

        this.hasRendered = true;

        const selectEstado = this.template.querySelector('[data-id="estadoSelect"]');
        if (selectEstado) {
            selectEstado.value = this.filtros.estado || '';
            if (this.filtros.estado || this.filtros.grupo) {
                this.aplicarFiltros();
            }
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            const estadoParam = currentPageReference.state?.estado;
            const grupoParam = currentPageReference.state?.grupo;
            console.log('estadoParam:', estadoParam, 'grupoParam:', grupoParam);

            if (grupoParam) {
                this.filtros.grupo = grupoParam;
                this.filtros.estado = '';
            } else if (estadoParam) {
                this.filtros.estado = estadoParam;
                this.filtros.grupo = '';
            }

            if (this.ventasAll.length > 0) {
                this.aplicarFiltros();
            }
        }
    }

    get mostrarAccionesColumna() {
        return this.ventasFiltradas.some(venta => venta.mostrarBoton);
    }

    async applyButtonVisibilityByVenta() {
        const ventaIds = this.ventasAll.map(venta => venta.id).filter(Boolean);
        if (!ventaIds.length) {
            this.aplicarFiltros();
            return;
        }

        try {
            const visibilityByVenta = await getAccountFromUserByVentas({ ventaIds });
            this.ventasAll = this.ventasAll.map(venta => ({
                ...venta,
                mostrarBoton: !ESTADOS_SIN_SUBIR_FACTURA.has(venta.estado) && Boolean(visibilityByVenta?.[venta.id])
            }));
        } catch (error) {
            console.error('Error evaluando visibilidad por venta:', error);
            this.ventasAll = this.ventasAll.map(venta => ({ ...venta, mostrarBoton: false }));
        }

        this.aplicarFiltros();
    }

    @wire(getVentasHT)
    wiredVentas({ data, error }) {
        console.log('wiredVentas',JSON.stringify(data) )
        if (data) {
            this.ventasAll = data.map(venta => ({
                ...venta,
                id: venta.id,
                tieneAdjunto: Boolean(venta.TieneAdjunto__c),
                mostrarBoton: false
            }));
            this.aplicarFiltros();
            this.applyButtonVisibilityByVenta();
        } else if (error) {
            console.error('Error al cargar ventas:', error);
        }
    }

    @wire(getEstadosVentaHT)
    wiredEstados({ data }) {
        if (data) this.estados = data;
    }

    @wire(getCultivosVentaHT)
    wiredCultivos({ data }) {
        if (data) this.cultivos = data;
    }

    @wire(getProductoresVentaHT)
    wiredProductores({ data }) {
        if (data) this.productores = data;
    }

    handleVenderHT() {
        console.log('Vender HT');
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'FormularioNuevaVentaHT__c'
            },
            state: {
                estado: ''
            }
        });
    }

    navigateToVenta(event) {
        const recordId = event.currentTarget.dataset.id;
        const recordName = event.currentTarget.dataset.name;

        // ⚠️ Usar el Name tal cual lo devuelve Salesforce
        const safeName = recordName; 

        // Detectar basePath dinámicamente
        // ej: "/SembraEvolucionComercio/s" o "/Comercio/s"
        let basePath = '';
        const pathname = window.location.pathname;

        if (pathname.includes('/SembraEvolucionComercio/s')) {
            basePath = '/SembraEvolucionComercio/s';
        } else if (pathname.includes('/Comercio/s')) {
            basePath = '/Comercio/s';
        } else {
            // fallback genérico
            basePath = pathname.split('/s')[0] + '/s';
        }

        // Construcción de URL final
        const url = `${basePath}/venta-ht/${recordId}/${safeName}`;

        console.log('🌐 Navegando a:', url);

        // Redirigir
        window.open(url, "_self");
    }

    get totalElementos() {
        return this.ventasFiltradas.length;
    }

    cumpleFiltroEstado(venta) {
        const { estado, grupo } = this.filtros;
        if (grupo === 'vendidas') {
            return venta.estado === ESTADO_HT_VENDIDAS;
        }
        if (grupo === 'pendientes') {
            return venta.estado === 'Facturada';
        }
        if (estado) {
            return venta.estado === estado;
        }
        return true;
    }

    aplicarFiltros() {
        const { cultivo, productor, search } = this.filtros;
        this.ventasFiltradas = this.ventasAll.filter(v =>
            this.cumpleFiltroEstado(v) &&
            (!cultivo || v.cultivo === cultivo) &&
            (!productor || v.productor === productor) &&
            (!search || JSON.stringify(v).toLowerCase().includes(search.toLowerCase()))
        );
        this.currentPage = 1;
        this.updatePage();
    }

    handleFilterChange(event) {
        const tipo = event.target.dataset.filter;
        const valor = event.target.value;
        this.filtros[tipo] = valor;
        if (tipo === 'estado') {
            this.filtros.grupo = '';
        }
        this.aplicarFiltros();
    }

    handleSearch(event) {
        this.filtros.search = event.target.value;
        this.aplicarFiltros();
    }

    updatePage() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.ventas = this.ventasFiltradas.slice(start, end);
    }

    get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= Math.ceil(this.ventasFiltradas.length / this.pageSize);
    }

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePage();
        }
    }

    handleNext() {
        if (this.currentPage < Math.ceil(this.ventasFiltradas.length / this.pageSize)) {
            this.currentPage++;
            this.updatePage();
        }
    }

    handleVerFactura(event) {
        const ventaId = event.currentTarget.dataset.id; 
        getAttachments({ ventaId })
            .then(attachments => {
                if (attachments.length > 0) {
                    const docId = attachments[0].ContentDocumentId;
                    window.open(`/sfc/servlet.shepherd/document/download/${docId}?operationContext=S1`, '_blank');
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Éxito',
                            message: 'Factura descargada',
                            variant: 'success'
                        })
                    );
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Información',
                            message: 'No hay adjuntos PDF para este registro',
                            variant: 'info'
                        })
                    );
                }
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Error al descargar la factura: ' + (error.body?.message || error.message),
                        variant: 'error'
                    })
                );
            });
    }

    handleSubirFactura(event) {
        console.log('event.currentTarget.dataset.id;: ', event.currentTarget.dataset.id);
        this.selectedRowId = event.currentTarget.dataset.id;;
        this.showFileUploadModal = true;
    }

    closeFileUpload() {
        this.showFileUploadModal = false;
        this.selectedRowId = null;
    }

    get acceptedFormats() {
        return ['.pdf'];
    }

    ValidateData(){
        if(this.formattedDate != null && this.formattedDate != '' && this.customCode != null && this.customCode != ''){
            this.uploadFactura = false;
        }
        else {
            this.uploadFactura = true;
        }
    }

    handleDateChange(event) {
    const rawDate = event.target.value; // formato yyyy-mm-dd
    const [year, month, day] = rawDate.split('-');
    this.formattedDate = `${year}-${month}-${day}`; // mantiene ISO para el input
    console.log(this.formattedDate);
    this.ValidateData();
  }

  handleCodeChange(event) {
    const value = event.target.value;
    const regex = /^[ABC]-\d{4,5}-\d{8}$/;

    if (regex.test(value)) {
      this.customCode = value;
    } else {
      this.customCode = null;
    }
    this.ValidateData();
  }

    async updateOpp(){
            await updateOpportunity({recordId: this.selectedRowId, fechaEmision: this.formattedDate, numComprobante: this.customCode}).then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Éxito',
                    message: `Factura ${this.customCode} guardada correctamente`,
                    variant: 'success'
                })
            );
            this.isLoading = false;
            this.handleRefresh();
            })
            .catch(error => {
                this.dispatchEvent(
                new ShowToastEvent({
                    title: 'error',
                    message: `Error al guardar la factura`,
                    variant: 'error'
                })
            );
            });
        }

    handleSave() {
        if(this.formattedDate != null && this.customCode != null){
            this.isLoading = true;
            this.updateOpp();
            this.closeFileUpload();
        }
        else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: `Debe completar correctamente los campos N° de Comprobante y Fecha de emisión`,
                    variant: 'error'
                })
            );
        }
    }

    
    handleUploadFinished(event) {
        if(this.formattedDate != null && this.customCode != null){
            const file = event.detail.files[0];
            console.log('File: ', file);
            console.log('File name: ', file.name);
            console.log('File type: ', file.mimeType);
            if (!file.name.toLowerCase().endsWith('.pdf')) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Solo se permite subir un archivo PDF',
                        variant: 'error'
                    })
                );
                return;
            }
            const isValidExtension = file.name.toLowerCase().endsWith('.pdf');
            const isValidMimeType = file.mimeType === 'application/pdf';

            console.log('file.name.toLowerCase().endsWith(.pdf): ', file.name.toLowerCase().endsWith('.pdf'));
            console.log('isValidMimeType: ', isValidMimeType);
            
            if (!isValidExtension || !isValidMimeType) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: `El archivo "${file.name}" no es un PDF válido. Solo se permiten archivos PDF.`,
                        variant: 'error'
                    })
                );
                return;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Éxito',
                    message: `Archivo PDF "${file.name}" subido correctamente`,
                    variant: 'success'
                })
            );        
        }
        else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: `Debe completar correctamente los campos N° de Comprobante y Fecha de emisión`,
                    variant: 'error'
                })
            );
        }
    }

    handleRefresh() {
        this.isLoading = true;
        window.location.reload(); // fuerza reload completo
    }

    showSuccessToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Éxito',
                message: message,
                variant: 'success'
            })
        );
    }
    showErrorToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }    
    
}