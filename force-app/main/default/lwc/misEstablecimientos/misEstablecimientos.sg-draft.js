import { LightningElement, api, track } from 'lwc';
import getEstablecimientos from '@salesforce/apex/misEstablecimientosController.getEstablecimientos';
import { doRequest } from 'c/utils';

const PAGE_SIZE = 200;

function formatCoord(lat, lng) {
    if (lat == null || lng == null) return 'Sin georeferencia';
    return `${Number(lat).toFixed(2)}┬░, ${Number(lng).toFixed(2)}┬░`;
}

function statusTone(vigente) {
    return vigente === true ? 'ok' : 'info';
}

export default class MisEstablecimientos extends LightningElement {
    @api type;
    @track rowsAll = [];
    @track filtered = [];

    loading = true;
    initialized = false;
    searchKey = '';
    pageSize = PAGE_SIZE;

    columns = [
        { label: 'Nombre', fieldName: 'title', type: 'link' },
        { label: 'Coordenadas', fieldName: 'coordenadas' },
        { label: 'Estado', fieldName: 'statusLabel', type: 'badge', toneField: 'statusTone' },
        { label: '', fieldName: 'action', type: 'action', actionLabel: 'Ver detalle' }
    ];

    mobileFields = [
        { label: 'Coordenadas', fieldName: 'coordenadas' },
        { label: 'Estado', fieldName: 'statusLabel' }
    ];

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
    }

    renderedCallback() {
        if (!this.initialized) {
            this.init();
        }
    }

    async init() {
        this.initialized = true;
        await this.loadRows();
    }

    async loadRows() {
        await doRequest.call(this, async () => {
            const data = await getEstablecimientos();
            this.rowsAll = (data || []).map((row) => this.decorateRow(row));
            this.applyFilters();
            this.loading = false;
        });
    }

    decorateRow(row) {
        const vigente = row.Vigente__c !== false;
        return {
            id: row.Id,
            title: row.Name,
            coordenadas: formatCoord(row.Coordenadas__Latitude__s, row.Coordenadas__Longitude__s),
            statusLabel: vigente ? 'Activo' : 'Inactivo',
            statusTone: statusTone(vigente),
            detailUrl: `/establecimiento/${row.Id}/${encodeURIComponent(row.Name || '')}`
        };
    }

    applyFilters() {
        const term = (this.searchKey || '').trim().toLowerCase();
        if (!term) {
            this.filtered = [...this.rowsAll];
            return;
        }
        this.filtered = this.rowsAll.filter((row) => {
            return (
                (row.title && row.title.toLowerCase().includes(term)) ||
                (row.coordenadas && row.coordenadas.toLowerCase().includes(term))
            );
        });
    }

    get listMetaLabel() {
        const count = this.filtered.length;
        return `${count} establecimiento${count === 1 ? '' : 's'} ┬À Ordenado por Nombre`;
    }

    get showFooterSummary() {
        return this.filtered.length > 0;
    }

    get footerSummaryLabel() {
        const withCoords = this.filtered.filter((r) => r.coordenadas !== 'Sin georeferencia').length;
        return `${withCoords} de ${this.filtered.length} con georeferencia declarada`;
    }

    handleSearchChange(event) {
        this.searchKey = event.detail?.value ?? event.detail ?? '';
        this.applyFilters();
    }

    handleRowAction(event) {
        const row = event.detail?.row;
        if (!row?.detailUrl) return;
        window.open(row.detailUrl, '_self');
    }

    handleNewEstablecimiento() {
        this.template.querySelector('c-establecimientos-map')?.openNew?.();
    }

    handleOpenMapa() {
        this.template.querySelector('c-establecimientos-map')?.openMap?.();
    }

    handleEstablecimientoSaved() {
        this.loading = true;
        this.loadRows();
    }
}
