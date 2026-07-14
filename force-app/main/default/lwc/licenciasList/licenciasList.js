import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getLicencias from '@salesforce/apex/LicenciasController.getLicencias';
import getEstadosLicencia from '@salesforce/apex/LicenciasController.getEstadosLicencia';
import getOrigenesLicencia from '@salesforce/apex/LicenciasController.getOrigenesLicenciaDistribuidor';
import getTiposLicencia from '@salesforce/apex/LicenciasController.getTiposLicencia';
import getLicensesReport from '@salesforce/apex/LicenseReportService.getLicensesReport';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import getUrl from '@salesforce/apex/SolicitarLicencia.getUrl';
import singleNewLicenseRequestJWTSigner from '@salesforce/apex/CustomJWTSigner.singleNewLicenseRequestJWTSigner';
import singleLicenseJWTSigner from '@salesforce/apex/CustomJWTSigner.singleLicenseJWTSigner';
import uId from '@salesforce/user/Id';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import CONTACT_ID from "@salesforce/schema/User.ContactId";

export default class LicenciasList extends NavigationMixin(LightningElement) {
    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    @track licencias = [];
    @track estados = [];
    @track origenes = [];
    @track tipos = [];

    @track selectedEstado = '';
    @track selectedOrigen = '';
    @track selectedTipo = '';
    @track searchTerm = '';

    @track totalRegistros = 0;
    @track showReportModal = false;
    @track isReportLoading = false;
    @track reportResponse = {
        success: false,
        message: '',
        data: null,
        statusCode: null
    };

    // Configuración de paginación del lado del servidor
    pageSize = 10;
    currentPage = 1;
    totalPages = 1;
    
    // URLs y IDs
    url;
    currentUserId = uId;
    currentContactId;
    
    // Debounce para búsqueda
    searchTimeout;
    
    // UI State
    @track isLoading = true;
    @track renderFilters = false;
    @track showModal = false;

    // Mapeo de estados para visualización
    ESTADO_MAP = {
        'Creada': 'En curso',
        'A validar': 'En curso',
        'Validada': 'En curso',
        'Solicitada': 'En curso',
        'Licencia Firmada': 'En curso',
        'En Proceso de Aprobacion': 'En curso',
        'En Proceso de Aprobación': 'En curso',
        'Aprobada': 'Aprobada',
        'Rechazada': 'Rechazada'
    };

    BUCKETS = {
        'En curso': [
            'Creada',
            'A validar',
            'Validada',
            'Solicitada',
            'Licencia Firmada',
            'En Proceso de Aprobacion',
            'En Proceso de Aprobación'
        ],
        'Aprobada': ['Aprobada'],
        'Rechazada': ['Rechazada']
    };

    @wire(getUrl, {})
    wiredGetUrl({error, data}) {
        if (data) {
            this.url = data;
        } else if (error) {
            console.error('Error getting URL:', error);
        }
    }

    @wire(getRecord, { recordId: '$currentUserId', fields: [CONTACT_ID] })
    wiredContactId({ error, data }) {
        if (data) {
            try {
                this.currentContactId = data.fields.ContactId.value;
                console.log('Contact ID obtenido:', this.currentContactId);
                this.loadInitialData();
            } catch (e) {
                console.error('Error getting contact:', e);
                this.isLoading = false;
            }
        } else if (error) {
            console.error('Error:', error);
            this.isLoading = false;
        }
    }

    async loadInitialData() {
        this.isLoading = true;
        console.log('Cargando datos iniciales...');
        
        try {
            // Cargar filtros
            await this.loadFilters();
            
            // Cargar filtros guardados en sesión
            this.loadSessionFilters();
            
            // Cargar licencias con los filtros aplicados
            await this.loadLicencias();
            
            // Habilitar renderizado de filtros
            this.renderFilters = true;
            this.isLoading = false;
            console.log('Datos cargados exitosamente');
            
        } catch (error) {
            console.error('Error cargando datos iniciales:', error);
            this.isLoading = false;
        }
    }

    async loadFilters() {
        try {
            console.log('Cargando filtros...');
            
            const promises = [
                getEstadosLicencia(),
                getOrigenesLicencia(),
                getTiposLicencia()
            ];
            
            const [estadosData, origenesData, tiposData] = await Promise.all(promises);
            
            this.estados = estadosData || [];
            this.origenes = origenesData || [];
            this.tipos = tiposData || [];
            
            console.log('Filtros cargados:', {
                estados: this.estados.length,
                origenes: this.origenes.length,
                tipos: this.tipos.length
            });
            
        } catch (error) {
            console.error('Error cargando filtros:', error);
            this.estados = [];
            this.origenes = [];
            this.tipos = [];
        }
    }

    loadSessionFilters() {
        console.log('Cargando filtros de sesión...');
        
        const estado = sessionStorage.getItem('selectedBucket');
        const origen = sessionStorage.getItem('selectedOrigen');
        const tipo = sessionStorage.getItem('selectedTipo');
        
        if (estado) {
            this.selectedEstado = estado;
            console.log('Estado de sesión:', estado);
        }
        if (origen) {
            this.selectedOrigen = origen;
            console.log('Origen de sesión:', origen);
        }
        if (tipo) {
            this.selectedTipo = tipo;
            console.log('Tipo de sesión:', tipo);
        }
    }

   async loadLicencias() {
    this.isLoading = true;
    console.log('Cargando licencias, página:', this.currentPage);
    
    // Construir objeto de filtros
    const filters = {};
    if (this.selectedEstado) filters.estado = this.selectedEstado;
    if (this.selectedOrigen) filters.origen = this.selectedOrigen;
    if (this.selectedTipo) filters.tipo = this.selectedTipo;
    if (this.searchTerm) filters.searchTerm = this.searchTerm;
    
    console.log('Filtros aplicados:', filters);
    
    try {
        // Llamar al método Apex con paginación y filtros
        const result = await getLicencias({
            pageNumber: this.currentPage,
            pageSize: this.pageSize,
            filtersJSON: JSON.stringify(filters)
        });
        
        console.log('Resultado recibido:', {
            licenciasCount: result.licencias ? result.licencias.length : 0,
            totalRecords: result.totalRecords,
            totalPages: result.totalPages
        });
        
        // Actualizar datos del componente
        this.licencias = result.licencias || [];
        this.totalRegistros = result.totalRecords || 0;
        this.totalPages = result.totalPages || 1;
        
        console.log('Licencias cargadas:', this.licencias.length);
        
    } catch (error) {
        console.error('Error loading licenses:', error);
        this.licencias = [];
        this.totalRegistros = 0;
        this.totalPages = 1;
    } finally {
        this.isLoading = false;
    }
}

    // ========== HANDLERS DE FILTROS ==========

    handleEstadoChange(event) {
        this.selectedEstado = event.target.value;
        console.log('Estado cambiado a:', this.selectedEstado);
        sessionStorage.setItem('selectedBucket', this.selectedEstado);
        this.applyFiltersWithDebounce();
    }

    handleOrigenChange(event) {
        this.selectedOrigen = event.target.value;
        console.log('Origen cambiado a:', this.selectedOrigen);
        sessionStorage.setItem('selectedOrigen', this.selectedOrigen);
        this.applyFiltersWithDebounce();
    }

    handleTipoChange(event) {
        this.selectedTipo = event.target.value;
        console.log('Tipo cambiado a:', this.selectedTipo);
        sessionStorage.setItem('selectedTipo', this.selectedTipo);
        this.applyFiltersWithDebounce();
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        console.log('Término de búsqueda:', this.searchTerm);
        this.applyFiltersWithDebounce();
    }

    applyFiltersWithDebounce() {
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        
        this.searchTimeout = setTimeout(() => {
            console.log('Aplicando filtros después de debounce...');
            this.currentPage = 1;
            this.loadLicencias();
        }, 300);
    }

    // ========== PAGINACIÓN ==========

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
            console.log('Página anterior:', this.currentPage);
            this.loadLicencias();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            console.log('Página siguiente:', this.currentPage);
            this.loadLicencias();
        }
    }

    get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    // ========== GETTERS PARA DATOS ==========

    get decoratedLicencias() {
        return (this.licencias || []).map(l => ({
            ...l,
            estadoVisual: this.ESTADO_MAP[l.estado] || l.estado
        }));
    }

    get hayLicencias() {
        return this.decoratedLicencias && this.decoratedLicencias.length > 0;
    }

    get noHayLicencias() {
        return !this.hayLicencias && !this.isLoading;
    }

    // ========== MÉTODOS DE MODAL ==========

    openModal() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }

    // ========== HANDLERS DE ACCIONES ==========

    handleRowAction(event) {
        const licenseId = event.currentTarget.dataset.id;
        console.log('Acción en fila, ID:', licenseId);
        this.isLoading = true;
        
        singleLicenseJWTSigner({
            userId: this.currentUserId,
            contactId: this.currentContactId,
            licenseId: licenseId
        })
        .then(response => {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: this.url + '?token=' + response + '&url=' + window.location.href
                }
            }, true);
        })
        .catch(error => {
            console.error('Error:', error);
            this.isLoading = false;
        });
    }

    handleSolicitarLicencia() {
        console.log('Solicitando nueva licencia');
        this.isLoading = true;
        
        singleNewLicenseRequestJWTSigner({
            userId: this.currentUserId,
            contactId: this.currentContactId
        })
        .then(response => {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: this.url + '/NewLicenseRequest' + '?token=' + response + '&url=' + window.location.href
                }
            }, true);
        })
        .catch(error => {
            console.error('Error:', error);
            this.isLoading = false;
        });
    }

    // ========== LIFECYCLE HOOKS ==========

    renderedCallback() {
        if (this.renderFilters && (this.selectedEstado || this.selectedOrigen || this.selectedTipo)) {
            this.updateFilterSelects();
        }
    }

    updateFilterSelects() {
        setTimeout(() => {
            const selects = {
                'estadoSelect': this.selectedEstado,
                'origenSelect': this.selectedOrigen,
                'tipoSelect': this.selectedTipo
            };
            
            Object.keys(selects).forEach(selector => {
                const element = this.template.querySelector(`[data-id="${selector}"]`);
                if (element && selects[selector]) {
                    element.value = selects[selector];
                    console.log(`Select ${selector} actualizado a:`, selects[selector]);
                }
            });
        }, 100);
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        console.log('CurrentPageReference: ', currentPageReference);
        if (currentPageReference) {
            const estadoParam = currentPageReference.state?.estado;
            console.log('estadoParam: ', estadoParam);
            if (estadoParam) {
                // Normalizar encoding
                const decodedEstado = decodeURIComponent(estadoParam);
                
                // Mapear estado del URL a bucket
                if (decodedEstado === 'En Proceso de Aprobación') {
                    this.selectedEstado = 'En curso';
                } else if (decodedEstado === 'Aprobada') {
                    this.selectedEstado = 'Aprobada';
                } else if (decodedEstado === 'Rechazada') {
                    this.selectedEstado = 'Rechazada';
                }
                
                sessionStorage.setItem('selectedBucket', this.selectedEstado);
                
                // Si ya tenemos los datos cargados, aplicar filtros
                if (this.renderFilters) {
                    this.applyFiltersWithDebounce();
                }
            }
        }
    }

    // ========== REPORTE ==========

    async handleCall(event) {
        if (event) {
            event.stopPropagation();
            event.preventDefault();
        }

        // Log síncrono inmediato al click (antes de cualquier await)
        console.warn('[LicenciasList - Reporte] handleCall: click recibido');
        console.log('[LicenciasList - Reporte] handleCall', {
            userId: this.currentUserId,
            contactId: this.currentContactId,
            showModal: this.showModal,
            showReportModal: this.showReportModal
        });

        this.showModal = false;

        try {
            await this.callReportService();
        } catch (error) {
            console.error('[LicenciasList - Reporte] Error no capturado en handleCall:', error);
        }
    }

    logReportError(context, errorOrResponse) {
        const label = `[LicenciasList - Reporte] ${context}`;
        console.group(label);

        if (errorOrResponse?.success === false) {
            const { message, statusCode, data } = errorOrResponse;
            console.error('Tipo: respuesta del servicio con error');
            console.error('Mensaje:', message);
            console.error('Status code:', statusCode);
            console.error('Data:', data);
            try {
                console.error('Respuesta completa:', JSON.stringify(errorOrResponse, null, 2));
            } catch (e) {
                console.error('No se pudo serializar la respuesta:', e);
            }
        } else {
            const error = errorOrResponse;
            console.error('Tipo: excepción al invocar Apex');
            console.error('message:', error?.message);
            console.error('statusCode:', error?.statusCode);
            console.error('statusText:', error?.statusText);

            if (error?.body) {
                const body = error.body;
                console.error('body.message:', body.message);
                console.error('body.exceptionType:', body.exceptionType);
                console.error('body.stackTrace:', body.stackTrace);
                console.error('body.pageErrors:', body.pageErrors);
                console.error('body.fieldErrors:', body.fieldErrors);
                console.error('body.output:', body.output);
                console.error('body (completo):', body);
            }

            try {
                console.error(
                    'Error completo (JSON):',
                    JSON.stringify(error, Object.getOwnPropertyNames(error ?? {}), 2)
                );
            } catch (e) {
                console.error('No se pudo serializar el error:', e);
                console.error('Objeto error:', error);
            }
        }

        console.groupEnd();
    }

    extractReportErrorMessage(error) {
        if (!error) {
            return 'Error inesperado al consultar el servicio';
        }
        if (error.body?.message) {
            return error.body.message;
        }
        if (error.body?.pageErrors?.length) {
            return error.body.pageErrors.map((e) => e.message).join('; ');
        }
        if (error.body?.output?.errors?.length) {
            return error.body.output.errors.map((e) => e.message).join('; ');
        }
        if (error.message) {
            return error.message;
        }
        return 'Error inesperado al consultar el servicio';
    }

    async callReportService() {
        console.warn('[LicenciasList - Reporte] callReportService: inicio');

        this.reportResponse = {
            success: false,
            message: '',
            data: null,
            statusCode: null
        };
        this.isReportLoading = true;
        this.showReportModal = true;
        this.showModal = false;

        console.log('[LicenciasList - Reporte] Iniciando solicitud', {
            userId: this.currentUserId,
            contactId: this.currentContactId
        });

        try {
            const result = await getLicensesReport({
                userId: this.currentUserId,
                contactId: this.currentContactId
            });

            console.log('[LicenciasList - Reporte] Respuesta Apex recibida');
            console.log('Result completo:', JSON.stringify(result, null, 2));

            this.reportResponse = {
                success: result.success || false,
                message: result.message || 'Sin mensaje',
                data: result.data || null,
                statusCode: result.statusCode ?? null
            };

            if (this.reportResponse.success) {
                console.log('[LicenciasList - Reporte] OK', {
                    message: this.reportResponse.message,
                    statusCode: this.reportResponse.statusCode
                });
            } else {
                this.logReportError('Error en respuesta del servicio', this.reportResponse);
            }
        } catch (error) {
            this.logReportError('Excepción al llamar getLicensesReport', error);

            this.reportResponse = {
                success: false,
                message: this.extractReportErrorMessage(error),
                data: error?.body ?? error,
                statusCode: error?.statusCode ?? null
            };
        } finally {
            this.isReportLoading = false;
        }
    }

    handleCloseReportModal() {
        this.showReportModal = false;
        this.showModal = false;
    }

    handleRetryReport() {
        this.callReportService();
    }

    get formattedReportData() {
        if (this.reportResponse.data) {
            try {
                return JSON.stringify(this.reportResponse.data, null, 2);
            } catch (e) {
                return String(this.reportResponse.data);
            }
        }
        return '';
    }

    get showRetryButton() {
        return !this.isReportLoading && !this.reportResponse.success;
    }
}