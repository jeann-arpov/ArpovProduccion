import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import searchEstablecimientos from '@salesforce/apex/AdhesionPPH.searchEstablecimientos';
import icons from 'c/icons';
import { errorEvent } from 'c/utils';

export default class EstablecimientoPph extends NavigationMixin(LightningElement) {
    @api info;
    @api hiding;
    @api cultivo;
    @api grandesCuentas;

    name = "";
    cantidadNoSE; //  cantidad de hectáreas con variedades por fuera de SE
    longitude// = -34.60;
    latitude// = -58.64;
    collapsed = false;
    establecimiento;

    icons = icons.pph;

    init() {
        this.initialized = true;
        
        this.cantidadNoSE = this.info.record.Cantidad_Variedad_No_SE__c;

        if (this.info.record.Establecimiento__r) {
            this.establecimiento = {...this.info.record.Establecimiento__r, title: this.info.record.Name, id: this.info.record.Establecimiento__r.Id, icon: 'standard:address'};
        }
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    get titulo() {
        return "Establecimiento " + (this.establecimiento?.Name || (this.name ? " - " + this.name : ""));
    }

    updateName(event) {
        this.name = event.target.value;
    }

    updateCantidad(event) {
        this.dispatchEvent(new CustomEvent('updatecantidad', {detail: event.detail}));
    }

    updateCantidadFuera(event) {
        this.cantidadNoSE = +event.detail.value;
    }

    showMap(event) {
        this.dispatchEvent(new CustomEvent('showmap', {detail: {callback: this.updateLocation.bind(this)}}));
    }

    updateLocation(data, map) {
        map.hide();
        if(this.validateCoordinates(data.longitude, data.latitude)){
            this.longitude = data.longitude;
            this.latitude = data.latitude;
            //sin esto queda como required faltante
            this.template.querySelector('.coordinates').value = this.mapCoodinates;
            this.template.querySelector('.coordinates').setCustomValidity('');
            this.template.querySelector('.coordinates').reportValidity();
            this.autosave();
        }else{
            this.dispatchEvent(errorEvent(new Error('Las coordenadas deben ser negativas')));
        }
    }

    validateCoordinates(longitude, latitude){
        return Math.sign(longitude) == -1 && Math.sign(latitude) == -1;
    }

    changeCollapsed(event) {
        this.collapsed = !this.collapsed;
    }

    remove(event) {
        this.dispatchEvent(new CustomEvent('remove'));
    }

    get safeCantidadNoSE() {
        return (this.cantidadNoSE || 0);
    }

    get totalSembrado() {
        return this.safeCantidadNoSE + this.variedadesPPH.map(e => e.getData().cantidad).reduce((a, b) => a + b, 0);
    }

    get mapCoodinates() {
        if (this.latitude != undefined) return this.latitude.toFixed(2) + ', ' + this.longitude.toFixed(2);
        return "Seleccionar Punto de lote";
    }

    get coordinatesClass() {
        return "coordinates" + (this.latitude != undefined ? '' : ' black');
    }

    get disabled() {
        return this.grandesCuentas == false && (!this.establecimiento && (this.name.trim() == "" || this.longitude == undefined || this.latitude == undefined)); 
    }

    get infoClass() {
        let cls = "info";
        if (this.collapsed) cls += " collapsed";
        if (this.disabled) cls += " disabled";
        return cls;
    }

    //devuelve true si no hubo errores
    @api
    validate() {
        let valid = true;

        if (this.grandesCuentas == false && !this.establecimiento && this.mapCoodinates.startsWith('Selec')) {
            this.template.querySelector('.coordinates').setCustomValidity('Este campo es obligatorio');
        }

        for (const element of this.template.querySelectorAll('lightning-input')) {
            if (!element.reportValidity()) valid = false;
        }

        let total = 0;

        for (const element of this.template.querySelectorAll('c-variedad-pph')) {
            if (!element.validate()) valid = false;
            total += element.getData().cantidad;
        }

        if (valid && total + this.safeCantidadNoSE == 0) {
            throw "Debe ingresarse cantidad distinto a 0 en al menos una variedad para poder avanzar";
        }

        return valid;
    }

    get variedadesPPH() {
        return Array.from(this.template.querySelectorAll('c-variedad-pph'));
    }

    @api getData() {
        const variedades = Object.fromEntries(this.variedadesPPH.filter(v => v.cantidad > 0 || v.info.record.Id).map(v => [v.info.id, v.getData()]));
        let data = {
            id: this.establecimiento?.Id,
            latitude: this.establecimiento?.Coordenadas__Latitude__s || this.latitude, 
            longitude: this.establecimiento?.Coordenadas__Longitude__s || this.longitude, 
            cantidadNoSE: this.safeCantidadNoSE, 
            name: this.establecimiento?.Name || this.name, 
            variedades
        };
        console.log(data);
        return data;
    }

    redirectCompraHT(event) {
        this[NavigationMixin.GenerateUrl]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'FormularioNuevaVentaHT',
            }
        }).then(url => window.open(url, "_blank"));
    }

    get establecimientoClass() {
        return "establecimiento" + (this.hiding[this.info.id] ? ' slds-hide' : '');
    }

    autosave(e) {
        this.dispatchEvent(new CustomEvent('autosave'));
    }

    blur(e) {
        if (e.target.dataset.val != e.target.value) {
            this.autosave();
        }
    }

    focus(e) {
        e.target.dataset.val = e.target.value;
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    establecimientoSelected(event) {
        const selection = event.target.getSelection();
        this.establecimiento = selection.length ? {...selection[0].record, title: selection[0].record.Name, icon: 'standard:address'} : null;

        if(this.establecimiento == null && this.info.record.Id) this.dispatchEvent(new CustomEvent('establecimientochange'));
    }

    async search(event) {
        const lookup = event.target;
        await searchEstablecimientos({searchTerm: event.detail.searchTerm}).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }

    get totalesSembradasLabel() {
        return `Hectáreas TOTALES de ${this.cultivo.Name} Sembradas`;
    }
}