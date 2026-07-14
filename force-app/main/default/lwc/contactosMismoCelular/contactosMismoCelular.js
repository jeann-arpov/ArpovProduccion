import { LightningElement, api } from 'lwc';
import getContacts from '@salesforce/apex/LWCContactosMismoCelular.getContacts';
import saveRecords from '@salesforce/apex/LWCContactosMismoCelular.saveRecords';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {reduceErrors} from 'c/utils';
import {getRecordNotifyChange} from 'lightning/uiRecordApi';

export default class ContactosMismoCelular extends LightningElement {
    @api recordId;
    contacts;
    loading;
    phone;
    user;
    isWhatsapp;

    renderedCallback() {
        if (!this.init && this.recordId) {
            this.init = true;
            this.loading = true;
            getContacts({recordId: this.recordId}).then(d => this.loadContacts(d)).catch(e => this.onError(e)).finally(_ => this.loading = false);
        }
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
        }));
    }

    loadContacts(data) {
        this.contacts = data.contacts;
        this.session = data.session;
        this.isWhatsapp = this.session && this.session.ChannelType == 'WhatsApp';
    }

    success() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Éxito',
            message: 'Se han guardado los cambios',
            variant: 'success',
        }));
    }

    save() {
        const inputs = this.template.querySelectorAll('lightning-input');
        
        for (let i = 0; i < this.contacts.length; i++) {
            this.contacts[i].Contacto_Usuario_Mensajeria__c = inputs[i].checked;
        }

        this.loading = true;
        saveRecords({contacts: this.contacts}).then(_ => getRecordNotifyChange(this.contacts.map(c => ({recordId: c.Id})))).then(_ => this.success()).catch(e => this.onError(e)).finally(_ => this.loading = false);;
    }

    get title() {
        if (this.contacts.length == 0) return this.isWhatsapp ? 'El teléfono está vacío' : 'El email está vacío';
        return this.isWhatsapp ? this.contacts[0].MobilePhone : this.contacts[0].Email;
    }

    get cantSave() {
        return this.session.Status == 'Ended' || this.contacts.length == 0;
    }
}