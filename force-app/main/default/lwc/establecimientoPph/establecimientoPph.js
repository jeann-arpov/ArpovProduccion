import { LightningElement, api, track } from 'lwc';
import searchEstablecimientos from '@salesforce/apex/AdhesionPPH.searchEstablecimientos';
import { reduceErrors } from 'c/utils';
import { PAGES, communityPageUrl } from 'c/seNav';

const MSG_REQUERIDO = 'Este campo es obligatorio';
const MSG_SIN_CANTIDAD =
    'Debe ingresarse cantidad distinto a 0 en al menos una variedad para poder avanzar';

const fmt = (n) => new Intl.NumberFormat('es-AR').format(Number(n) || 0);

export default class EstablecimientoPph extends LightningElement {
    @api info;
    @api hiding;
    @api cultivo;
    @api totalHt;

    name = '';
    cantidadNoSEInput = '';
    longitude;
    latitude;
    collapsed = false;
    establecimiento;
    showErrors = false;

    searchTerm = '';
    @track searchResults = [];
    searchDone = false;
    searching = false;
    searchTimer;

    @track cantidades = {};

    connectedCallback() {
        if (this.initialized) return;
        this.initialized = true;

        const record = this.info?.record || {};
        const noSE = record.Cantidad_Variedad_No_SE__c;
        this.cantidadNoSEInput = noSE == null ? '' : String(noSE);

        if (record.Establecimiento__r) {
            this.establecimiento = {
                ...record.Establecimiento__r,
                id: record.Establecimiento__r.Id
            };
        }

        const cantidades = {};
        for (const linea of this.info?.lineas || []) {
            cantidades[linea.id] = linea.record?.Cantidad_Declarada__c || 0;
        }
        this.cantidades = cantidades;
    }

    disconnectedCallback() {
        clearTimeout(this.searchTimer);
    }

    get cultivoName() {
        return this.cultivo?.Name || '';
    }

    get blockClass() {
        return 'p-block' + (this.hiding && this.hiding[this.info?.id] ? ' is-hidden' : '');
    }

    get headerName() {
        return this.establecimiento?.Name || this.name || '';
    }

    get hasEstablecimiento() {
        return !!this.establecimiento;
    }

    get showCrear() {
        return !this.establecimiento;
    }

    get establecimientosUrl() {
        return communityPageUrl(PAGES.establecimientos);
    }

    get step2Label() {
        return 'Detallá variedades y hectáreas sembradas con Sembrá Evolución';
    }

    get step3Label() {
        return `Indicá cantidad de hectáreas de ${this.cultivoName} con variedades por fuera de SE`;
    }

    get haCaption() {
        return `HT totales de ${this.cultivoName}`;
    }

    get hasCoordinates() {
        return this.latitude != null && this.longitude != null;
    }

    get mapCoordinates() {
        if (!this.hasCoordinates) return '';
        return Number(this.latitude).toFixed(6) + ', ' + Number(this.longitude).toFixed(6);
    }

    get geoClass() {
        let cls = 'p-geo';
        if (this.hasCoordinates) cls += ' filled';
        if (this.geoError) cls += ' err';
        return cls;
    }

    get nameError() {
        return this.showErrors && this.showCrear && !this.name.trim() ? MSG_REQUERIDO : null;
    }

    get geoError() {
        return this.showErrors && this.showCrear && !this.hasCoordinates ? MSG_REQUERIDO : null;
    }

    get nameClass() {
        return this.nameError ? 'p-input err' : 'p-input';
    }

    get noSEError() {
        return this.showErrors && this.cantidadNoSEInput === '' ? MSG_REQUERIDO : null;
    }

    get noSEClass() {
        return this.noSEError ? 'p-input num p-input-short err' : 'p-input num p-input-short';
    }

    get disabled() {
        return !this.establecimiento && (this.name.trim() === '' || !this.hasCoordinates);
    }

    get infoClass() {
        let cls = 'p-sec p-info';
        if (this.disabled) cls += ' is-disabled';
        if (this.collapsed) cls += ' is-collapsed';
        return cls;
    }

    get haWrapClass() {
        return 'p-ha-wrap' + (this.disabled || !(Number(this.totalHt) > 0) ? ' off' : '');
    }

    get safeCantidadNoSE() {
        const value = Number(this.cantidadNoSEInput);
        return this.cantidadNoSEInput === '' || Number.isNaN(value) ? 0 : value;
    }

    get totalHtLabel() {
        return fmt(this.totalHt);
    }

    get hasVariedades() {
        return (this.info?.lineas || []).some((linea) => {
            const totals = linea.variedad?.totals || {};
            const disponibles = (totals.total || 0) - (totals.current || 0);
            return disponibles > 0 || (this.cantidades[linea.id] || 0) > 0;
        });
    }

    get showVariedades() {
        return this.hasVariedades && !this.disabled;
    }

    get vlistClass() {
        return this.showVariedades ? 'p-vlist' : 'p-vlist is-hidden';
    }

    get collapseLabel() {
        return this.collapsed ? 'Expandir' : 'Colapsar';
    }

    get chevronPath() {
        return this.collapsed ? 'M6 9l6 6 6-6' : 'M18 15l-6-6-6 6';
    }

    get hasSearchTerm() {
        return this.searchTerm.trim().length > 0;
    }

    get showDropdown() {
        return this.hasSearchTerm && (this.searchResults.length > 0 || this.searchDone);
    }

    get noResults() {
        return this.searchDone && this.searchResults.length === 0;
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value || '';
        this.searchDone = false;
        clearTimeout(this.searchTimer);
        if (this.searchTerm.trim().length < 2) {
            this.searchResults = [];
            return;
        }
        const term = this.searchTerm.trim();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimer = setTimeout(() => this.runSearch(term), 300);
    }

    async runSearch(term) {
        this.searching = true;
        try {
            const res = await searchEstablecimientos({ searchTerm: term });
            if (term !== this.searchTerm.trim()) return;
            this.searchResults = (res || []).map((r) => ({
                id: r.id,
                title: r.title,
                subtitle: r.subtitle || 'Establecimiento',
                record: r.record
            }));
            this.searchDone = true;
        } catch (e) {
            this.notify(reduceErrors(e).join('\n'));
        }
        this.searching = false;
    }

    handleSelectResult(event) {
        const id = event.currentTarget.dataset.id;
        const result = this.searchResults.find((r) => r.id === id);
        if (!result) return;
        this.establecimiento = { ...result.record, id: result.record.Id };
        this.searchTerm = '';
        this.searchResults = [];
        this.searchDone = false;
        this.dispatchEvent(new CustomEvent('pasoestablecimiento'));
        this.autosave();
    }

    handleClearSelection() {
        this.establecimiento = null;
        if (this.info?.record?.Id) {
            this.dispatchEvent(new CustomEvent('establecimientochange'));
        }
    }

    updateName(event) {
        this.name = event.target.value || '';
    }

    updateCantidad(event) {
        const { variedad, cantidad } = event.detail;
        this.cantidades = {
            ...this.cantidades,
            [variedad]: (this.cantidades[variedad] || 0) + cantidad
        };
        this.dispatchEvent(new CustomEvent('updatecantidad', { detail: event.detail }));
    }

    updateCantidadFuera(event) {
        this.cantidadNoSEInput = event.target.value === '' ? '' : String(event.target.value);
        if (this.safeCantidadNoSE > 0) {
            this.dispatchEvent(new CustomEvent('pasohectareasnose'));
        }
    }

    showMap() {
        this.dispatchEvent(
            new CustomEvent('showmap', {
                detail: { callback: this.updateLocation.bind(this) }
            })
        );
    }

    updateLocation(data, map) {
        map.hide();
        if (this.validateCoordinates(data.longitude, data.latitude)) {
            this.longitude = data.longitude;
            this.latitude = data.latitude;
            this.autosave();
            this.dispatchEvent(new CustomEvent('pasoestablecimiento'));
        } else {
            this.notify('Las coordenadas deben ser negativas');
        }
    }

    validateCoordinates(longitude, latitude) {
        return Math.sign(longitude) === -1 && Math.sign(latitude) === -1;
    }

    changeCollapsed() {
        this.collapsed = !this.collapsed;
    }

    remove() {
        this.dispatchEvent(new CustomEvent('remove'));
    }

    get variedadesPPH() {
        return Array.from(this.template.querySelectorAll('c-variedad-pph'));
    }

    /** Devuelve true si no hubo errores. report=false valida sin marcar los campos. */
    @api
    validate(report = true) {
        if (report) this.showErrors = true;
        let valid = true;

        if (this.showCrear && (!this.name.trim() || !this.hasCoordinates)) valid = false;
        if (this.cantidadNoSEInput === '') valid = false;

        let total = 0;
        for (const element of this.variedadesPPH) {
            if (!element.validate(report)) valid = false;
            total += element.getData().cantidad;
        }

        if (!valid && report) this.collapsed = false;

        if (valid && total + this.safeCantidadNoSE === 0) {
            throw new Error(MSG_SIN_CANTIDAD);
        }

        return valid;
    }

    @api getData() {
        const variedades = Object.fromEntries(
            this.variedadesPPH
                .filter((v) => v.cantidad > 0 || v.info.record.Id)
                .map((v) => [v.info.id, v.getData()])
        );
        return {
            id: this.establecimiento?.Id,
            latitude: this.establecimiento?.Coordenadas__Latitude__s || this.latitude,
            longitude: this.establecimiento?.Coordenadas__Longitude__s || this.longitude,
            cantidadNoSE: this.safeCantidadNoSE,
            name: this.establecimiento?.Name || this.name,
            variedades
        };
    }

    redirectCompraHT() {
        if (this.disabled) return;
        window.open(communityPageUrl(PAGES.comprar), '_blank');
    }

    autosave() {
        this.dispatchEvent(new CustomEvent('autosave'));
    }

    handleBlur(event) {
        if (event.target.dataset.val !== event.target.value) {
            this.autosave();
        }
    }

    handleFocus(event) {
        event.target.dataset.val = event.target.value;
    }

    notify(message) {
        this.dispatchEvent(new CustomEvent('notify', { detail: { message } }));
    }
}
