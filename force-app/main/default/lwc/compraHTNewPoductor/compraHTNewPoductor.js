import { LightningElement, track } from 'lwc';
import getLoadData from '@salesforce/apex/CuentaGranaria.getLoadData';
import getHectareasTecnologicas from '@salesforce/apex/ComprasHTController.getHectareasTecnologicas';
import { fetchCultivoSummary } from 'c/cultivoResumenService';
import { reduceErrors } from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import { syncPortalModal, releasePortalModal } from 'c/seModalLayer';

const NONE_KEY = '__none__';

function pad(n) {
    return String(n).padStart(2, '0');
}

function formatDate(value) {
    if (!value) return '—';
    const dt = new Date(value);
    if (Number.isNaN(dt.getTime())) return String(value);
    return `${pad(dt.getDate())}/${pad(dt.getMonth() + 1)}/${dt.getFullYear()}`;
}

function formatAmount(value) {
    if (value == null || value === '' || value === 0) {
        return '—';
    }
    const num = Number(value);
    if (Number.isNaN(num)) {
        return String(value);
    }
    const prefix = num > 0 ? '+' : '';
    return `${prefix}${num.toLocaleString('es-AR', { maximumFractionDigits: 0 })}`;
}

function origenTone(origen) {
    const o = (origen || '').toLowerCase();
    if (/compra|cesi[oó]n/.test(o)) return 'ok';
    if (/entrega|consumo|aplicad/.test(o)) return 'warn';
    return 'info';
}

function uniqueFromRows(rows, valueKey, labelKey, emptyLabel) {
    const map = new Map();
    (rows || []).forEach((row) => {
        const raw = row[valueKey];
        const isEmpty = raw == null || raw === '' || raw === NONE_KEY;
        const value = isEmpty ? NONE_KEY : String(raw);
        const label = isEmpty ? emptyLabel : row[labelKey] || String(raw);
        if (!map.has(value)) {
            map.set(value, label);
        }
    });
    return [...map.entries()]
        .map(([value, label]) => ({ value, label }))
        .sort((a, b) => a.label.localeCompare(b.label, 'es'));
}

function toggleInList(list, value) {
    const next = new Set(list || []);
    if (next.has(value)) {
        next.delete(value);
    } else {
        next.add(value);
    }
    return [...next];
}

function withChecked(options, selected) {
    const selectedSet = new Set(selected || []);
    return (options || []).map((opt) => ({
        ...opt,
        checked: selectedSet.has(opt.value),
        ariaChecked: selectedSet.has(opt.value) ? 'true' : 'false',
        boxClass: 'filt-check' + (selectedSet.has(opt.value) ? ' filt-check-on' : '')
    }));
}

export default class CompraHTNewProductor extends NavigationMixin(LightningElement) {
    initialized = false;
    processing = true;

    @track hectareasTecnologicas = [];
    @track cultivos;
    @track summaryCultivoId;
    @track summaryTotal = 0;
    @track summaryRows = [];
    @track summaryLoading = false;
    @track listLoading = false;
    @track filteredRows = [];

    @track searchTerm = '';
    @track filtersPanelOpen = false;
    @track filtersSheetOpen = false;

    @track filterCultivoIds = [];
    @track filterCampanias = [];
    @track filterBiotecnologias = [];
    @track filterOrigenes = [];

    @track draftCultivoIds = [];
    @track draftCampanias = [];
    @track draftBiotecnologias = [];
    @track draftOrigenes = [];

    @track campaniaOptions = [];
    @track biotecnologiaOptions = [];
    @track origenOptions = [];

    listPageSize = 10;
    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    columns = [
        { label: 'Cultivo', fieldName: 'cultivo', type: 'strong' },
        { label: 'Biotecnología', fieldName: 'biotecnologia' },
        { label: 'Campaña', fieldName: 'campaniaDisplay' },
        { label: 'Fecha Transacción', fieldName: 'fechaLabel' },
        { label: 'Débito', fieldName: 'debitoDisplay', type: 'amount' },
        { label: 'Crédito', fieldName: 'creditoDisplay', type: 'amount' },
        { label: 'Origen', fieldName: 'origen', type: 'accent' }
    ];

    mobileFields = [
        { label: 'Biotecnología', fieldName: 'biotecnologia' },
        { label: 'Campaña', fieldName: 'campaniaDisplay' },
        { label: 'Fecha', fieldName: 'fechaLabel' },
        { label: 'Débito', fieldName: 'debitoDisplay', valueClassField: 'debitoValueClass' },
        { label: 'Crédito', fieldName: 'creditoDisplay', valueClassField: 'creditoValueClass' }
    ];

    get pageLoading() {
        return this.processing || this.listLoading;
    }

    get filterToggleChevronClass() {
        return 'filt-chevron' + (this.filtersPanelOpen ? ' filt-chevron-open' : '');
    }

    get activeFilterCount() {
        let count = 0;
        const tabIds = this.tabCultivoIds();
        const sameAsTab =
            this.filterCultivoIds.length === tabIds.length &&
            tabIds.every((id) => this.filterCultivoIds.includes(id));
        if (this.cultivos?.length && !sameAsTab) count++;
        if (this.campaniaOptions.length && this.filterCampanias.length < this.campaniaOptions.length) count++;
        if (this.biotecnologiaOptions.length && this.filterBiotecnologias.length < this.biotecnologiaOptions.length) count++;
        if (this.origenOptions.length && this.filterOrigenes.length < this.origenOptions.length) count++;
        return count;
    }

    get showFilterBadge() {
        return this.activeFilterCount > 0;
    }

    get cultivoFilterItems() {
        return withChecked(
            (this.cultivos || []).map((c) => ({ value: c.value, label: c.label })),
            this.filtersSheetOpen ? this.draftCultivoIds : this.filterCultivoIds
        );
    }

    get campaniaFilterItems() {
        return withChecked(
            this.campaniaOptions,
            this.filtersSheetOpen ? this.draftCampanias : this.filterCampanias
        );
    }

    get biotecnologiaFilterItems() {
        return withChecked(
            this.biotecnologiaOptions,
            this.filtersSheetOpen ? this.draftBiotecnologias : this.filterBiotecnologias
        );
    }

    get origenFilterItems() {
        return withChecked(
            this.origenOptions,
            this.filtersSheetOpen ? this.draftOrigenes : this.filterOrigenes
        );
    }

    get singleCampaniaHint() {
        return this.campaniaOptions.length === 1;
    }

    get singleCampaniaLabel() {
        return this.campaniaOptions.length === 1 ? this.campaniaOptions[0].label : '';
    }

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
    }

    disconnectedCallback() {
        releasePortalModal(this);
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
    }

    async loadSummary() {
        if (!this.summaryCultivoId) {
            this.summaryRows = [];
            this.summaryTotal = 0;
            return;
        }

        const cultivoId = this.summaryCultivoId;
        this.summaryLoading = true;
        try {
            const summary = await fetchCultivoSummary(cultivoId);
            if (cultivoId !== this.summaryCultivoId) return;
            this.summaryRows = summary.rows;
            this.summaryTotal = summary.total;
        } catch (e) {
            if (cultivoId !== this.summaryCultivoId) return;
            this.summaryRows = [];
            this.summaryTotal = 0;
            this.onError(e);
        } finally {
            if (cultivoId === this.summaryCultivoId) this.summaryLoading = false;
        }
    }

    tabCultivoIds() {
        if (this.summaryCultivoId) return [this.summaryCultivoId];
        return (this.cultivos || []).map((c) => c.value);
    }

    /** El filtro de cultivo es de selección única y siempre igual a la tab activa. */
    selectCultivo(value) {
        if (value && value !== this.summaryCultivoId) {
            this.summaryCultivoId = value;
            this.loadSummary();
        }
        this.filterCultivoIds = this.tabCultivoIds();
        this.draftCultivoIds = [...this.filterCultivoIds];
    }

    handleCultivoResumenSelect(event) {
        this.selectCultivo(event.detail?.value);
        this.applyFilters();
    }

    get paramCultivo() {
        return new URL(window.location.href).searchParams.get('cultivoId');
    }

    async init() {
        this.initialized = true;
        try {
            const data = await getLoadData();
            this.cultivos = (data.cultivos || []).map((c) => ({ label: c.Name, value: c.Id }));

            if (this.paramCultivo) {
                this.summaryCultivoId = this.paramCultivo;
            } else if (this.cultivos.length) {
                this.summaryCultivoId = this.cultivos[0].value;
            }

            if (this.cultivos.length) {
                await Promise.all([this.loadAllMovimientos(), this.loadSummary()]);
            }
        } catch (e) {
            this.onError(e);
        }
        this.processing = false;
    }

    renderedCallback() {
        if (!this.initialized) {
            this.init();
        }
        syncPortalModal(this, this.filtersSheetOpen, '.filt-sheet-wrap');
    }

    decorateRow(row, index) {
        const hasDebito = row.debito != null && row.debito !== '' && Number(row.debito) !== 0;
        const hasCredito = row.credito != null && row.credito !== '' && Number(row.credito) !== 0;

        return {
            ...row,
            id: row.id || `row-${index}`,
            campaniaKey: row.campaniaAno || NONE_KEY,
            campaniaDisplay: row.campaniaPeriodo || '—',
            biotecnologiaKey: row.biotecnologia ? row.biotecnologia : NONE_KEY,
            origenKey: row.origen ? row.origen : NONE_KEY,
            fechaLabel: formatDate(row.fechaTransaccion),
            debitoDisplay: formatAmount(row.debito),
            creditoDisplay: formatAmount(row.credito),
            debitoValueClass: hasDebito ? 'amount' : '',
            creditoValueClass: hasCredito ? 'amount' : '',
            origenTone: origenTone(row.origen)
        };
    }

    initFilterOptions() {
        const rows = this.hectareasTecnologicas;

        this.campaniaOptions = uniqueFromRows(rows, 'campaniaKey', 'campaniaPeriodo', 'Sin campaña').sort((a, b) => {
            if (a.value === NONE_KEY) return 1;
            if (b.value === NONE_KEY) return -1;
            return b.value.localeCompare(a.value);
        });
        this.biotecnologiaOptions = uniqueFromRows(rows, 'biotecnologiaKey', 'biotecnologia', 'Sin biotecnología');
        this.origenOptions = uniqueFromRows(rows, 'origenKey', 'origen', 'Sin origen');

        this.filterCultivoIds = this.tabCultivoIds();
        this.filterCampanias = this.campaniaOptions.map((o) => o.value);
        this.filterBiotecnologias = this.biotecnologiaOptions.map((o) => o.value);
        this.filterOrigenes = this.origenOptions.map((o) => o.value);
    }

    async loadAllMovimientos() {
        if (!this.cultivos?.length) {
            return;
        }

        this.listLoading = true;
        try {
            const batches = await Promise.all(
                this.cultivos.map((c) => getHectareasTecnologicas({ cultivoId: c.value }))
            );
            const merged = batches.flat();

            merged.sort((a, b) => {
                const da = a.fechaTransaccion ? new Date(a.fechaTransaccion).getTime() : 0;
                const db = b.fechaTransaccion ? new Date(b.fechaTransaccion).getTime() : 0;
                return db - da;
            });

            this.hectareasTecnologicas = merged.map((row, index) => this.decorateRow(row, index));
            this.initFilterOptions();
            this.applyFilters();
        } catch (e) {
            this.onError(e);
        }
        this.listLoading = false;
    }

    handleSearchChange(event) {
        this.searchTerm = (event.detail?.value ?? event.target?.value ?? '').toLowerCase();
        this.applyFilters();
    }

    handleToggleFiltersPanel() {
        this.filtersPanelOpen = !this.filtersPanelOpen;
    }

    handleCloseFiltersPanel() {
        this.filtersPanelOpen = false;
    }

    handleOpenFiltersSheet() {
        this.draftCultivoIds = [...this.filterCultivoIds];
        this.draftCampanias = [...this.filterCampanias];
        this.draftBiotecnologias = [...this.filterBiotecnologias];
        this.draftOrigenes = [...this.filterOrigenes];
        this.filtersSheetOpen = true;
    }

    handleCloseFiltersSheet() {
        this.filtersSheetOpen = false;
    }

    handleClearFilters() {
        this.filterCultivoIds = this.tabCultivoIds();
        this.filterCampanias = this.campaniaOptions.map((o) => o.value);
        this.filterBiotecnologias = this.biotecnologiaOptions.map((o) => o.value);
        this.filterOrigenes = this.origenOptions.map((o) => o.value);
        this.draftCultivoIds = [...this.filterCultivoIds];
        this.draftCampanias = [...this.filterCampanias];
        this.draftBiotecnologias = [...this.filterBiotecnologias];
        this.draftOrigenes = [...this.filterOrigenes];
        this.applyFilters();
    }

    handleApplyFiltersSheet() {
        this.selectCultivo(this.draftCultivoIds[0]);
        this.filterCampanias = [...this.draftCampanias];
        this.filterBiotecnologias = [...this.draftBiotecnologias];
        this.filterOrigenes = [...this.draftOrigenes];
        this.filtersSheetOpen = false;
        this.applyFilters();
    }

    handleFilterToggle(event) {
        const group = event.currentTarget.dataset.group;
        const value = event.currentTarget.dataset.value;
        const isMobile = event.currentTarget.dataset.mobile === 'true';

        if (isMobile) {
            if (group === 'cultivo') this.draftCultivoIds = [value];
            if (group === 'campania') this.draftCampanias = toggleInList(this.draftCampanias, value);
            if (group === 'biotecnologia') this.draftBiotecnologias = toggleInList(this.draftBiotecnologias, value);
            if (group === 'origen') this.draftOrigenes = toggleInList(this.draftOrigenes, value);
            return;
        }

        if (group === 'cultivo') this.selectCultivo(value);
        if (group === 'campania') this.filterCampanias = toggleInList(this.filterCampanias, value);
        if (group === 'biotecnologia') this.filterBiotecnologias = toggleInList(this.filterBiotecnologias, value);
        if (group === 'origen') this.filterOrigenes = toggleInList(this.filterOrigenes, value);
        this.applyFilters();
    }

    applyFilters() {
        const cultivoSet = new Set(this.filterCultivoIds);
        const campaniaSet = new Set(this.filterCampanias);
        const bioSet = new Set(this.filterBiotecnologias);
        const origenSet = new Set(this.filterOrigenes);
        const cultivoCount = this.cultivos?.length || 0;

        let filtered = [...this.hectareasTecnologicas];

        if (cultivoCount && cultivoSet.size < cultivoCount) {
            filtered = filtered.filter((row) => cultivoSet.has(row.cultivoId));
        }

        if (this.campaniaOptions.length && campaniaSet.size < this.campaniaOptions.length) {
            filtered = filtered.filter((row) => campaniaSet.has(row.campaniaKey));
        }
        if (this.biotecnologiaOptions.length && bioSet.size < this.biotecnologiaOptions.length) {
            filtered = filtered.filter((row) => bioSet.has(row.biotecnologiaKey));
        }
        if (this.origenOptions.length && origenSet.size < this.origenOptions.length) {
            filtered = filtered.filter((row) => origenSet.has(row.origenKey));
        }

        if (this.searchTerm) {
            filtered = filtered.filter(
                (row) =>
                    (row.cultivo && row.cultivo.toLowerCase().includes(this.searchTerm)) ||
                    (row.biotecnologia && row.biotecnologia.toLowerCase().includes(this.searchTerm)) ||
                    (row.campaniaPeriodo && row.campaniaPeriodo.includes(this.searchTerm)) ||
                    (row.comercio && row.comercio.toLowerCase().includes(this.searchTerm)) ||
                    (row.origen && row.origen.toLowerCase().includes(this.searchTerm))
            );
        }

        this.filteredRows = filtered;
    }

    onError(e) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: reduceErrors(e).join('\n'),
                variant: 'error',
                mode: 'sticky'
            })
        );
    }
}
