import { LightningElement, api } from 'lwc';
import searchDestinatarios from '@salesforce/apex/CesionPPH.searchDestinatarios';
import {errorEvent} from 'c/utils';
import icons from 'c/icons';

export default class DestinatarioPph extends LightningElement {
    @api info;
    @api hiding;

    destinatario;
    icons = icons;
    collapsed;

    connectedCallback() {
        if (this.info.account) {
            this.destinatario = this.info.account;
        }
    }

    remove(event) {
        this.dispatchEvent(new CustomEvent('remove'));
    }

    async search(event) {
        const lookup = event.target;
        await searchDestinatarios(event.detail).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    destinatarioSelected(event) {
        const selection = event.target.getSelection();
        this.destinatario = selection.length ? selection[0] : null;
        this.autosave();
    }

    handleRemove(e) {
        this.destinatario = null;
    }

    updateCantidad(event) {
        this.dispatchEvent(new CustomEvent('updatecantidad', {detail: event.detail}));
    }

    autosave(e) {
        this.dispatchEvent(new CustomEvent('autosave'));
    }

    changeCollapsed(event) {
        this.collapsed = !this.collapsed;
    }

    get disabled() {
        return this.destinatario == null;
    }

    get infoClass() {
        let cls = "info";
        if (this.collapsed) cls += " collapsed";
        if (this.disabled) cls += " disabled";
        return cls;
    }

    //devuelve true si no hubo errores
    @api
    validate(isContinue = false) {
        let valid = true;

        for (const element of this.template.querySelectorAll('lightning-input')) {
            if (!element.reportValidity()) valid = false;
        }

        let total = 0;

        for (const element of this.template.querySelectorAll('c-linea-destinatario-pph')) {
            if (!element.validate(isContinue)) valid = false;
            total += element.getData().cantidad;
        }

        if (this.destinatario == null) throw "Debe ingresar un destinatario para poder avanzar";

        if (valid && total == 0) {
            throw "Debe ingresarse cantidad distinto a 0 en al menos una variedad para poder avanzar";
        }

        return valid;
    }

    get variedadesPPH() {
        return Array.from(this.template.querySelectorAll('c-linea-destinatario-pph'));
    }

    @api getData() {
        const variedades = Object.fromEntries(this.variedadesPPH.filter(v => v.cantidad > 0 || v.info.record.Id).map(v => [v.info.id, v.getData()]));
        return {destinatarioId: this.destinatario?.record.Id, variedades, id: this.info.record.Id, record: this.info.record, destinatarioRecord: this.destinatario?.record}
    }

    @api getAccount() {
        return this.destinatario;
    }

    get destinatarioClass() {
        let cls = 'destinatario';
        if (this.hiding[this.info.id]) cls += ' slds-hide';
        if (this.info.record.Estado__c != 'En Curso') cls += ' disabled';
        return cls;
    }

    registerCuit() {
        this.dispatchEvent(new CustomEvent('registercuit', {detail: this.template.querySelector('c-lookup').getSearchTerm()}));
    }

    @api onRegisterCuit(res) {
        const lookup = this.template.querySelector('c-lookup');
        lookup.setSearchResults(res);

        if (res.length) {
            lookup.selection = res[0];
            this.destinatarioSelected({target: lookup});
        }
    }
}