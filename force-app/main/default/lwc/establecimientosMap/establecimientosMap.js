import { LightningElement, api } from 'lwc';
import getEstablecimientos from '@salesforce/apex/EstablecimientosMap.getEstablecimientos';
import getAccountId from '@salesforce/apex/EstablecimientosMap.getAccountId';
import insertEstablecimiento from '@salesforce/apex/EstablecimientosMap.insertEstablecimiento';
import { doRequest, errorEvent } from 'c/utils';

const DEFAULT_LAT = -34.603722;
const DEFAULT_LNG = -58.381592;
/** Misma duración que el drawer del header / pay sheet de Compra HT */
const SHEET_MS = 280;

export default class EstablecimientosMap extends LightningElement {
    @api hideChrome = false;

    markers = [];
    initialized = false;
    loading = false;

    mapSheetMounted = false;
    mapSheetOpen = false;
    mapReady = false;

    newSheetMounted = false;
    newSheetOpen = false;

    successMounted = false;
    successOpen = false;
    mensaje = '';

    selectedName = '';
    selectedSuperficie = '';
    selectedProductor;
    latitude;
    longitude;
    mapTick = 0;

    _boundVfHandler;
    _mapCloseTimer;
    _newCloseTimer;
    _successCloseTimer;
    _openRaf;
    _bodyLocked = false;

    connectedCallback() {
        this._boundVfHandler = this.handleVfMessage.bind(this);
        window.addEventListener('message', this._boundVfHandler);
    }

    disconnectedCallback() {
        if (this._boundVfHandler) {
            window.removeEventListener('message', this._boundVfHandler);
        }
        this.clearTimers();
        this.unlockBody();
    }

    clearTimers() {
        if (this._mapCloseTimer) window.clearTimeout(this._mapCloseTimer);
        if (this._newCloseTimer) window.clearTimeout(this._newCloseTimer);
        if (this._successCloseTimer) window.clearTimeout(this._successCloseTimer);
        if (this._openRaf) window.cancelAnimationFrame(this._openRaf);
        this._mapCloseTimer = null;
        this._newCloseTimer = null;
        this._successCloseTimer = null;
        this._openRaf = null;
    }

    lockBody() {
        if (this._bodyLocked) return;
        document.body.classList.add('se-drawer-open');
        this._bodyLocked = true;
    }

    unlockBody() {
        if (!this._bodyLocked) return;
        if (!this.mapSheetMounted && !this.newSheetMounted && !this.successMounted) {
            document.body.classList.remove('se-drawer-open');
            this._bodyLocked = false;
        }
    }

    /** Montar → paint → is-open (para que el transition corra) */
    afterMountOpen(setter) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._openRaf = window.requestAnimationFrame(() => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._openRaf = window.requestAnimationFrame(() => {
                setter();
                this._openRaf = null;
            });
        });
    }

    async init() {
        this.initialized = true;
        await this.refreshMarkers();
    }

    async refreshMarkers() {
        await doRequest.call(this, async () => {
            const establecimientos = await getEstablecimientos();
            this.selectedProductor = await getAccountId();
            this.markers = (establecimientos || [])
                .filter((est) => est.Coordenadas__Latitude__s != null && est.Coordenadas__Longitude__s != null)
                .map((est) => ({
                    title: est.Name,
                    location: {
                        Latitude: Number(est.Coordenadas__Latitude__s),
                        Longitude: Number(est.Coordenadas__Longitude__s)
                    }
                }));
        });
    }

    renderedCallback() {
        if (!this.initialized) {
            this.init();
        }
    }

    get mapBackdropClass() {
        return `se-sheet-backdrop${this.mapSheetOpen ? ' is-open' : ''}`;
    }

    get mapSheetClass() {
        return `se-sheet se-map-view${this.mapSheetOpen ? ' is-open' : ''}`;
    }

    get newBackdropClass() {
        return `se-sheet-backdrop${this.newSheetOpen ? ' is-open' : ''}`;
    }

    get newSheetClass() {
        return `se-sheet${this.newSheetOpen ? ' is-open' : ''}`;
    }

    get successBackdropClass() {
        return `se-sheet-backdrop${this.successOpen ? ' is-open' : ''}`;
    }

    get successDialogClass() {
        return `se-dialog${this.successOpen ? ' is-open' : ''}`;
    }

    /** Compat: callers / lógica interna que chequeaban showNewSheet */
    get showNewSheet() {
        return this.newSheetMounted;
    }

    @api
    openNew() {
        if (this._newCloseTimer) {
            window.clearTimeout(this._newCloseTimer);
            this._newCloseTimer = null;
        }
        this.resetForm();
        this.latitude = DEFAULT_LAT;
        this.longitude = DEFAULT_LNG;
        this.mapTick += 1;
        this.newSheetMounted = true;
        this.newSheetOpen = false;
        this.lockBody();
        this.afterMountOpen(() => {
            this.newSheetOpen = true;
        });
    }

    @api
    openMap() {
        if (this._mapCloseTimer) {
            window.clearTimeout(this._mapCloseTimer);
            this._mapCloseTimer = null;
        }
        this.mapSheetMounted = true;
        this.mapSheetOpen = false;
        this.mapReady = false;
        this.lockBody();
        this.afterMountOpen(() => {
            this.mapSheetOpen = true;
        });
        // Montar el mapa cuando el sheet ya tiene tamaño real (fitBounds correcto)
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this.mapReady = true;
        }, SHEET_MS + 40);
    }

    closeMap() {
        this.mapSheetOpen = false;
        this.mapReady = false;
        if (this._mapCloseTimer) window.clearTimeout(this._mapCloseTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._mapCloseTimer = window.setTimeout(() => {
            this.mapSheetMounted = false;
            this._mapCloseTimer = null;
            this.unlockBody();
        }, SHEET_MS);
    }

    handleMapBackdropClick(event) {
        if (event.target.classList.contains('se-sheet-backdrop')) {
            this.closeMap();
        }
    }

    get hasMarkers() {
        return (this.markers || []).length > 0;
    }

    get showMapCanvas() {
        return this.hasMarkers && this.mapReady;
    }

    get markersCountLabel() {
        const n = (this.markers || []).length;
        return n === 1 ? '1 establecimiento' : `${n} establecimientos`;
    }

    get markerItems() {
        return (this.markers || []).map((m, i) => {
            const lat = Number(m?.location?.Latitude);
            const lng = Number(m?.location?.Longitude);
            const coords =
                Number.isFinite(lat) && Number.isFinite(lng)
                    ? `${lat.toFixed(5)}, ${lng.toFixed(5)}`
                    : '';
            return {
                key: String(i),
                title: m.title || 'Sin nombre',
                coords
            };
        });
    }

    get mapPreviewSource() {
        const lat = this.latitude != null ? this.latitude : DEFAULT_LAT;
        const lng = this.longitude != null ? this.longitude : DEFAULT_LNG;
        const pathParts = location.href.split('/s')[0].split('/');
        const community = pathParts[pathParts.length - 1] || '';
        return `/${community}/apex/GoogleMapIframe?latitud=${lat}&longitud=${lng}&t=${this.mapTick}`;
    }

    get mapCoodinates() {
        if (this.latitude != null && this.longitude != null) {
            return `${Number(this.latitude).toFixed(3)}°, ${Number(this.longitude).toFixed(3)}°`;
        }
        return 'Elegir georeferencia';
    }

    get saveDisabled() {
        return !this.selectedName?.trim() || this.latitude == null || this.longitude == null;
    }

    validateCoordinates(longitude, latitude) {
        return Math.sign(longitude) === -1 && Math.sign(latitude) === -1;
    }

    handleVfMessage(message) {
        if (!this.newSheetMounted) return;
        try {
            if (message.origin !== new URL(location.href).origin) return;
            if (message.data?.lat == null || message.data?.lng == null) return;
            const latitude = Number(message.data.lat);
            const longitude = Number(message.data.lng);
            if (!this.validateCoordinates(longitude, latitude)) {
                this.dispatchEvent(errorEvent(new Error('Las coordenadas deben ser negativas')));
                return;
            }
            this.latitude = latitude;
            this.longitude = longitude;
        } catch (e) {
            // ignore cross-origin noise
        }
    }

    handleLocateMe() {
        if (!navigator.geolocation) {
            this.dispatchEvent(errorEvent(new Error('Tu navegador no permite geolocalización')));
            return;
        }
        navigator.geolocation.getCurrentPosition(
            (pos) => {
                const latitude = pos.coords.latitude;
                const longitude = pos.coords.longitude;
                if (!this.validateCoordinates(longitude, latitude)) {
                    this.dispatchEvent(
                        errorEvent(new Error('La ubicación actual no es válida para Argentina (coords negativas)'))
                    );
                    return;
                }
                this.latitude = latitude;
                this.longitude = longitude;
                this.mapTick += 1;
            },
            () => {
                this.dispatchEvent(errorEvent(new Error('No se pudo obtener tu ubicación')));
            },
            { enableHighAccuracy: true, timeout: 10000 }
        );
    }

    handleNameInput(event) {
        this.selectedName = event.target.value;
    }

    handleSuperficieInput(event) {
        this.selectedSuperficie = event.target.value;
    }

    handleBackdropClick(event) {
        if (event.target.classList.contains('se-sheet-backdrop')) {
            this.closeNew();
        }
    }

    closeNew() {
        this.newSheetOpen = false;
        if (this._newCloseTimer) window.clearTimeout(this._newCloseTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._newCloseTimer = window.setTimeout(() => {
            this.newSheetMounted = false;
            this.resetForm();
            this._newCloseTimer = null;
            this.unlockBody();
        }, SHEET_MS);
    }

    openSuccess(message) {
        if (this._successCloseTimer) {
            window.clearTimeout(this._successCloseTimer);
            this._successCloseTimer = null;
        }
        this.mensaje = message;
        this.successMounted = true;
        this.successOpen = false;
        this.lockBody();
        this.afterMountOpen(() => {
            this.successOpen = true;
        });
    }

    closeSuccess() {
        this.successOpen = false;
        if (this._successCloseTimer) window.clearTimeout(this._successCloseTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._successCloseTimer = window.setTimeout(() => {
            this.successMounted = false;
            this.mensaje = '';
            this._successCloseTimer = null;
            this.unlockBody();
        }, SHEET_MS);
    }

    resetForm() {
        this.selectedName = '';
        this.selectedSuperficie = '';
        this.latitude = undefined;
        this.longitude = undefined;
    }

    async handleSave() {
        if (this.saveDisabled) return;

        const fieldMap = {
            Name: this.selectedName.trim(),
            Coordenadas__Latitude__s: parseFloat(this.latitude),
            Coordenadas__Longitude__s: parseFloat(this.longitude),
            Vigente__c: true,
            Origen__c: 'Propio',
            Productor__c: this.selectedProductor
        };

        this.newSheetOpen = false;
        if (this._newCloseTimer) window.clearTimeout(this._newCloseTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._newCloseTimer = window.setTimeout(() => {
            this.newSheetMounted = false;
            this._newCloseTimer = null;
            this.unlockBody();
        }, SHEET_MS);

        await doRequest.call(this, async () => {
            const result = await insertEstablecimiento({ fieldMap });
            if (result?.startsWith?.('Error')) {
                throw new Error(result);
            }
            await this.refreshMarkers();
            this.dispatchEvent(new CustomEvent('saved'));
            this.resetForm();
            this.openSuccess(result || 'Nuevo establecimiento generado con éxito');
        });
    }
}
