import { LightningElement, api } from 'lwc';

export default class Map extends LightningElement {
    @api latitude;
    @api longitude;
    callback;

    connectedCallback() {
        window.addEventListener("message", this.handleVFResponse.bind(this));
    }

    handleVFResponse(message) {
        if (message.origin === new URL(location.href).origin && message.data.lat != undefined) {
            console.log(JSON.parse(JSON.stringify(message.data)));
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
        this.template.querySelector('c-modal').show();
    }

    @api hide() {
        this.template.querySelector('c-modal').hide();
    }
}