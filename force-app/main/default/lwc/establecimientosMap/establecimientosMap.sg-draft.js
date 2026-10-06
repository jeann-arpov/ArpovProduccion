import { LightningElement, api } from 'lwc';
import getEstablecimientos from '@salesforce/apex/EstablecimientosMap.getEstablecimientos';
import getAccountId from '@salesforce/apex/EstablecimientosMap.getAccountId';
import insertEstablecimiento from '@salesforce/apex/EstablecimientosMap.insertEstablecimiento';
import { doRequest, errorEvent } from 'c/utils';

export default class EstablecimientosMap extends LightningElement {
    markers = [];
    initialized = false;
    loading = false;

    showNewSheet = false;
    showSuccess = false;
    mensaje = '';

    selectedName = '';
    selectedProductor;
    latitude;
    longitude;

    async init() {
        this.initialized = true;
        await this.refreshMarkers();
    }

    async refreshMarkers() {
        await doRequest.call(this, async () => {
            const establecimientos = await getEstablecimientos();
            this.selectedProductor = await getAccountId();
            this.markers = (establecimientos || [])
                .filter((est) => est.Coordenadas__Latitude__s != null)
                .map((est) => ({
                    title: est.Name,
                    location: {
                        Latitude: String(est.Coordenadas__Latitude__s),
                        Longitude: String(est.Coordenadas__Longitude__s)
                    }
                }));
        });
    }

    renderedCallback() {
        if (!this.initialized) {
            this.init();
        }
    }

    @api
    openNew() {
        this.resetForm();
        this.showNewSheet = true;
    }

    @api
    openMap() {
        this.template.querySelector('c-modal')?.show();
    }

    get mapCoodinates() {
        if (this.latitude !== undefined) {
            return `${this.latitude.toFixed(3)}┬░, ${this.longitude.toFixed(3)}┬░`;
        }
        return 'Elegir georeferencia';
    }

    get saveDisabled() {
        return !this.selectedName?.trim() || this.latitude === undefined;
    }

    validateCoordinates(longitude, latitude) {
        return Math.sign(longitude) === -1 && Math.sign(latitude) === -1;
    }

    showMap() {
        this.template.querySelector('c-map')?.show(this.updateLocation.bind(this));
    }

    updateLocation(data, map) {
        map.hide();
        if (this.validateCoordinates(data.longitude, data.latitude)) {
            this.longitude = data.longitude;
            this.latitude = data.latitude;
        } else {
            this.dispatchEvent(errorEvent(new Error('Las coordenadas deben ser negativas')));
        }
    }

    handleNameChange(event) {
        this.selectedName = event.detail.value;
    }

    handleBackdropClick(event) {
        if (event.target.classList.contains('se-sheet-backdrop')) {
            this.closeNew();
        }
    }

    closeNew() {
        this.showNewSheet = false;
        this.resetForm();
    }

    closeSuccess() {
        this.showSuccess = false;
        this.mensaje = '';
    }

    resetForm() {
        this.selectedName = '';
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
            Productor__c: this.selectedProductor
        };

        this.showNewSheet = false;

        await doRequest.call(this, async () => {
            const result = await insertEstablecimiento({ fieldMap });
            if (result?.startsWith('Error')) {
                throw new Error(result);
            }
            this.mensaje = result || 'Nuevo establecimiento generado con ├®xito';
            this.showSuccess = true;
            await this.refreshMarkers();
            this.dispatchEvent(new CustomEvent('saved'));
            this.resetForm();
        });
    }
}
