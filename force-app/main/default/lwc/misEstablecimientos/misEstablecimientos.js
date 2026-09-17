import { LightningElement, api, track } from 'lwc';
import getEstablecimientos from '@salesforce/apex/misEstablecimientosController.getEstablecimientos';
import { doRequest } from 'c/utils';

const PAGE_SIZE = 200;

function formatHa(value) {
    if (value == null || value === '') return '—';
    const n = Number(value);
    if (Number.isNaN(n)) return '—';
    return `${new Intl.NumberFormat('es-AR', { maximumFractionDigits: 2 }).format(n)} ha`;
}

function formatCoord(value) {
    if (value == null || value === '') return '—';
    const n = Number(value);
    if (Number.isNaN(n)) return '—';
    return `${n.toFixed(6)}°`;
}

function cultivoLabel(value) {
    if (!value) return '—';
    if (Array.isArray(value)) return value.filter(Boolean).join(' · ') || '—';
    return String(value).replace(/;/g, ' · ').replace(/\s*-\s*/g, ' · ');
}

export default class MisEstablecimientos extends LightningElement {
    @api type;
    @track rowsAll = [];
    @track filtered = [];

    loading = true;
    initialized = false;
    searchKey = '';
    statusFilter = 'todos';
    cultivoFilter = 'todos';
    pageSize = PAGE_SIZE;

    columns = [
        { label: 'Nombre', fieldName: 'title', type: 'link' },
        { label: 'Origen', fieldName: 'origen' },
        { label: 'Localidad', fieldName: 'localidad' },
        { label: 'Provincia', fieldName: 'provincia' },
        { label: 'Latitud', fieldName: 'latLabel' },
        { label: 'Longitud', fieldName: 'lngLabel' },
        { label: 'Superficie', fieldName: 'superficieLabel' },
        { label: 'Superficie sin sembrar', fieldName: 'superficieSinSembrarLabel' },
        { label: 'Cultivos declarados', fieldName: 'cultivo' },
        { label: 'PPH', fieldName: 'pphLabel' },
        { label: 'Estado', fieldName: 'statusLabel', type: 'badge', toneField: 'statusTone' },
        { label: '', fieldName: 'action', type: 'action', actionLabel: 'Ver detalle' }
    ];

    mobileFields = [
        { label: 'Origen', fieldName: 'origen' },
        { label: 'Localidad', fieldName: 'localidad' },
        { label: 'Provincia', fieldName: 'provincia' },
        { label: 'Latitud', fieldName: 'latLabel' },
        { label: 'Longitud', fieldName: 'lngLabel' },
        { label: 'Superficie', fieldName: 'superficieLabel' },
        { label: 'Sin sembrar', fieldName: 'superficieSinSembrarLabel' },
        { label: 'Cultivos', fieldName: 'cultivo' },
        { label: 'PPH', fieldName: 'pphLabel' }
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
        const hasHt = row.hasHt === true;
        const adheridoPph = row.adheridoPph === true;
        return {
            id: row.id,
            title: row.name,
            origen: row.origen || '—',
            localidad: row.localidad || '—',
            provincia: row.provincia || '—',
            cultivo: cultivoLabel(row.cultivo),
            cultivoKey: (row.cultivo || '').trim().toLowerCase() || '—',
            latLabel: formatCoord(row.lat),
            lngLabel: formatCoord(row.lng),
            superficie: row.superficie,
            superficieSinSembrar: row.superficieSinSembrar,
            superficieLabel: formatHa(row.superficie),
            superficieSinSembrarLabel: formatHa(row.superficieSinSembrar),
            hasHt,
            adheridoPph,
            vigente: row.vigente !== false,
            pphLabel: adheridoPph ? 'Adherido' : '—',
            statusLabel: hasHt ? 'Activo' : 'Sin HT',
            statusTone: hasHt ? 'ok' : 'info'
        };
    }

    get estadoSelectOptions() {
        return [
            { value: 'todos', label: 'Todos los estados' },
            { value: 'conHt', label: 'Activo' },
            { value: 'sinHt', label: 'Sin HT' }
        ];
    }

    get cultivoSelectOptions() {
        const set = new Set();
        (this.rowsAll || []).forEach((row) => {
            if (row.cultivo && row.cultivo !== '—') {
                row.cultivo.split(' · ').forEach((c) => {
                    const t = c.trim();
                    if (t) set.add(t);
                });
            }
        });
        const options = [{ value: 'todos', label: 'Todos los cultivos' }];
        [...set].sort((a, b) => a.localeCompare(b, 'es')).forEach((c) => {
            options.push({ value: c.toLowerCase(), label: c });
        });
        return options;
    }

    applyFilters() {
        const term = (this.searchKey || '').trim().toLowerCase();
        let rows = [...(this.rowsAll || [])];

        if (this.statusFilter === 'conHt') {
            rows = rows.filter((r) => r.hasHt);
        } else if (this.statusFilter === 'sinHt') {
            rows = rows.filter((r) => !r.hasHt);
        }

        if (this.cultivoFilter && this.cultivoFilter !== 'todos') {
            const key = this.cultivoFilter.toLowerCase();
            rows = rows.filter((r) => (r.cultivo || '').toLowerCase().includes(key));
        }

        if (term) {
            rows = rows.filter((row) => {
                return (
                    (row.title && row.title.toLowerCase().includes(term)) ||
                    (row.origen && row.origen.toLowerCase().includes(term)) ||
                    (row.localidad && row.localidad.toLowerCase().includes(term)) ||
                    (row.provincia && row.provincia.toLowerCase().includes(term)) ||
                    (row.cultivo && row.cultivo.toLowerCase().includes(term)) ||
                    (row.pphLabel && row.pphLabel.toLowerCase().includes(term)) ||
                    (row.statusLabel && row.statusLabel.toLowerCase().includes(term)) ||
                    (row.superficieLabel && row.superficieLabel.toLowerCase().includes(term))
                );
            });
        }

        this.filtered = rows;
    }

    get listMetaLabel() {
        const count = this.filtered.length;
        return `${count} establecimiento${count === 1 ? '' : 's'} · Ordenado por Nombre`;
    }

    get showFooterSummary() {
        return this.filtered.length > 0;
    }

    get footerSummaryLabel() {
        const totalHa = this.filtered.reduce((sum, r) => sum + (Number(r.superficie) || 0), 0);
        const adheridos = this.filtered.filter((r) => r.adheridoPph).length;
        const haLabel = formatHa(totalHa);
        return `${haLabel} totales declaradas · ${adheridos} de ${this.filtered.length} establecimientos adheridos a PPH`;
    }

    handleEstadoChange(event) {
        this.statusFilter = event.detail?.value || 'todos';
        this.applyFilters();
    }

    handleCultivoChange(event) {
        this.cultivoFilter = event.detail?.value || 'todos';
        this.applyFilters();
    }

    handleSearchChange(event) {
        this.searchKey = event.target?.value ?? event.detail?.value ?? event.detail ?? '';
        this.applyFilters();
    }

    handleRowAction(event) {
        const row = event.detail?.row;
        if (!row?.id) return;
        this.goToEstablecimiento(row.id, row.title);
    }

    getCommunityBasePath() {
        const pathname = window.location.pathname || '';
        if (pathname.includes('/SembraEvolucion/s')) {
            return '/SembraEvolucion/s';
        }
        if (pathname.includes('/Productores/s')) {
            return '/Productores/s';
        }
        if (pathname.includes('/RegaliaProductor/s')) {
            return '/RegaliaProductor/s';
        }
        if (pathname.includes('/s')) {
            return `${pathname.split('/s')[0]}/s`;
        }
        return '/s';
    }

    goToEstablecimiento(recordId, recordName) {
        const basePath = this.getCommunityBasePath();
        const slug = encodeURIComponent(recordName || 'detalle');
        window.open(`${basePath}/establecimiento/${recordId}/${slug}`, '_self');
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
