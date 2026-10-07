import { LightningElement, api } from 'lwc';
import { syncPortalModal, releasePortalModal } from 'c/seModalLayer';

export default class Map extends LightningElement {
    @api latitude;
    @api longitude;
    @api title = 'Seleccionar punto de lote';
    callback;
    isOpen = false;

    connectedCallback() {
        this.messageHandler = this.handleVFResponse.bind(this);
        window.addEventListener('message', this.messageHandler);
    }

    renderedCallback() {
        syncPortalModal(this, this.isOpen, '.sg-layer');
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.messageHandler);
        releasePortalModal(this);
    }

    handleVFResponse(message) {
        if (message.origin === new URL(location.href).origin && message.data.lat != undefined) {
            const location = {latitude: message.data.lat, longitude: message.data.lng};
            this.latitude = location.latitude;
            this.longitude = location.longitude;

            if (this.callback) this.callback(location, this);
            else this.dispatchEvent(new CustomEvent('locationselected', {detail: location}))
        }
    }

    get mapSource() {
        return '/' + location.href.split('/s')[0].split('/').pop() + '/apex/GoogleMapIframe?latitud=' + (this.latitude || -34.603722) + '&longitud=' + (this.longitude || -58.381592);
    }

    @api show(callback) {
        this.callback = callback;
        this.isOpen = true;
    }

    @api hide() {
        this.isOpen = false;
    }
}
