import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCesiones from '@salesforce/apex/misCesionesController.getCesiones';
import { doRequest } from 'c/utils';
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

function statusTone(estado) {
    const s = (estado || '').toLowerCase();
    if (/valid|finaliz|confirm/.test(s)) return 'ok';
    if (/anul|cancel|rechaz/.test(s)) return 'danger';
    if (/pendiente|curso|borrador/.test(s)) return 'warn';
    return 'info';
}

const STATUS_ORDER = [
    'En Curso',
    'Pendiente de Validación',
    'Validada',
    'Finalizada',
    'Anulada',
    'Borrador'
];
const PAGE_SIZE = 200;

export default class MisCesiones extends NavigationMixin(LightningElement) {
    /** Legacy Experience Builder property (Productor/Comercio); unused in Productor redesign. */
    @api type;
    @track rowsAll = [];
    @track filtered = [];
    @track statusPills = [];
    @track cultivoOptions = [];
    @track tipoOptions = [];
    @track loading = true;
    @track showNewSheet = false;

    pageSize = PAGE_SIZE;
    estadoSeleccionado = 'todas';
    cultivoSeleccionado = 'todas';
    tipoSeleccionado = 'todas';
    searchKey = '';
    _ga4Tracked = false;

    columns = [
        { label: 'Fecha', fieldName: 'fechaLabel' },
        { label: 'Cesión', fieldName: 'name', type: 'link' },
        { label: 'Cedente', fieldName: 'cedente' },
        { label: 'Cultivo', fieldName: 'cultivo' },
        { label: 'Tipo', fieldName: 'tipo' },
        { label: 'Estado', fieldName: 'statusLabel', type: 'badge', toneField: 'statusTone' },
        { label: 'Variedades', fieldName: 'variedades' },
        { label: '', fieldName: 'action', type: 'action', actionLabel: 'Ver' }
    ];

    mobileFields = [
        { label: 'Fecha', fieldName: 'fechaLabel' },
        { label: 'Cultivo', fieldName: 'cultivo' },
        { label: 'Cedente', fieldName: 'cedente' },
        { label: 'Tipo', fieldName: 'tipo' },
        { label: 'Variedades', fieldName: 'variedades' }
    ];

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
        this.load();
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
    }

    async load() {
        await doRequest.call(this, async () => {
            const data = await getCesiones();
            this.rowsAll = await Promise.all(
                data.map(async (row) => {
                    const safeName = row.Name
                        ? row.Name.toLowerCase().trim().replace(/\s+/g, '').replace(/[^a-z0-9\-]/g, '')
                        : '';
                    const pageRef = {
                        type: 'comm__namedPage',
                        attributes: { name: 'Cesion_HT_Detail__c' },
                        state: { recordId: row.Id, recordName: safeName }
                    };
                    const url = await this[NavigationMixin.GenerateUrl](pageRef);
                    const estado = row.Estado__c || 'Sin estado';
                    return {
                        id: row.Id,
                        name: row.Name,
                        url,
                        fechaLabel: formatDate(row.CreatedDate),
                        cedente: row.Cuenta_Cedente__r?.Name || '',
                        cultivo: row.Cultivo__r?.Name || '',
                        tipo: row.Tipo_de_Cesion__c || '',
                        variedades: row.Variedades__c || '',
                        estado,
                        statusLabel: estado,
                        statusTone: statusTone(estado)
                    };
                })
            );
            this.applyFilters();
            this.loading = false;
            if (!this._ga4Tracked) {
                this._ga4Tracked = true;
                trackGa4Event('cesion_vista', { portal: 'Productor' });
            }
        });
    }

    handlePill(event) {
        this.estadoSeleccionado = event.detail.id;
        this.applyFilters();
    }

    handleCultivo(event) {
        this.cultivoSeleccionado = event.detail.value;
        this.applyFilters();
    }

    handleTipo(event) {
        this.tipoSeleccionado = event.detail.value;
        this.applyFilters();
    }

    handleSearchChange(event) {
        this.searchKey = (event.detail.value || '').toLowerCase();
        this.applyFilters();
    }

    applyFilters() {
        const counts = {};
        this.rowsAll.forEach((row) => {
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

        this.statusPills = [
            {
                id: 'todas',
                label: 'Todas',
                count: this.rowsAll.length,
                selected: this.estadoSeleccionado === 'todas'
            },
            ...statuses.map((estado) => ({
                id: estado,
                label: estado,
                count: counts[estado],
                selected: this.estadoSeleccionado === estado
            }))
        ];

        const cultivoCounts = {};
        const tipoCounts = {};
        this.rowsAll.forEach((row) => {
            if (row.cultivo) cultivoCounts[row.cultivo] = (cultivoCounts[row.cultivo] || 0) + 1;
            if (row.tipo) tipoCounts[row.tipo] = (tipoCounts[row.tipo] || 0) + 1;
        });

        this.cultivoOptions = [
            { value: 'todas', label: 'Todos los cultivos' },
            ...Object.keys(cultivoCounts)
                .sort((a, b) => a.localeCompare(b, 'es'))
                .map((c) => ({ value: c, label: c }))
        ];

        this.tipoOptions = [
            { value: 'todas', label: 'Todos los tipos' },
            ...Object.keys(tipoCounts)
                .sort((a, b) => a.localeCompare(b, 'es'))
                .map((t) => ({ value: t, label: t }))
        ];

        let rows = [...this.rowsAll];
        if (this.estadoSeleccionado !== 'todas') {
            rows = rows.filter((r) => r.estado === this.estadoSeleccionado);
        }
        if (this.cultivoSeleccionado !== 'todas') {
            rows = rows.filter((r) => r.cultivo === this.cultivoSeleccionado);
        }
        if (this.tipoSeleccionado !== 'todas') {
            rows = rows.filter((r) => r.tipo === this.tipoSeleccionado);
        }
        if (this.searchKey) {
            rows = rows.filter(
                (r) =>
                    (r.name && r.name.toLowerCase().includes(this.searchKey)) ||
                    (r.cedente && r.cedente.toLowerCase().includes(this.searchKey)) ||
                    (r.variedades && r.variedades.toLowerCase().includes(this.searchKey))
            );
        }
        this.filtered = rows;
    }

    handleRowAction(event) {
        const row = event.detail.row;
        if (row?.url) {
            window.open(row.url, '_self');
        }
    }

    openNewSheet() {
        this.showNewSheet = true;
    }

    closeNewSheet() {
        this.showNewSheet = false;
    }

    handleNewCesion(event) {
        const tipo = event.currentTarget.dataset.type;
        if (!tipo) return;
        this.showNewSheet = false;
        trackGa4Event('cesion_iniciada', { tipo });
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { pageName: 'cesion-pph' },
            state: { recordId: 'new', type: tipo }
        });
    }

    get newSheetClass() {
        return 'se-new-sheet-wrap' + (this.showNewSheet ? ' is-open' : '');
    }
}
