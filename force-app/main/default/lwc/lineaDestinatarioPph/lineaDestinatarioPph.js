import { LightningElement, api } from 'lwc';
import icons from 'c/icons';

export default class LineaDestinatarioPph extends LightningElement {
    @api cantidad;
    @api info;

    lastCantidadSent;

    init() {
        this.initialized = true;
        this.cantidad = (this.info.record.Cantidad__c || 0) ;
        this.lastCantidadSent = this.cantidad;
        console.log("init", this.cantidad, this.lastCantidadSent)
    }

    renderedCallback() {
        if (!this.initialized) this.init();
        console.log('lineaDestinatarioPph logo', { logoWidth: this.logoWidth, icono: this.icono });
    }

    get safeCantidad() {
        return this.cantidad || 0;
    }

    get icono() {
        return icons.semilleros[this.info.variedad.Obtentor_Comercializa__r.Id_Obtentor__c];
    }

    get logoWidth() {
        const obtentorId = this.info?.variedad?.Obtentor_Comercializa__r?.Id_Obtentor__c;
        const logoWidthByObtentor = {
            // LG tends to look larger with the same width
            '12': 100,
            // Buck is wider and needs a bit more room
            '05': 180
        };
        return logoWidthByObtentor[obtentorId] || 200;
    }

    get disponibles() {
        return (this.info.variedad.totals.stock - this.info.variedad.totals.current);
    }

    get maxValue() {
        return this.disponibles + this.safeCantidad;
    }
    
    updateCantidad(event) {
        const cantidad = event.target.reportValidity() ? +event.target.value : 0;
        this.dispatchEvent(new CustomEvent('updatecantidad', {detail: {variedad: this.info.variedad.Id, cantidad: cantidad - this.lastCantidadSent}}));
        console.log(cantidad, this.lastCantidadSent)
        this.lastCantidadSent = cantidad;
        if (cantidad > 0) this.cantidad = cantidad;
    }

    @api
    validate(isContinue = false) {
        let valid = true;

        for (const element of this.template.querySelectorAll('lightning-input')) {
            if (!element.reportValidity()) valid = false;
        }

        if(isContinue && this.disponibles < 0){
            throw 'Debe comprar HT para poder avanzar con la cesión';
        }

        return valid;
    }

    @api getData() {
        return {id: this.info.record.Id, cantidad: this.safeCantidad, variedad: this.info.variedad, icono: this.icono, license: this.info.record.Licencia__c};
    }

    blur(e) {
        this.cantidad = e.target.value = this.lastCantidadSent;
        e.target.reportValidity();

        if (e.target.dataset.val != e.target.cantidad) {
            this.dispatchEvent(new CustomEvent('autosave'));
        }
    }

    focus(e) {
        e.target.dataset.val = e.target.cantidad;
    }
}