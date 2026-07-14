import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getLicenciasObtentor from '@salesforce/apex/LicenciasController.getLicenciasObtentor';
import getEstadosLicencia from '@salesforce/apex/LicenciasController.getEstadosLicencia';
import getOrigenesLicencia from '@salesforce/apex/LicenciasController.getOrigenesLicencia';
import getTiposLicencia from '@salesforce/apex/LicenciasController.getTiposLicencia';
import getLicensesReport from '@salesforce/apex/LicenseReportService.getLicensesReport';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import getUrl from '@salesforce/apex/SolicitarLicencia.getUrl';
import singleNewLicenseRequestJWTSigner from '@salesforce/apex/CustomJWTSigner.singleNewLicenseRequestJWTSigner';
import singleLicenseJWTSigner from '@salesforce/apex/CustomJWTSigner.singleLicenseJWTSigner';
import uId from '@salesforce/user/Id';
import { getRecord } from "lightning/uiRecordApi";
import CONTACT_ID from "@salesforce/schema/User.ContactId";
import esUsuarioEspecial from '@salesforce/apex/LicenciasController.esUsuarioEspecial';

/**
 * Componente LWC para listar y gestionar licencias de obtentores
 * Permite filtrar, buscar, paginar y generar reportes de licencias
 */
export default class LicenciasListObtentor extends NavigationMixin(LightningElement) {
    // URL del icono de búsqueda desde recursos estáticos
    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    // Propiedades reactivas (@track) para datos y filtros
    @track licencias = [];
    @track estados = [];
    @track origenes = [];
    @track tipos = [];

    // Valores seleccionados en los filtros
    @track selectedEstado = '';
    @track selectedOrigen = '';
    @track selectedTipo = '';
    @track selectedCarta = '';
    @track searchTerm = '';

    // Propiedades para paginación y reportes
    @track totalRegistros = 0;
    @track showReportModal = false;
    @track isReportLoading = false;
    @track reportResponse = {
        success: false,
        message: '',
        data: null,
        statusCode: null
    };

    // Configuración de paginación
    pageSize = 50;
    currentPage = 1;
    totalPages = 1;
    
    // URLs y IDs
    url;
    isLoading = true;
    currentUserId = uId;
    currentContactId;
    
    // Control de renderizado
    renderFilters = false;

    // Control de modales
    @track showModal = false;
    
    // Debounce para búsqueda
    searchTimeout;

// AGREGAR esta propiedad:
@track esUsuarioEspecial = false; // Controla si es usuario especial
    
    // Almacenamiento de filtros actuales
    currentFilters = {};

    // AGREGAR este getter:
get mostrarFiltroTecnologia() {
    return !this.esUsuarioEspecial;
}

    /**
     * Getter que verifica si hay licencias para mostrar
     * @     * @returns {boolean} true si hay licencias, false si no
     */
    get hayLicencias() {
        return this.decoratedLicencias && this.decoratedLicencias.length > 0;
    }

    /**
     * Getter que verifica si no hay licencias (para mostrar mensaje)
     * @returns {boolean} true si no hay licencias y no está cargando
     */
    get noHayLicencias() {
        return !this.hayLicencias && !this.isLoading;
    }

    /**
     * Wire service para obtener URL base desde Apex
     */
    @wire(getUrl, {})
    wiredGetUrl({error, data}) {
        if (data) {
            this.url = data;
        } else if (error) {
            console.error('Error getting URL:', error);
        }
    }

    /**
     * Wire service para obtener el ContactId del usuario actual
     */
    @wire(getRecord, { recordId: '$currentUserId', fields: [CONTACT_ID] })
    wiredContactId({ error, data }) {
        if (data) {
            try {
                this.currentContactId = data.fields.ContactId.value;
                console.log('Contact ID obtenido:', this.currentContactId);
                // Cargar datos iniciales una vez que tenemos el ContactId
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

    /**
     * Carga inicial de datos: filtros y licencias
     */
    async loadInitialData() {
        this.isLoading = true;
        console.log('Cargando datos iniciales...');
        
        try {
              // AGREGAR: Verificar si es usuario especial
            const esEspecial = await esUsuarioEspecial();
            this.esUsuarioEspecial = esEspecial;
            console.log('Es usuario especial:', this.esUsuarioEspecial);
            // Cargar filtros (estados, orígenes, tipos)
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

    /**
     * Carga los valores para los filtros desde Apex
     */
    async loadFilters() {
    try {
        console.log('Cargando filtros...');
        
        // MODIFICAR: Cargar orígenes solo si NO es usuario especial
        const promises = [
            getEstadosLicencia(),
            getTiposLicencia()
        ];
        
        if (!this.esUsuarioEspecial) {
            promises.push(getOrigenesLicencia());
        } else {
            promises.push(Promise.resolve([])); // Para mantener el orden
        }
        
        const [estadosData, tiposData, origenesData] = await Promise.all(promises);
        
        this.estados = estadosData || [];
        this.tipos = tiposData || [];
        this.origenes = origenesData || [];
        
        console.log('Filtros cargados:', {
            estados: this.estados.length,
            origenes: this.origenes.length,
            tipos: this.tipos.length,
            esUsuarioEspecial: this.esUsuarioEspecial
        });
        
    } catch (error) {
        console.error('Error cargando filtros:', error);
        this.estados = [];
        this.origenes = [];
        this.tipos = [];
    }
}

    /**
     * Carga filtros guardados en sessionStorage
     * Permite persistir filtros entre recargas de página
     */
    loadSessionFilters() {
        console.log('Cargando filtros de sesión...');
        
        // Cargar filtros desde sessionStorage
        const cartaOption = sessionStorage.getItem('cartaOption');
        const estado = sessionStorage.getItem('selectedBucket');
        const origen = sessionStorage.getItem('selectedOrigen');
        const tipo = sessionStorage.getItem('selectedTipo');
        
        // Aplicar filtros si existen en sessionStorage
        if (cartaOption) {
            this.selectedCarta = cartaOption;
            console.log('Carta de sesión:', cartaOption);
        }
        if (estado) {
            this.selectedEstado = estado;
            console.log('Estado de sesión:', estado);
        }
       if (origen) {
            this.selectedOrigen = origen; // Filtro por tecnología/origen
            console.log('Origen de sesión:', origen);
        }
        if (tipo) {
            this.selectedTipo = tipo;
            console.log('Tipo de sesión:', tipo);
        }
    }

    /**
     * Carga licencias aplicando filtros actuales
     */
    async loadLicencias() {
        this.isLoading = true;
        console.log('Cargando licencias, página:', this.currentPage);
        
        // Construir objeto de filtros
        const filters = {};
        if (this.selectedEstado) filters.estado = this.selectedEstado;
        if (this.selectedOrigen) filters.origen = this.selectedOrigen;
        if (this.selectedTipo) filters.tipo = this.selectedTipo;
        if (this.selectedCarta) filters.carta = this.selectedCarta;
        if (this.searchTerm) filters.searchTerm = this.searchTerm;
        
        // Guardar filtros actuales
        this.currentFilters = filters;
        
        console.log('Filtros aplicados:', filters);
        
        try {
            // Llamar al método Apex con paginación y filtros
            const result = await getLicenciasObtentor({
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
            // Resetear datos en caso de error
            this.licencias = [];
            this.totalRegistros = 0;
            this.totalPages = 1;
        } finally {
            this.isLoading = false;
        }
    }

    // ========== HANDLERS DE FILTROS ==========

    /**
     * Handler para cambio en filtro de estado
     */
    handleEstadoChange(event) {
        this.selectedEstado = event.target.value;
        console.log('Estado cambiado a:', this.selectedEstado);
        sessionStorage.setItem('selectedBucket', this.selectedEstado);
        this.applyFiltersWithDebounce();
    }

    /**
     * Handler para cambio en filtro de origen
     */
    handleOrigenChange(event) {
        this.selectedOrigen = event.target.value;
        console.log('Origen cambiado a:', this.selectedOrigen);
        sessionStorage.setItem('selectedOrigen', this.selectedOrigen);
        this.applyFiltersWithDebounce();
    }

    /**
     * Handler para cambio en filtro de tipo
     */
    handleTipoChange(event) {
        this.selectedTipo = event.target.value;
        console.log('Tipo cambiado a:', this.selectedTipo);
        sessionStorage.setItem('selectedTipo', this.selectedTipo);
        this.applyFiltersWithDebounce();
    }

    /**
     * Handler para cambio en filtro de carta de aceptación
     */
    handleCartaChange(event) {
        this.selectedCarta = event.target.value;
        console.log('Carta cambiada a:', this.selectedCarta);
        sessionStorage.setItem('cartaOption', this.selectedCarta);
        this.applyFiltersWithDebounce();
    }

    /**
     * Handler para cambio en campo de búsqueda
     */
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        console.log('Término de búsqueda:', this.searchTerm);
        this.applyFiltersWithDebounce();
    }

    /**
     * Aplica filtros con debounce para evitar múltiples llamadas
     */
    applyFiltersWithDebounce() {
        // Limpiar timeout existente
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        
        // Establecer nuevo timeout (300ms de debounce)
        this.searchTimeout = setTimeout(() => {
            console.log('Aplicando filtros después de debounce...');
            this.currentPage = 1; // Resetear a primera página
            this.loadLicencias();
        }, 300);
    }

    // ========== PAGINACIÓN ==========

    /**
     * Navega a la página anterior
     */
    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
            console.log('Página anterior:', this.currentPage);
            this.loadLicencias();
        }
    }

    /**
     * Navega a la página siguiente
     */
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            console.log('Página siguiente:', this.currentPage);
            this.loadLicencias();
        }
    }

    /**
     * Getter para deshabilitar botón "Anterior"
     */
    get disablePrev() {
        return this.currentPage <= 1;
    }

    /**
     * Getter para deshabilitar botón "Siguiente"
     */
    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    // ========== MÉTODOS DE MODAL ==========

    /**
     * Abre el modal de confirmación para generar reporte
     */
    openModal() {
        this.showModal = true;
    }

    /**
     * Cierra el modal de confirmación
     */
    closeModal() {
        this.showModal = false;
    }

    async handleCall(event) {
        if (event) {
            event.stopPropagation();
            event.preventDefault();
        }

        console.warn('[LicenciasListObtentor - Reporte] handleCall: click recibido');
        console.log('[LicenciasListObtentor - Reporte] handleCall', {
            userId: this.currentUserId,
            contactId: this.currentContactId
        });

        this.showModal = false;

        try {
            await this.callReportService();
        } catch (error) {
            console.error('[LicenciasListObtentor - Reporte] Error en handleCall:', error);
        }
    }

    logReportError(context, errorOrResponse) {
        const label = `[LicenciasListObtentor - Reporte] ${context}`;
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

    /**
     * Llama al servicio de generación de reporte
     */
    async callReportService() {
        console.warn('[LicenciasListObtentor - Reporte] callReportService: inicio');

        this.reportResponse = {
            success: false,
            message: '',
            data: null,
            statusCode: null
        };
        this.isReportLoading = true;
        this.showReportModal = true;
        this.showModal = false;

        console.log('[LicenciasListObtentor - Reporte] Iniciando solicitud', {
            userId: this.currentUserId,
            contactId: this.currentContactId
        });

        try {
            const jwtToken = await singleNewLicenseRequestJWTSigner({
                userId: this.currentUserId,
                contactId: this.currentContactId
            });
            console.log('[LicenciasListObtentor - Reporte] JWT Token:', jwtToken);

            const result = await getLicensesReport({
                userId: this.currentUserId,
                contactId: this.currentContactId
            });

            console.log('[LicenciasListObtentor - Reporte] Respuesta Apex recibida');
            console.log('Result completo:', JSON.stringify(result, null, 2));

            this.reportResponse = {
                success: result.success || false,
                message: result.message || 'Sin mensaje',
                data: result.data || null,
                statusCode: result.statusCode ?? null
            };

            if (this.reportResponse.success) {
                console.log('[LicenciasListObtentor - Reporte] OK', {
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

    /**
     * Cierra el modal de reporte
     */
    handleCloseReportModal() {
        this.showReportModal = false;
        this.showModal = false;
    }

    /**
     * Reintenta la generación del reporte
     */
    handleRetryReport() {
        this.callReportService();
    }

    /**
     * Getter para formatear datos del reporte como JSON
     */
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

    /**
     * Getter para mostrar botón de reintentar
     */
    get showRetryButton() {
        return !this.isReportLoading && !this.reportResponse.success;
    }

    // ========== GETTERS PARA DATOS ==========

    /**
     * Getter para licencias decoradas (asegura array)
     */
    get decoratedLicencias() {
        return this.licencias || [];
    }

    // ========== HANDLERS DE ACCIONES ==========

    /**
     * Handler para acción en fila (clic en licencia)
     */
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

    /**
     * Handler para solicitar nueva licencia
     */
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

    /**
     * Lifecycle hook - Se ejecuta después de cada renderizado
     * Actualiza los selects con los valores de sesión
     */
    renderedCallback() {
        // Solo ejecutar si los filtros están renderizados y tenemos valores
        if (this.renderFilters && (this.selectedEstado || this.selectedOrigen || this.selectedTipo || this.selectedCarta)) {
            this.updateFilterSelects();
        }
    }

    /**
     * Actualiza los elementos select con los valores almacenados
     */
    updateFilterSelects() {
        // Pequeño delay para asegurar que el DOM esté listo
        setTimeout(() => {
            const selects = {
                'cartaSelect': this.selectedCarta,
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
}