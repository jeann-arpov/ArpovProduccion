import { LightningElement, api } from 'lwc';
import {getRecordsFromForms, validateInputs, reduceErrors} from 'c/utils';
import getProducts from '@salesforce/apex/CreateItemDupController.getProducts'; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const CSS = `
    lightning-record-edit-form:not(:first-of-type) lightning-helptext {
        display:none;
    }

            
    lightning-record-edit-form:not(:first-of-type) lightning-layout-item > * {
        padding: 0 var(--lwc-spacingXxSmall,0.25rem);
        margin-bottom: var(--lwc-spacingXSmall,0.5rem);
        display: block;
    }

    .slds-modal__content{
        overflow: initial;
    }
`;

export default class ItemDupsForm extends LightningElement {
    variedades = [];
    counter = 0;
    items = [{id: 0, data: {}, variant: "label-stacked"}];
    loadedProductData = false;
    @api dups;

    renderedCallback() {
        const style = document.createElement('style');
        style.innerText = CSS;
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form && !form.querySelector('style')) form.appendChild(style);
    }

    connectedCallback() {
        this.updateRows();
    }

    @api
    updateRows() {
        if (this.dups && this.dups.length) {
            this.items = [];
            for (const dup of this.dups) {
                this.addRow();
                this.items[this.items.length - 1].data = dup;
            }
            this.items[0].variant = "label-stacked";
        }
    }

    @api 
    updateProducts(cultivoId, obtentorId) {
        if (!cultivoId || !obtentorId) return;
        this.loadedProductData = false;
        getProducts({cultivoId, obtentorId}).then(r => this.updateVariedades(r)).catch(e => this.onError(e)).finally(_ => this.loadedProductData = true);
    }

    updateVariedades(records) {
        this.variedades = records.map(r => ({label: r.Variedad__c, value: r.Id}));
    }

    addRow() {
        this.counter++;
        this.items = this.items.concat([{id: this.counter, data: {}, variant: "label-hidden"}]);
    }

    removeRow(event) {
        if (this.items.length > 1 || this.dups) {
            this.items = this.items.filter(e => parseInt(e.id) !== parseInt(event.target.accessKey));
            this.items.forEach((i, idx) => i.variant = idx == 0 ? 'label-stacked' : 'label-hidden')
        }
    }

    @api
    validate() {
        return validateInputs(this.template);
    }

    @api
    getItems() {
        return getRecordsFromForms(this.template);
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
        }));
    }

    get loading() {
        return !this.loadedProductData;
    }
}