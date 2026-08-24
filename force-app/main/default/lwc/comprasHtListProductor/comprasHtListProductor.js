import { LightningElement, track, wire } from 'lwc';
import getComprasHT from '@salesforce/apex/ComprasHTController.getComprasHT';
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

export default class ComprasHtListProductor extends LightningElement {
    @track comprasAll = [];
    @track filtered = [];
    @track data = [];
    @track statusPills = [];
    @track cultivoPills = [];
    @track variedadPills = [];

    estadoSeleccionado = 'todas';
    cultivoSeleccionado = 'todas';
    variedadSeleccionada = 'todas';
    searchKey = '';
    currentPage = 1;
    openMenu = null;
    _ga4ListadoTracked = false;
    _onPointerDown;

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
        this._onPointerDown = (event) => {
            const path = typeof event.composedPath === 'function' ? event.composedPath() : [];
            if (path.includes(this.template.host)) return;
            this.openMenu = null;
        };
        window.addEventListener('pointerdown', this._onPointerDown);
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
        window.removeEventListener('pointerdown', this._onPointerDown);
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
            if (!this._ga4ListadoTracked) {
                this._ga4ListadoTracked = true;
                trackGa4Event('ht_listado_vista', { portal: 'Productor' });
            }
        } else if (error) {
            console.error('Error al cargar compras:', error);
        }
    }

    handlePill(event) {
        this.estadoSeleccionado = event.currentTarget.dataset.filter;
        this.applyFilters();
    }

    get cultivoOpen() {
        return this.openMenu === 'cultivo';
    }

    get variedadOpen() {
        return this.openMenu === 'variedad';
    }

    get cultivoTriggerLabel() {
        return this.cultivoSeleccionado === 'todas' ? 'Todos los cultivos' : this.cultivoSeleccionado;
    }

    get variedadTriggerLabel() {
        return this.variedadSeleccionada === 'todas' ? 'Todas las variedades' : this.variedadSeleccionada;
    }

    get cultivoTriggerClass() {
        return this.openMenu === 'cultivo' ? 'dd-trigger is-open' : 'dd-trigger';
    }

    get variedadTriggerClass() {
        return this.openMenu === 'variedad' ? 'dd-trigger is-open' : 'dd-trigger';
    }

    toggleCultivo(event) {
        event.stopPropagation();
        this.openMenu = this.openMenu === 'cultivo' ? null : 'cultivo';
    }

    toggleVariedad(event) {
        event.stopPropagation();
        this.openMenu = this.openMenu === 'variedad' ? null : 'variedad';
    }

    handleCultivo(event) {
        this.cultivoSeleccionado = event.currentTarget.dataset.filter;
        this.openMenu = null;
        this.applyFilters();
    }

    handleVariedad(event) {
        this.variedadSeleccionada = event.currentTarget.dataset.filter;
        this.openMenu = null;
        this.applyFilters();
    }

    handleSearchChange(event) {
        this.searchKey = (event.target.value || '').toLowerCase();
        this.applyFilters();
    }

    applyFilters() {
        const counts = {};
        this.comprasAll.forEach((row) => {
            counts[row.estado] = (counts[row.estado] || 0) + 1;
        });

        const statuses = Object.keys(counts).sort((a, b) => {
            const ia = STATUS_ORDER.indexOf(a);
            const ib = STATUS_ORDER.indexOf(b);
            if (ia === -1 && ib === -1) return a.localeCompare(b);
            if (ia === -1) return 1;
            if (ib === -1) return -1;
            return ia - ib;
        });

        this.statusPills = [
            {
                id: 'todas',
                label: 'Todas',
                count: this.comprasAll.length,
                className: this.estadoSeleccionado === 'todas' ? 'pill is-active' : 'pill'
            },
            ...statuses.map((estado) => ({
                id: estado,
                label: estado,
                count: counts[estado],
                className: this.estadoSeleccionado === estado ? 'pill is-active' : 'pill'
            }))
        ];

        const cultivoCounts = {};
        const variedadCounts = {};
        this.comprasAll.forEach((row) => {
            cultivoCounts[row.cultivo] = (cultivoCounts[row.cultivo] || 0) + 1;
            row.varietyList.forEach((variedad) => {
                variedadCounts[variedad] = (variedadCounts[variedad] || 0) + 1;
            });
        });

        this.cultivoPills = [
            {
                id: 'todas',
                label: 'Todos los cultivos',
                itemClass: this.cultivoSeleccionado === 'todas' ? 'dd-item is-active' : 'dd-item'
            },
            ...Object.keys(cultivoCounts)
                .sort((a, b) => a.localeCompare(b, 'es'))
                .map((cultivo) => ({
                    id: cultivo,
                    label: cultivo,
                    itemClass: this.cultivoSeleccionado === cultivo ? 'dd-item is-active' : 'dd-item'
                }))
        ];

        this.variedadPills = [
            {
                id: 'todas',
                label: 'Todas las variedades',
                itemClass: this.variedadSeleccionada === 'todas' ? 'dd-item is-active' : 'dd-item'
            },
            ...Object.keys(variedadCounts)
                .sort((a, b) => a.localeCompare(b, 'es'))
                .map((variedad) => ({
                    id: variedad,
                    label: variedad,
                    itemClass: this.variedadSeleccionada === variedad ? 'dd-item is-active' : 'dd-item'
                }))
        ];

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
        if (this.searchKey) {
            rows = rows.filter(
                (row) =>
                    (row.name && row.name.toLowerCase().includes(this.searchKey)) ||
                    (row.productor && row.productor.toLowerCase().includes(this.searchKey))
            );
        }
        this.filtered = rows;
        this.currentPage = 1;
        this.paginar();
    }

    get showPager() {
        return this.filtered.length > 0;
    }

    get pageLabel() {
        return `Página ${this.currentPage}`;
    }

    get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage * PAGE_SIZE >= this.filtered.length;
    }

    paginar() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        this.data = this.filtered.slice(start, start + PAGE_SIZE);
    }

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
            this.paginar();
        }
    }

    handleNext() {
        if (this.currentPage * PAGE_SIZE < this.filtered.length) {
            this.currentPage += 1;
            this.paginar();
        }
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
