import { LightningElement, api } from 'lwc';
import icons from 'c/icons';

export default class VariedadPph extends LightningElement {
    @api cantidad;
    @api info;
    lastCantidadSent;

    init() {
        this.initialized = true;
        this.cantidad = this.info.record.Cantidad_Declarada__c || 0;
        this.lastCantidadSent = this.safeCantidad;
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    get safeCantidad() {
        return this.cantidad || 0;
    }

    get icono() {
        return icons.semilleros[this.info.variedad.Obtentor_Comercializa__r.Id_Obtentor__c];
    }

    get disponibles() {
        return this.info.variedad.totals.total - (this.info.variedad.totals.current || 0);
    }

    get safeDisponibles() {
        return Math.max(this.disponibles, 0);
    }

    get maxValue() {
        return Math.max(this.disponibles + this.safeCantidad, 0);
    }

    get shouldShow() {
        return this.disponibles > 0 || this.safeCantidad > 0;
    }
    
    updateCantidad(event) {
        this.cantidad = event.target.reportValidity() ? +event.target.value : 0;
        this.dispatchEvent(new CustomEvent('updatecantidad', {detail: {variedad: this.info.variedad.Id, cantidad: this.cantidad - this.lastCantidadSent}}));
        this.lastCantidadSent = this.cantidad;
    }

    @api
    validate() {
        let valid = true;

        for (const element of this.template.querySelectorAll('lightning-input')) {
            if (!element.reportValidity()) valid = false;
        }

        return valid;
    }

    @api getData() {
        return {id: this.info.record.Id, cantidad: this.safeCantidad, variedad: this.info.variedad, icono: this.icono};
    }

    blur(e) {
        if (e.target.dataset.val != e.target.value) {
            this.dispatchEvent(new CustomEvent('autosave'));
        }
    }

    focus(e) {
        e.target.dataset.val = e.target.value;
    }
}