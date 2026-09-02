import { LightningElement, track, wire } from 'lwc';
import getComprasHT from '@salesforce/apex/ComprasHTController.getComprasHT';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import { trackGa4Event } from 'c/portalGa4Events';

function pad(n) {
    return String(n).padStart(2, '0');
}

function formatDate(value) {
    if (!value) return '';
    const dt = new Date(value);
    if (Number.isNaN(dt.getTime())) return '';
    return `${pad(dt.getDate())}/${pad(dt.getMonth() + 1)}/${dt.getFullYear()}`;
}

function formatTotal(value) {
    if (value == null || value === '' || value === 'null') return '—';
    const num = Number(value);
    if (Number.isNaN(num)) return String(value);
    return num.toLocaleString('es-AR', { maximumFractionDigits: 0 });
}

function statusTone(estado) {
    const s = (estado || '').toLowerCase();
    if (/pagad/.test(s)) return 'ok';
    if (/vencid|cancel/.test(s)) return 'danger';
    if (/factur|pendiente/.test(s)) return 'warn';
    return 'info';
}

function splitVariedades(value) {
    return String(value || '')
        .split(';')
        .map((item) => item.trim())
        .filter((item) => item && item !== 'Sin variedad');
}

const STATUS_ORDER = ['Pagada', 'Facturada', 'Vencida', 'Cancelada', 'Pendiente de Facturación', 'Pendiente'];
const PAGE_SIZE = 200;
const SESSION_KEYS = {
    estado: 'selectedEstadoComprasProductor',
    cultivo: 'selectedCultivoComprasProductor',
    variedad: 'selectedVariedadComprasProductor'
};

export default class ComprasHtListProductor extends LightningElement {
    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    @track comprasAll = [];
    @track filtered = [];
    @track estadoSelectOptions = [];
    @track cultivoSelectOptions = [];
    @track variedadSelectOptions = [];
    @track loading = true;

    pageSize = PAGE_SIZE;
    estadoSeleccionado = 'todas';
    cultivoSeleccionado = 'todas';
    variedadSeleccionada = 'todas';
    searchTerm = '';
    searchTimeout;
    showFilters = false;
    _ga4ListadoTracked = false;

    columns = [
        { label: 'Fecha', fieldName: 'fechaLabel' },
        { label: 'Compra HT', fieldName: 'name', type: 'link' },
        { label: 'Total HT', fieldName: 'totalLabel' },
        { label: 'Variedades', fieldName: 'variedades' },
        { label: 'Cultivo', fieldName: 'cultivo' },
        { label: 'Estado', fieldName: 'statusLabel', type: 'badge', toneField: 'statusTone' },
        { label: '', fieldName: 'action', type: 'action', actionLabel: 'Ver' }
    ];

    mobileFields = [
        { label: 'Fecha', fieldName: 'fechaLabel' },
        { label: 'Cultivo', fieldName: 'cultivo' },
        { label: 'Variedades', fieldName: 'variedades' },
        { label: 'Total HT', fieldName: 'totalLabel' }
    ];

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
        this.loadSessionFilters();
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
    }

    loadSessionFilters() {
        this.estadoSeleccionado = sessionStorage.getItem(SESSION_KEYS.estado) || 'todas';
        this.cultivoSeleccionado = sessionStorage.getItem(SESSION_KEYS.cultivo) || 'todas';
        this.variedadSeleccionada = sessionStorage.getItem(SESSION_KEYS.variedad) || 'todas';
    }

    @wire(getComprasHT)
    wiredCompras({ data, error }) {
        if (data) {
            this.comprasAll = data.map((c) => {
                const estado = c.estado || 'Sin estado';
                return {
                    id: c.id,
                    name: c.compra,
                    fechaLabel: formatDate(c.fecha),
                    totalLabel: formatTotal(c.totalHt),
                    cultivo: c.cultivo || 'Sin cultivo',
                    variedades: c.variedades || 'Sin variedad',
                    varietyList: splitVariedades(c.variedades),
                    productor: c.productor || '',
                    comercio: c.comercio || '',
                    estado,
                    statusLabel: estado,
                    statusTone: statusTone(estado)
                };
            });

            this.applyFilters();
            this.showFilters = true;
            this.loading = false;

            if (!this._ga4ListadoTracked) {
                this._ga4ListadoTracked = true;
                trackGa4Event('ht_listado_vista', { portal: 'Productor' });
            }
        } else if (error) {
            this.loading = false;
            console.error('Error al cargar compras:', error);
        }
    }

    get totalRegistros() {
        return this.filtered.length;
    }

    get metaMaxElementos() {
        return PAGE_SIZE;
    }

    get filtroResumen() {
        const partes = [];
        if (this.estadoSeleccionado !== 'todas') partes.push(this.estadoSeleccionado);
        if (this.cultivoSeleccionado !== 'todas') partes.push(this.cultivoSeleccionado);
        if (this.variedadSeleccionada !== 'todas') partes.push(this.variedadSeleccionada);
        if (this.searchTerm) partes.push(`"${this.searchTerm}"`);
        return partes.length ? partes.join(' - ') : 'Todas las compras HT';
    }

    handleEstadoChange(event) {
        this.estadoSeleccionado = event.detail.value || 'todas';
        sessionStorage.setItem(SESSION_KEYS.estado, this.estadoSeleccionado);
        this.applyFiltersWithDebounce();
    }

    handleCultivoChange(event) {
        this.cultivoSeleccionado = event.detail.value || 'todas';
        sessionStorage.setItem(SESSION_KEYS.cultivo, this.cultivoSeleccionado);
        this.applyFiltersWithDebounce();
    }

    handleVariedadChange(event) {
        this.variedadSeleccionada = event.detail.value || 'todas';
        sessionStorage.setItem(SESSION_KEYS.variedad, this.variedadSeleccionada);
        this.applyFiltersWithDebounce();
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.applyFiltersWithDebounce();
    }

    applyFiltersWithDebounce() {
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        this.searchTimeout = setTimeout(() => {
            this.applyFilters();
        }, 300);
    }

    applyFilters() {
        const counts = {};
        this.comprasAll.forEach((row) => {
            counts[row.estado] = (counts[row.estado] || 0) + 1;
        });

        const statuses = Object.keys(counts).sort((a, b) => {
            const ia = STATUS_ORDER.indexOf(a);
            const ib = STATUS_ORDER.indexOf(b);
            if (ia === -1 && ib === -1) return a.localeCompare(b, 'es');
            if (ia === -1) return 1;
            if (ib === -1) return -1;
            return ia - ib;
        });

        this.estadoSelectOptions = [
            { value: 'todas', label: 'Estado' },
            ...statuses.map((estado) => ({ value: estado, label: estado }))
        ];

        const cultivoCounts = {};
        const variedadCounts = {};
        this.comprasAll.forEach((row) => {
            cultivoCounts[row.cultivo] = (cultivoCounts[row.cultivo] || 0) + 1;
            row.varietyList.forEach((variedad) => {
                variedadCounts[variedad] = (variedadCounts[variedad] || 0) + 1;
            });
        });

        this.cultivoSelectOptions = [
            { value: 'todas', label: 'Cultivo' },
            ...Object.keys(cultivoCounts)
                .sort((a, b) => a.localeCompare(b, 'es'))
                .map((cultivo) => ({ value: cultivo, label: cultivo }))
        ];

        this.variedadSelectOptions = [
            { value: 'todas', label: 'Variedad' },
            ...Object.keys(variedadCounts)
                .sort((a, b) => a.localeCompare(b, 'es'))
                .map((variedad) => ({ value: variedad, label: variedad }))
        ];

        const searchKey = (this.searchTerm || '').trim().toLowerCase();
        let rows = [...this.comprasAll];

        if (this.estadoSeleccionado !== 'todas') {
            rows = rows.filter((row) => row.estado === this.estadoSeleccionado);
        }
        if (this.cultivoSeleccionado !== 'todas') {
            rows = rows.filter((row) => row.cultivo === this.cultivoSeleccionado);
        }
        if (this.variedadSeleccionada !== 'todas') {
            rows = rows.filter((row) => row.varietyList.includes(this.variedadSeleccionada));
        }
        if (searchKey) {
            rows = rows.filter((row) => {
                const haystack = [
                    row.name,
                    row.productor,
                    row.comercio,
                    row.cultivo,
                    row.variedades,
                    row.estado
                ]
                    .join(' ')
                    .toLowerCase();
                return haystack.includes(searchKey);
            });
        }

        this.filtered = rows;
    }

    handleRowAction(event) {
        const row = event.detail.row;
        if (!row) return;
        this.goToCompra(row.id, row.name);
    }

    goToCompra(recordId, recordName) {
        const pathname = window.location.pathname;
        let basePath = '';
        if (pathname.includes('/SembraEvolucion/s')) {
            basePath = '/SembraEvolucion/s';
        } else if (pathname.includes('/Productores/s')) {
            basePath = '/Productores/s';
        } else {
            basePath = pathname.split('/s')[0] + '/s';
        }
        window.open(`${basePath}/compra-ht/${recordId}/${recordName}`, '_self');
    }
}
