import { LightningElement, api } from 'lwc';
import getEstablecimientos from '@salesforce/apex/EstablecimientosMap.getEstablecimientos';
import getAccountId from '@salesforce/apex/EstablecimientosMap.getAccountId';
import insertEstablecimiento from '@salesforce/apex/EstablecimientosMap.insertEstablecimiento';
import { errorEvent, reduceErrors } from 'c/utils';
import { syncPortalModal, releasePortalModal } from 'c/seModalLayer';

const MAP_MOUNT_DELAY_MS = 320;
const REQUIRED_MSG = 'Este campo es obligatorio';

function formatCoord(value) {
    const n = Number(value);
    return Number.isFinite(n) ? String(n) : '';
}

export default class EstablecimientosMap extends LightningElement {
    @api hideChrome = false;

    markers = [];
    selectedProductor;
    loading = false;
    _loaded = false;

    mapOpen = false;
    mapReady = false;
    selectedMarker;

    newOpen = false;
    selectedName = '';
    latitude;
    longitude;
    showErrors = false;
    geoError = '';
    saveError = '';
    saving = false;

    successOpen = false;
    mensaje = '';

    _mapTimer;

    renderedCallback() {
        this.syncBodyLock();
    }

    disconnectedCallback() {
        if (this._mapTimer) window.clearTimeout(this._mapTimer);
        releasePortalModal(this);
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    syncBodyLock() {
        const open = this.mapOpen || this.newOpen || this.successOpen;
        syncPortalModal(this, open, '.p-layer');
    }

    async ensureData(force = false) {
        if (this._loaded && !force) return;
        this.loading = true;
        try {
            const [establecimientos, accountId] = await Promise.all([getEstablecimientos(), getAccountId()]);
            this.selectedProductor = accountId;
            this.markers = (establecimientos || [])
                .filter((est) => est.Coordenadas__Latitude__s != null && est.Coordenadas__Longitude__s != null)
                .map((est) => ({
                    value: est.Id,
                    title: est.Name,
                    location: {
                        Latitude: Number(est.Coordenadas__Latitude__s),
                        Longitude: Number(est.Coordenadas__Longitude__s)
                    }
                }));
            this._loaded = true;
        } catch (e) {
            this.onError(e);
        }
        this.loading = false;
    }

    /* ---------- Mapa ---------- */

    @api
    openMap() {
        this.mapOpen = true;
        this.mapReady = false;
        this.selectedMarker = undefined;
        this.syncBodyLock();
        this.ensureData();
        if (this._mapTimer) window.clearTimeout(this._mapTimer);
        // lightning-map calcula los bounds al montarse: esperar a que el modal tenga su tamaño final
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._mapTimer = window.setTimeout(() => {
            this.mapReady = true;
        }, MAP_MOUNT_DELAY_MS);
    }

    closeMap() {
        this.mapOpen = false;
        this.mapReady = false;
        this.syncBodyLock();
    }

    get hasMarkers() {
        return this.markers.length > 0;
    }

    get showMapCanvas() {
        return this.hasMarkers && this.mapReady;
    }

    get showMapEmpty() {
        return !this.loading && !this.hasMarkers;
    }

    get markersLabel() {
        return `Marcadores (${this.markers.length})`;
    }

    get markerItems() {
        return this.markers.map((m) => ({
            key: m.value,
            title: m.title || 'Sin nombre',
            coords: `${formatCoord(m.location.Latitude)}, ${formatCoord(m.location.Longitude)}`,
            className: `p-mk${m.value === this.selectedMarker ? ' is-on' : ''}`
        }));
    }

    handleMarkerSelect(event) {
        this.selectedMarker = event.currentTarget.dataset.id;
    }

    handleMapMarkerSelect(event) {
        this.selectedMarker = event.target.selectedMarkerValue;
    }

    /* ---------- Nuevo establecimiento ---------- */

    @api
    openNew() {
        this.selectedName = '';
        this.latitude = undefined;
        this.longitude = undefined;
        this.showErrors = false;
        this.geoError = '';
        this.saveError = '';
        this.newOpen = true;
        this.syncBodyLock();
        this.ensureData();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.requestAnimationFrame(() => {
            this.template.querySelector('[data-id="new-name"]')?.focus();
        });
    }

    closeNew() {
        if (this.saving) return;
        this.newOpen = false;
        this.syncBodyLock();
    }

    handleNameInput(event) {
        this.selectedName = event.target.value;
    }

    get hasGeo() {
        return this.latitude != null && this.longitude != null;
    }

    get geoLabel() {
        return this.hasGeo ? `${formatCoord(this.latitude)}, ${formatCoord(this.longitude)}` : '';
    }

    get nameError() {
        return this.showErrors && !this.selectedName.trim() ? REQUIRED_MSG : '';
    }

    get geoErrorMsg() {
        if (this.geoError) return this.geoError;
        return this.showErrors && !this.hasGeo ? REQUIRED_MSG : '';
    }

    get nameInputClass() {
        return `p-input${this.nameError ? ' err' : ''}`;
    }

    get geoClass() {
        let cls = 'p-geo';
        if (this.hasGeo) cls += ' filled';
        if (this.geoErrorMsg) cls += ' err';
        return cls;
    }

    openGeo() {
        this.template.querySelector('c-map')?.show((data, map) => {
            map.hide();
            const latitude = Number(data.latitude);
            const longitude = Number(data.longitude);
            if (!(Math.sign(latitude) === -1 && Math.sign(longitude) === -1)) {
                this.geoError = 'Las coordenadas deben ser negativas';
                return;
            }
            this.geoError = '';
            this.latitude = latitude;
            this.longitude = longitude;
        });
    }

    async handleSave() {
        this.showErrors = true;
        this.saveError = '';
        if (this.nameError || this.geoErrorMsg || this.saving) return;

        this.saving = true;
        try {
            await this.ensureData();
            const result = await insertEstablecimiento({
                fieldMap: {
                    Name: this.selectedName.trim(),
                    Coordenadas__Latitude__s: this.latitude,
                    Coordenadas__Longitude__s: this.longitude,
                    Vigente__c: true,
                    Origen__c: 'Propio',
                    Productor__c: this.selectedProductor
                }
            });
            if (result?.startsWith?.('Error')) {
                throw new Error(result);
            }
            this.saving = false;
            this.newOpen = false;
            this.mensaje = result || 'Nuevo establecimiento creado con éxito';
            this.successOpen = true;
            this.syncBodyLock();
            this.dispatchEvent(new CustomEvent('saved'));
            this.ensureData(true);
        } catch (e) {
            this.saving = false;
            this.saveError = reduceErrors(e).join('\n') || 'No se pudo crear el establecimiento';
        }
    }

    get saveLabel() {
        return this.saving ? 'Guardando…' : 'Guardar';
    }

    closeSuccess() {
        this.successOpen = false;
        this.syncBodyLock();
    }

    handleKeydown(event) {
        if (event.key !== 'Escape') return;
        if (this.successOpen) this.closeSuccess();
        else if (this.newOpen) this.closeNew();
        else if (this.mapOpen) this.closeMap();
    }
}
