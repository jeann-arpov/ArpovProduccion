import { LightningElement, track, api } from 'lwc';
import createItemDups from '@salesforce/apex/CreateItemDupController.createItemDups';
import getTransaction from '@salesforce/apex/CreateItemDupController.getTransaction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {reduceErrors} from 'c/utils';

export default class CreateItemDup extends LightningElement {
    @api recordId = 'a0J3C000000oBQrUAM';
    variedades = [];
    counter = 0;
    items = [{id: 0, data: {}, variant: "label-stacked"}]
    creatingItems = false;
    loadedTransaction = false;
    shouldShow = false;

    renderedCallback() {
        if (!this.initialized) {
            this.initialized = true;
            getTransaction({transactionId: this.recordId}).then(r => this.updateTransaction(r)).catch(e => this.onError(e)).finally(_ => this.loadedTransaction = true);
        }

        if (this.shouldShow && !this.loadedProducts && this.template.querySelector('c-item-dups-form')) {
            this.loadedProducts = true;
            this.template.querySelector('c-item-dups-form').updateProducts(this.transaction.Cultivo__c, this.transaction.Obtentor__c);
        }
    }

    updateTransaction(transaction) {
        this.transaction = transaction;
        this.shouldShow = transaction.Estado__c == 'Creada' || transaction.Estado__c == 'Respondida';
    }

    async createItems() {
        if (this.template.querySelector('c-item-dups-form').validate()) {
            const records = this.template.querySelector('c-item-dups-form').getItems();
            console.log(records);
            this.creatingItems = true;
            await createItemDups({transactionJson: JSON.stringify(this.transaction), jsonDups: JSON.stringify(records)}).then(r => this.onCreated(r)).catch(e => this.onError(e));
            this.creatingItems = false
        }
    }

    cancel() {
        this.dispatchEvent(new CustomEvent("close"));
    }

    onCreated(response) {
        let result = JSON.parse(response);
        console.log(result);
        this.dispatchEvent(new CustomEvent("success"));
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
        }));
    }

    get loading() {
        return this.creatingItems || !this.loadedTransaction;
    }
}