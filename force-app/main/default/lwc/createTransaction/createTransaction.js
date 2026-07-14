import { LightningElement } from 'lwc';
import getObtentores from '@salesforce/apex/CreateTransactionController.getObtentores';
import getCampaigns from '@salesforce/apex/CreateTransactionController.getCampaigns';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {reduceErrors, validateInputs, getRecordFromInputs} from 'c/utils';
import createItemDups from '@salesforce/apex/CreateItemDupController.createItemDups';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

export default class CreateTransaction extends LightningElement {
    transactionId = '';
    obtentorId = '';
    campaignId = '';
    cultivo = {};

    obtentores = [];
    campaigns = [];

    loadedInit = false;
    creating = false;
    created = false;


    get loading() {
        return this.loadedInit != true || this.creating;
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
        }));
    }

    getOptions(records) {
        return records.map(r => ({label: r.Name, value: r.Id, record: r}));
    }

    async init() {
        const obtentores = getObtentores().then(o => this.obtentores = this.getOptions(o));
        const campaigns = getCampaigns().then(c => this.campaigns = this.getOptions(c));

        await Promise.all([obtentores, campaigns]).catch(e => this.onError(e));

        this.loadedInit = true;
    }
    changeCampaign(event) {
        if (event.target.value) {
            const campaign = this.campaigns.find(r => r.value == event.target.value);
            this.cultivo = campaign.record.Cultivo__r;
            this.updateProducts();
        }
    }

    changeObtentor(event) {
        this.obtentorId = event.target.value;
        this.updateProducts();
    }

    updateProducts() {
        this.template.querySelector('c-item-dups-form').updateProducts(this.cultivo.Id, this.obtentorId);
    }

    async createTransaction() {
        const valid = validateInputs(this.template.querySelector('.transaction-form')) && this.template.querySelector('c-item-dups-form').validate();
        if (valid) {
            const transaction = getRecordFromInputs(this.template.querySelector('.transaction-form'));
            const items = this.template.querySelector('c-item-dups-form').getItems();
            this.creating = true;
            await createItemDups({transactionJson: JSON.stringify(transaction), jsonDups: JSON.stringify(items)}).then(r => this.onCreated(r)).catch(e => this.onError(e));
            this.creating = false;
        }
    }

    onCreated(transactionId) {
        getRecordNotifyChange([transactionId]);
        this.created = true;
    }

    closeModal() {
        this.template.querySelector('c-modal').hide();
    }

    openModal() {
        if (!this.initialized) {
            this.initialized = true;
            this.init();
        }
        this.template.querySelector('c-modal').show();
    }
}