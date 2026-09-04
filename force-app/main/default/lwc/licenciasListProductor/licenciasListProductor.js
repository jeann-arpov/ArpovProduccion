import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getLicencias from '@salesforce/apex/LicenciasController.getLicenciasProductor';
import getEstadosLicencia from '@salesforce/apex/LicenciasController.getEstadosLicencia';
import getOrigenesLicencia from '@salesforce/apex/LicenciasController.getOrigenesLicenciaProductor';
import getTiposLicencia from '@salesforce/apex/LicenciasController.getTiposLicencia';
import getLicensesReport from '@salesforce/apex/LicenseReportService.getLicensesReport';
import { fetchCultivoOptions, fetchCultivoSummary } from 'c/cultivoResumenService';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import getUrl from '@salesforce/apex/SolicitarLicencia.getUrl';
import singleNewLicenseRequestJWTSigner from '@salesforce/apex/CustomJWTSigner.singleNewLicenseRequestJWTSigner';
import singleLicenseJWTSigner from '@salesforce/apex/CustomJWTSigner.singleLicenseJWTSigner';
import uId from '@salesforce/user/Id';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import CONTACT_ID from "@salesforce/schema/User.ContactId";
import { redirectToSglWithToken } from 'c/utils';
import { trackGa4Event } from 'c/portalGa4Events';

function licenseStatusTone(estadoVisual) {
    const s = (estadoVisual || '').toLowerCase();
    if (/aprob/.test(s)) return 'ok';
    if (/rechaz/.test(s)) return 'danger';
    if (/curso/.test(s)) return 'warn';
    return 'info';
}

export default class LicenciasListProductor extends NavigationMixin(LightningElement) {
    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    @track licencias = [];
    @track estados = [];
    @track origenes = [];
    @track tipos = [];

    @track selectedEstado = '';
    @track selectedOrigen = '';
    @track selectedTipo = '';
    @track searchTerm = '';
    @track selectedCarta = '';

    @track totalRegistros = 0;
    @track showModal = false;
    @track showReportModal = false;
    @track isReportLoading = false;
    @track reportResponse = {
        success: false,
        message: '',
        data: null,
        statusCode: null
    };
    @track isLoading = true;
    @track renderFilters = false;
    @track cultivoOptions = [];
    @track cultivoSummaryRows = [];
    @track selectedCultivoId;
    @track cultivoSummaryTotal = 0;
    @track cultivoSummaryLoading = false;
    @track showCultivoResumen = false;
    initialized = false;

    // Configuración de paginación
    pageSize = 50;
    listPageSize = 0;
    currentPage = 1;
    totalPages = 1;

    columns = [
        { label: 'Fecha', fieldName: 'fecha' },
        { label: 'Código', fieldName: 'name', type: 'link' },
        { label: 'CUIT', fieldName: 'cuit' },
        { label: 'Razón social', fieldName: 'productor' },
        { label: 'Marca', fieldName: 'marca' },
        { label: 'Tecnología', fieldName: 'origen' },
        { label: 'Origen', fieldName: 'tipo' },
        { label: 'Estado', fieldName: 'statusLabel', type: 'badge', toneField: 'statusTone' },
        { label: 'Comercio', fieldName: 'comercio' },
        { label: 'Email', fieldName: 'emailDisplay', type: 'mailto' },
        { label: 'Teléfono', fieldName: 'telefonoDisplay' }
    ];

    mobileFields = [
        { label: 'Fecha', fieldName: 'fecha' },
        { label: 'CUIT', fieldName: 'cuit' },
        { label: 'Razón social', fieldName: 'productor' },
        { label: 'Marca', fieldName: 'marca' },
        { label: 'Tecnología', fieldName: 'origen' },
        { label: 'Origen', fieldName: 'tipo' },
        { label: 'Comercio', fieldName: 'comercio' },
        { label: 'Email', fieldName: 'emailDisplay', valueClassField: 'emailValueClass' }
    ];
    
    // URLs y IDs
    url;
    currentUserId = uId;
    currentContactId;
    
    // Debounce para búsqueda
    searchTimeout;
    
    // Almacenamiento de filtros actuales
    currentFilters = {};

    // Mapeo de estados para visualización
    ESTADO_MAP = {
        'Creada': 'En curso',
        'A validar': 'En curso',
        'Validada': 'En curso',
        'Solicitada': 'En curso',
        'Licencia Firmada': 'En curso',
        'En Proceso de Aprobacion': 'En curso',
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
            'En Proceso de Aprobacion'
        ],
        'Aprobada': ['Aprobada'],
        'Rechazada': ['Rechazada']
    };

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
    }

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
        if (this.initialized) {
            return;
        }
        this.initialized = true;
        this.isLoading = true;

        try {
            await this.loadFilters();
            this.loadSessionFilters();

            await Promise.all([
                this.loadLicencias({ manageLoading: false }),
                this.loadCultivoResumenOptions()
            ]);

            this.showCultivoResumen = this.cultivoOptions.length > 0;
            this.renderFilters = true;
        } catch (error) {
            console.error('Error cargando datos iniciales:', error);
        } finally {
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

    async loadCultivoResumenOptions() {
        try {
            const { options, defaultId } = await fetchCultivoOptions();
            this.cultivoOptions = options;

            if (options.length && !this.selectedCultivoId) {
                this.selectedCultivoId = defaultId;
                await this.loadCultivoSummary();
            }
        } catch (error) {
            console.error('Error cargando cultivos para resumen:', error);
            this.cultivoOptions = [];
        }
    }

    async loadCultivoSummary() {
        if (!this.selectedCultivoId) {
            this.cultivoSummaryRows = [];
            this.cultivoSummaryTotal = 0;
            return;
        }

        this.cultivoSummaryLoading = true;
        try {
            const summary = await fetchCultivoSummary(this.selectedCultivoId);
            this.cultivoSummaryRows = summary.rows;
            this.cultivoSummaryTotal = summary.total;
        } catch (error) {
            console.error('Error cargando resumen por cultivo:', error);
            this.cultivoSummaryRows = [];
            this.cultivoSummaryTotal = 0;
        } finally {
            this.cultivoSummaryLoading = false;
        }
    }

    handleCultivoResumenSelect(event) {
        this.selectedCultivoId = event.detail?.value;
        this.loadCultivoSummary();
    }

    loadSessionFilters() {
        console.log('Cargando filtros de sesión...');
        
        const estado = sessionStorage.getItem('selectedBucketProductor');
        const origen = sessionStorage.getItem('selectedOrigenProductor');
        const tipo = sessionStorage.getItem('selectedTipoProductor');
        const carta = sessionStorage.getItem('cartaOptionProductor');
        
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
        if (carta) {
            this.selectedCarta = carta;
            console.log('Carta de sesión:', carta);
        }
    }

    async loadLicencias(options = {}) {
        const { manageLoading = true } = options;
        if (manageLoading) {
            this.isLoading = true;
        }

        try {
            const filters = {};
            if (this.selectedEstado) filters.estado = this.selectedEstado;
            if (this.selectedOrigen) filters.origen = this.selectedOrigen;
            if (this.selectedTipo) filters.tipo = this.selectedTipo;
            if (this.selectedCarta) filters.carta = this.selectedCarta;
            if (this.searchTerm) filters.searchTerm = this.searchTerm;

            this.currentFilters = filters;

            const result = await getLicencias({
                pageNumber: this.currentPage,
                pageSize: this.pageSize,
                filtersJSON: JSON.stringify(filters)
            });

            this.licencias = result.licencias || [];
            this.totalRegistros = result.totalRecords || 0;
            this.totalPages = result.totalPages || 1;
        } catch (error) {
            console.error('Error loading licenses:', error);
            this.licencias = [];
            this.totalRegistros = 0;
            this.totalPages = 1;
        } finally {
            if (manageLoading) {
                this.isLoading = false;
            }
        }
    }

    // ========== HANDLERS DE FILTROS ==========

    get metaMaxElementos() {
        return 200;
    }

    get renderList() {
        return this.renderFilters;
    }

    get filtroResumen() {
        const partes = [];
        if (this.selectedEstado) partes.push(this.selectedEstado);
        if (this.selectedTipo) partes.push(this.selectedTipo);
        if (this.selectedOrigen) partes.push(this.selectedOrigen);
        if (this.searchTerm) partes.push(`"${this.searchTerm}"`);
        return partes.length ? partes.join(' - ') : 'Todas las licencias';
    }

    get estadoOptions() {
        return [
            { value: '', label: 'Estado' },
            { value: 'En curso', label: 'En curso' },
            { value: 'Aprobada', label: 'Aprobada' },
            { value: 'Rechazada', label: 'Rechazada' }
        ];
    }

    get tipoOptions() {
        return [
            { value: '', label: 'Tipo' },
            ...(this.tipos || []).map((item) => ({ value: item, label: item }))
        ];
    }

    get origenOptions() {
        return [
            { value: '', label: 'Tecnología' },
            ...(this.origenes || []).map((item) => ({ value: item, label: item }))
        ];
    }

    handleEstadoChange(event) {
        this.selectedEstado = event.detail.value || '';
        sessionStorage.setItem('selectedBucketProductor', this.selectedEstado);
        this.applyFiltersWithDebounce();
    }

    handleOrigenChange(event) {
        this.selectedOrigen = event.detail.value || '';
        sessionStorage.setItem('selectedOrigenProductor', this.selectedOrigen);
        this.applyFiltersWithDebounce();
    }

    handleTipoChange(event) {
        this.selectedTipo = event.detail.value || '';
        sessionStorage.setItem('selectedTipoProductor', this.selectedTipo);
        this.applyFiltersWithDebounce();
    }

    handleCartaChange(event) {
        this.selectedCarta = event.detail?.value || event.target.value;
        console.log('Carta cambiada a:', this.selectedCarta);
        sessionStorage.setItem('cartaOptionProductor', this.selectedCarta);
        this.applyFiltersWithDebounce();
    }

    handleSearchChange(event) {
        this.searchTerm = event.detail?.value ?? event.target?.value ?? '';
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
        return (this.licencias || []).map((l) => {
            const estadoVisual = this.ESTADO_MAP[l.estado] || l.estado;
            const email = (l.email || '').trim();
            const telefono = (l.telefono || '').trim();
            return {
                ...l,
                estadoVisual,
                statusLabel: estadoVisual,
                statusTone: licenseStatusTone(estadoVisual),
                emailDisplay: email || '—',
                telefonoDisplay: telefono || '—',
                emailValueClass: email ? 'email-link' : ''
            };
        });
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
        const row = event.detail?.row;
        const licenseId = row?.id || event.currentTarget?.dataset?.id;
        if (!licenseId) return;

        console.log('Acción en fila, ID:', licenseId);
        this.isLoading = true;
        
        singleLicenseJWTSigner({
            userId: this.currentUserId,
            contactId: this.currentContactId,
            licenseId
        })
        .then(response => {
            redirectToSglWithToken(this, this.url, response, window.location.href);
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
            redirectToSglWithToken(this, this.url + '/NewLicenseRequest', response, window.location.href);
        })
        .catch(error => {
            console.error('Error:', error);
            this.isLoading = false;
        });
    }

    // ========== LIFECYCLE HOOKS ==========

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        console.log('CurrentPageReference: ', currentPageReference);
        if (currentPageReference) {
            const estadoParam = currentPageReference.state?.estado;
            console.log('estadoParam: ', estadoParam);
            if (estadoParam) {
                this.selectedEstado = estadoParam;
                sessionStorage.setItem('selectedBucketProductor', estadoParam);
                
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

        console.warn('[LicenciasListProductor - Reporte] handleCall: click recibido');
        console.log('[LicenciasListProductor - Reporte] handleCall', {
            userId: this.currentUserId,
            contactId: this.currentContactId
        });

        this.showModal = false;

        try {
            await this.callReportService();
        } catch (error) {
            console.error('[LicenciasListProductor - Reporte] Error en handleCall:', error);
        }
    }

    logReportError(context, errorOrResponse) {
        const label = `[LicenciasListProductor - Reporte] ${context}`;
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
        console.warn('[LicenciasListProductor - Reporte] callReportService: inicio');

        this.reportResponse = {
            success: false,
            message: '',
            data: null,
            statusCode: null
        };
        this.isReportLoading = true;
        this.showReportModal = true;
        this.showModal = false;

        console.log('[LicenciasListProductor - Reporte] Iniciando solicitud', {
            userId: this.currentUserId,
            contactId: this.currentContactId
        });

        try {
            const result = await getLicensesReport({
                userId: this.currentUserId,
                contactId: this.currentContactId
            });

            console.log('[LicenciasListProductor - Reporte] Respuesta Apex recibida');
            console.log('Result completo:', JSON.stringify(result, null, 2));

            this.reportResponse = {
                success: result.success || false,
                message: result.message || 'Sin mensaje',
                data: result.data || null,
                statusCode: result.statusCode ?? null
            };

            if (this.reportResponse.success) {
                console.log('[LicenciasListProductor - Reporte] OK', {
                    message: this.reportResponse.message,
                    statusCode: this.reportResponse.statusCode
                });
                trackGa4Event('reporte_generado', {
                    modulo: 'Licencias',
                    tipo_reporte: 'licencias_productor'
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