import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEstablecimientos from '@salesforce/apex/misEstablecimientosController.getEstablecimientos';
import updateEstablecimiento from '@salesforce/apex/misEstablecimientosController.updateEstablecimiento';
import { doRequest, errorEvent, reduceErrors } from 'c/utils';
import { syncPortalModal, releasePortalModal } from 'c/seModalLayer';
import { latitudError, longitudError } from 'c/seGeo';

const PAGE_SIZE = 10;
const DETAIL_PARAM = 'establecimiento';
const REQUIRED_MSG = 'Este campo es obligatorio';

function toNumber(value) {
    if (value == null || value === '') return null;
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
}

function parseCoord(text) {
    const clean = String(text ?? '').trim().replace(',', '.');
    if (!clean) return null;
    return /^-?\d+(\.\d+)?$/.test(clean) ? Number(clean) : NaN;
}

export default class MisEstablecimientos extends LightningElement {
    @api type;

    rowsAll = [];
    loading = true;
    searchKey = '';
    page = 1;

    selectedId;
    infoOpen = true;

    editOpen = false;
    editName = '';
    editLat = '';
    editLng = '';
    editVigente = false;
    editShowErrors = false;
    editSaveError = '';
    saving = false;
    _focusField;

    _initialized = false;
    _popHandler;

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
        this.selectedId = new URLSearchParams(window.location.search).get(DETAIL_PARAM) || undefined;
        this._popHandler = () => {
            this.selectedId = new URLSearchParams(window.location.search).get(DETAIL_PARAM) || undefined;
            this.editOpen = false;
            this.syncBodyLock();
        };
        window.addEventListener('popstate', this._popHandler);
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
        releasePortalModal(this);
        window.removeEventListener('popstate', this._popHandler);
    }

    renderedCallback() {
        if (!this._initialized) {
            this._initialized = true;
            this.loadRows();
        }
        this.syncBodyLock();
        if (this._focusField) {
            const el = this.template.querySelector(`[data-field="${this._focusField}"]`);
            if (el) {
                el.focus();
                this._focusField = undefined;
            }
        }
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    async loadRows() {
        await doRequest.call(this, async () => {
            const data = await getEstablecimientos();
            this.rowsAll = (data || [])
                .map((row) => this.decorateRow(row))
                .sort((a, b) => b.created - a.created || a.name.localeCompare(b.name, 'es'));
        });
    }

    decorateRow(row) {
        const lat = toNumber(row.lat);
        const lng = toNumber(row.lng);
        const hasCoords = lat != null && lng != null;
        const name = row.name || 'Sin nombre';
        return {
            id: row.id,
            name,
            productor: row.productor || '—',
            lat,
            lng,
            latLabel: lat != null ? String(lat) : '—',
            lngLabel: lng != null ? String(lng) : '—',
            coordsLabel: hasCoords ? `${lat}, ${lng}` : 'Sin coordenadas',
            vigente: row.vigente === true,
            created: row.createdDate ? Date.parse(row.createdDate) || 0 : 0,
            search: `${name} ${hasCoords ? `${lat} ${lng}` : ''}`.toLowerCase()
        };
    }

    /* ---------- Listado ---------- */

    get isList() {
        return !this.selectedId;
    }

    get filtered() {
        const term = this.searchKey.trim().toLowerCase();
        return term ? this.rowsAll.filter((r) => r.search.includes(term)) : this.rowsAll;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.filtered.length / PAGE_SIZE));
    }

    get currentPage() {
        return Math.min(this.page, this.totalPages);
    }

    get pageRows() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this.filtered.slice(start, start + PAGE_SIZE).map((r) => ({ ...r, href: this.detailHref(r.id) }));
    }

    get hasRows() {
        return this.filtered.length > 0;
    }

    get showEmpty() {
        return !this.loading && !this.hasRows;
    }

    get emptyText() {
        return this.searchKey.trim()
            ? 'No encontramos establecimientos con esa búsqueda.'
            : 'Todavía no cargaste establecimientos.';
    }

    get showPager() {
        return this.totalPages > 1;
    }

    get pageLabel() {
        return `Página ${this.currentPage}`;
    }

    get prevDisabled() {
        return this.currentPage <= 1;
    }

    get nextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    get countLabel() {
        const n = this.filtered.length;
        return `${n} elemento${n === 1 ? '' : 's'} · Ordenado por fecha de emisión`;
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value || '';
        this.page = 1;
    }

    handlePrev() {
        if (!this.prevDisabled) this.page = this.currentPage - 1;
    }

    handleNext() {
        if (!this.nextDisabled) this.page = this.currentPage + 1;
    }

    handleOpenRow(event) {
        event.preventDefault();
        this.openDetail(event.currentTarget.dataset.id);
    }

    detailHref(id) {
        const url = new URL(window.location.href);
        if (id) url.searchParams.set(DETAIL_PARAM, id);
        else url.searchParams.delete(DETAIL_PARAM);
        return url.pathname + url.search + url.hash;
    }

    openDetail(id) {
        if (!id) return;
        window.history.pushState({}, '', this.detailHref(id));
        this.selectedId = id;
        this.infoOpen = true;
        window.scrollTo(0, 0);
    }

    backToList(event) {
        event?.preventDefault();
        window.history.pushState({}, '', this.detailHref(null));
        this.selectedId = undefined;
        this.editOpen = false;
        this.syncBodyLock();
        window.scrollTo(0, 0);
    }

    handleNewEstablecimiento() {
        this.template.querySelector('c-establecimientos-map')?.openNew();
    }

    handleOpenMapa() {
        this.template.querySelector('c-establecimientos-map')?.openMap();
    }

    handleEstablecimientoSaved() {
        this.loadRows();
    }

    /* ---------- Detalle ---------- */

    get selected() {
        return this.rowsAll.find((r) => r.id === this.selectedId);
    }

    get showDetail() {
        return !!this.selectedId && !!this.selected;
    }

    get showNotFound() {
        return !!this.selectedId && !this.loading && !this.selected;
    }

    get listHref() {
        return this.detailHref(null);
    }

    get infoChevronClass() {
        return `p-chev${this.infoOpen ? ' open' : ''}`;
    }

    get infoExpanded() {
        return this.infoOpen ? 'true' : 'false';
    }

    get vigenteBoxClass() {
        return `p-check${this.selected?.vigente ? ' on' : ''}`;
    }

    get vigenteLabel() {
        return this.selected?.vigente ? 'Vigente' : 'No vigente';
    }

    toggleInfo() {
        this.infoOpen = !this.infoOpen;
    }

    /* ---------- Modificar ---------- */

    openEdit(event) {
        const row = this.selected;
        if (!row) return;
        this.editName = row.name === 'Sin nombre' ? '' : row.name;
        this.editLat = row.lat != null ? String(row.lat) : '';
        this.editLng = row.lng != null ? String(row.lng) : '';
        this.editVigente = row.vigente;
        this.editShowErrors = false;
        this.editSaveError = '';
        this.editOpen = true;
        this._focusField = event?.currentTarget?.dataset?.focus || 'name';
        this.syncBodyLock();
    }

    closeEdit() {
        if (this.saving) return;
        this.editOpen = false;
        this.syncBodyLock();
    }

    syncBodyLock() {
        syncPortalModal(this, this.editOpen, '.p-layer');
    }

    handleEditKeydown(event) {
        if (event.key === 'Escape') this.closeEdit();
    }

    handleEditInput(event) {
        const field = event.target.dataset.field;
        if (field === 'name') this.editName = event.target.value;
        else if (field === 'lat') this.editLat = event.target.value;
        else if (field === 'lng') this.editLng = event.target.value;
    }

    toggleEditVigente() {
        this.editVigente = !this.editVigente;
    }

    get editTitle() {
        return `Modificar ${this.selected?.name || 'establecimiento'}`;
    }

    get editNameError() {
        return this.editShowErrors && !this.editName.trim() ? REQUIRED_MSG : '';
    }

    coordError(text, validate, other) {
        if (!this.editShowErrors) return '';
        const value = parseCoord(text);
        const otherValue = parseCoord(other);
        if (value == null) return otherValue == null ? '' : 'Completá latitud y longitud';
        if (Number.isNaN(value)) return 'Ingresá un número válido';
        return validate(value);
    }

    get editLatError() {
        return this.coordError(this.editLat, latitudError, this.editLng);
    }

    get editLngError() {
        return this.coordError(this.editLng, longitudError, this.editLat);
    }

    get editNameClass() {
        return `p-input${this.editNameError ? ' err' : ''}`;
    }

    get editLatClass() {
        return `p-input${this.editLatError ? ' err' : ''}`;
    }

    get editLngClass() {
        return `p-input${this.editLngError ? ' err' : ''}`;
    }

    get editVigenteClass() {
        return `p-check${this.editVigente ? ' on' : ''}`;
    }

    get editVigenteAria() {
        return this.editVigente ? 'true' : 'false';
    }

    get saveLabel() {
        return this.saving ? 'Guardando…' : 'Guardar';
    }

    handleSave() {
        this.save(false);
    }

    handleSaveAndNew() {
        this.save(true);
    }

    async save(andNew) {
        this.editShowErrors = true;
        this.editSaveError = '';
        if (this.editNameError || this.editLatError || this.editLngError || this.saving) return;

        this.saving = true;
        try {
            await updateEstablecimiento({
                establecimientoId: this.selectedId,
                name: this.editName.trim(),
                lat: parseCoord(this.editLat),
                lng: parseCoord(this.editLng),
                vigente: this.editVigente
            });
            this.saving = false;
            this.editOpen = false;
            this.syncBodyLock();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Establecimiento actualizado',
                    message: 'Los cambios se guardaron correctamente.',
                    variant: 'success'
                })
            );
            await this.loadRows();
            if (andNew) this.handleNewEstablecimiento();
        } catch (e) {
            this.saving = false;
            this.editSaveError = reduceErrors(e).join('\n') || 'No se pudo guardar el establecimiento';
        }
    }
}
