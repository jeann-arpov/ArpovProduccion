import { LightningElement, api } from 'lwc';
import getObtentores from '@salesforce/apex/CreateTransactionController.getObtentores';
import getCampaigns from '@salesforce/apex/CreateTransactionController.getCampaigns';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {reduceErrors, validateInputs, getRecordFromInputs} from 'c/utils';
import saveChanges from '@salesforce/apex/EditTransactionController.saveChanges';
import getTransaction from '@salesforce/apex/EditTransactionController.getTransaction';
//import { CloseActionScreenEvent } from 'lightning/actions';

export default class EditTransaction extends LightningElement {
    @api recordId = '';

    obtentorId = '';
    campaignId = '';
    cultivo = {};

    loadedInit = false;
    created = false;
    
    savePromise;

    transaction;
    getTransactionPromise;

    get loading() {
        return this.loadedInit != true || this.savePromise != null;
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
        }));
    }

    setTransaction(r) {
        this.transaction = r;
        console.log(r)
    }

    async init() {
        this.recordId = this.recordId || new URL(window.location.href).searchParams.get("recordId");
        const getTransactionPromise = getTransaction({transactionId: this.recordId}).then(r => this.setTransaction(r)).finally(_ => this.getTransactionPromise = null);

        await Promise.all([getTransactionPromise]).catch(e => this.onError(e));

        this.loadedInit = true;
        this.updateProducts();
    }

    async save() {
        const valid = validateInputs(this.template.querySelector('.transaction-form')) && this.template.querySelector('c-item-dups-form').validate();
        if (valid) {
            const items = this.template.querySelector('c-item-dups-form').getItems();
            this.savePromise = saveChanges({transactionId: this.transaction.Id, jsonDups: JSON.stringify(items)}).then(r => this.onSuccess(r)).catch(e => this.onError(e)).finally(_ => this.savePromise = null);
        }
    }

    onSuccess(r) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Éxito',
            message: 'Se han realizado los cambios',
            variant: 'success',
        }));
        this.transaction.Item_de_DUP__r = this.template.querySelector('c-item-dups-form').dups = r;
        this.template.querySelector('c-item-dups-form').updateRows();
    }

    updateProducts() {
        this.template.querySelector('c-item-dups-form').updateProducts(this.transaction.Campana__r.Cultivo__c, this.transaction.Obtentor__c);
    }

    connectedCallback() {
        if (!this.initialized) {
            this.initialized = true;
            this.init();
        }
    }

    renderedCallback() {
        const style = document.createElement('style');
        style.innerText = `.modal-container{ max-width: 80% !important; width: auto} .modal-body{height: auto !important; padding: 0px !important} .cuf-content{padding: 0px !important}`;
        const body = this.template.querySelector('.body');

        if (body && !this.template.querySelector('.body style')) body.appendChild(style);
    }

    closeModal() {
        //this.dispatchEvent(new CloseActionScreenEvent());
        if (new URL(window.location.href).searchParams.get("recordId")) {
            if (window.opener != null || window.history.length == 1) window.close();
            else window.history.back();
        } else {
            this.dispatchEvent(new CustomEvent("close"));
        }
    }
}