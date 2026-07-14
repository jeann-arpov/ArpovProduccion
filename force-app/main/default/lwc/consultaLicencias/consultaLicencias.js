import { LightningElement, track } from 'lwc';
import { errorEvent, doRequest } from 'c/utils';
import searchProductores from '@salesforce/apex/ConsultaLicenciasController.searchProductores';
import getLicencias from '@salesforce/apex/ConsultaLicenciasController.getLicencias';
import getEstadosLicencia from '@salesforce/apex/LicenciasController.getEstadosLicencia';
//import getOrigenesLicencia from '@salesforce/apex/LicenciasController.getOrigenesLicencia';
import getTiposLicencia from '@salesforce/apex/LicenciasController.getTiposLicencia';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import marcasSE from '@salesforce/resourceUrl/MarcasSE';

export default class ConsultaLicencias extends LightningElement {
    // URL del icono de búsqueda
    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    // Propiedades reactivas
    @track licencias = [];
    @track estados = [];
    @track origenes = [];
    @track tipos = [];
    
    // Filtros
    @track selectedEstado = '';
    @track selectedOrigen = '';
    @track selectedTipo = '';
    @track searchTerm = '';
    @track selectedProductor = null;
    
    // Paginación
    @track totalRegistros = 0;
    pageSize = 50;
    currentPage = 1;
    totalPages = 1;
    
    // Estados
    @track isLoading = true;
    @track renderFilters = false;
    @track loadingLicencias = false;
    
    // Debounce
    searchTimeout;
    
    // Diccionario Marca → Archivo
    marcaMap = {
        'GDM': 'GDM.png',
        'Brevant': 'Brevant.jpg',
        'Syngenta': 'Syngenta.jpg',
        'Pioneer': 'Pioneer.jpg',
        'Stine': 'Stine.jpg',
        'ACA': 'ACA.jpg',
        'MacroSeed': 'MacroSeed.jpg',
        'Bioceres': 'Bioceres.jpg',
        'BASF Credenz': 'BASF_Credenz.jpg',
        'Credenz': 'BASF_Credenz.jpg',
        'Corteva': 'Corteva.jpg',
        'klein': 'klein.png'
    };

    // Mapeo de estados
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

    async connectedCallback() {
        this.isLoading = true;
        this.doRequest = doRequest.bind(this);
        
        try {
            // Cargar filtros
            await this.loadFilters();
            
            // Cargar filtros guardados en sesión
            this.loadSessionFilters();
            
            // Habilitar renderizado de filtros
            this.renderFilters = true;
            this.isLoading = false;
            
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
               // getOrigenesLicencia(),
                getTiposLicencia()
            ];
            
           // const [estadosData, origenesData, tiposData] = await Promise.all(promises);
              const [estadosData, tiposData] = await Promise.all(promises);
            this.estados = estadosData || [];
            //this.origenes = origenesData || [];
            this.tipos = tiposData || [];
            
            console.log('Filtros cargados:', {
                estados: this.estados.length,
               // origenes: this.origenes.length,
                tipos: this.tipos.length
            });
            
        } catch (error) {
            console.error('Error cargando filtros:', error);
            this.estados = [];
            //this.origenes = [];
            this.tipos = [];
        }
    }

    loadSessionFilters() {
        console.log('Cargando filtros de sesión...');
        
        const estado = sessionStorage.getItem('selectedEstadoConsulta');
       // const origen = sessionStorage.getItem('selectedOrigenConsulta');
        const tipo = sessionStorage.getItem('selectedTipoConsulta');
        
        if (estado) {
            this.selectedEstado = estado;
            console.log('Estado de sesión:', estado);
        }
       /* if (origen) {
            this.selectedOrigen = origen;
            console.log('Origen de sesión:', origen);
        }*/
        if (tipo) {
            this.selectedTipo = tipo;
            console.log('Tipo de sesión:', tipo);
        }
    }

    async updateLicencias(event) {
        console.log('🎯 event del select ', JSON.stringify(event));
        
        if (!event.detail || !event.detail[0]) {
            this.selectedProductor = null;
            this.licencias = [];
            this.totalRegistros = 0;
            this.totalPages = 1;
            this.currentPage = 1;
            return;
        }

        this.selectedProductor = event.detail[0];
        this.loadingLicencias = true;
        this.currentPage = 1;
        
        await this.loadLicencias();
    }

    async loadLicencias() {
        if (!this.selectedProductor) {
            this.licencias = [];
            this.totalRegistros = 0;
            this.totalPages = 1;
            return;
        }

        this.loadingLicencias = true;
        console.log('Cargando licencias, página:', this.currentPage);
        
        try {
            // Construir filtros
            const filters = {};
            if (this.selectedEstado) filters.estado = this.selectedEstado;
           // if (this.selectedOrigen) filters.origen = this.selectedOrigen;
            if (this.selectedTipo) filters.tipo = this.selectedTipo;
            if (this.searchTerm) filters.searchTerm = this.searchTerm;
            
            // Llamar al método Apex con paginación y filtros
            const result = await getLicencias({
                productorId: this.selectedProductor,
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
            this.totalRegistros = result.totalRecords || 0;
            this.totalPages = result.totalPages || 1;
            
            // Formatear licencias
            this.licencias = (result.licencias || []).map(l => {
                let licencia = { ...l };
                
                // Estado visual
                licencia.estadoVisual = this.ESTADO_MAP[licencia.Estado__c] || licencia.Estado__c;
                
                // Marca dinámica
                let marcaName = null;
                if (licencia.Marcas_Productor_Comercio__c) {
                    const match = licencia.Marcas_Productor_Comercio__c.match(/alt="([^"]+)"/);
                    console.log(`Extrayendo marca de licencia ${licencia.Id}:`, licencia.Marcas_Productor_Comercio__c, '→', match);
                    if (match && match[1]) {
                        marcaName = match[1];
                        console.log(`Marca encontrada para licencia ${licencia.Id}:`, marcaName);
                    }
                }
                if (marcaName && this.marcaMap[marcaName]) {
                    licencia.marcaUrl = `${marcasSE}/${this.marcaMap[marcaName]}`;
                    console.log(`URL de marca para licencia ${licencia.Id}:`, licencia.marcaUrl);
                }
                
                return licencia;
            });
            
            console.log('Licencias cargadas:', this.licencias.length);
            
        } catch (error) {
            console.error('Error loading licenses:', error);
            this.licencias = [];
            this.totalRegistros = 0;
            this.totalPages = 1;
        } finally {
            this.loadingLicencias = false;
        }
    }

    // ========== HANDLERS DE FILTROS ==========

    handleEstadoChange(event) {
        this.selectedEstado = event.target.value;
        console.log('Estado cambiado a:', this.selectedEstado);
        sessionStorage.setItem('selectedEstadoConsulta', this.selectedEstado);
        this.applyFiltersWithDebounce();
    }

   /* handleOrigenChange(event) {
        this.selectedOrigen = event.target.value;
        console.log('Origen cambiado a:', this.selectedOrigen);
        sessionStorage.setItem('selectedOrigenConsulta', this.selectedOrigen);
        this.applyFiltersWithDebounce();
    }*/

    handleTipoChange(event) {
        this.selectedTipo = event.target.value;
        console.log('Tipo cambiado a:', this.selectedTipo);
        sessionStorage.setItem('selectedTipoConsulta', this.selectedTipo);
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

    // ========== GETTERS ==========

    get hayLicencias() {
        return this.licencias && this.licencias.length > 0;
    }

    get noHayLicencias() {
        return !this.hayLicencias && !this.loadingLicencias && this.selectedProductor;
    }

    get mostrarTabla() {
        return this.selectedProductor && !this.loadingLicencias;
    }

    // ========== HANDLERS DE BÚSQUEDA ==========

    async search(event) {
        const lookup = event.target;
        await searchProductores(event.detail)
            .then(res => lookup.setSearchResults(res))
            .catch(e => this.onError(e));
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    // ========== LIFECYCLE HOOKS ==========

    renderedCallback() {
        if (this.renderFilters && (this.selectedEstado || this.selectedOrigen || this.selectedTipo)) {
            this.updateFilterSelects();
        }
    }
    /* const selects = {
                'estadoSelect': this.selectedEstado,
                'origenSelect': this.selectedOrigen,
                'tipoSelect': this.selectedTipo
            };*/

    updateFilterSelects() {
        setTimeout(() => {
            const selects = {
                'estadoSelect': this.selectedEstado,
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