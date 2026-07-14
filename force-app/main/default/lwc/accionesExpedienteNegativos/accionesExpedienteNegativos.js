import { LightningElement, api } from 'lwc';
import getExpedienteNegativosById from '@salesforce/apex/ExpedienteNegativo.getExpedienteNegativosById';
import facturarRegaliaEnlist from '@salesforce/apex/ExpedienteNegativo.facturarRegaliaEnlist';
import cerrarExpediente from '@salesforce/apex/ExpedienteNegativo.cerrarExpediente';
import { doRequest, errorEvent } from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
export default class AccionesExpedienteNegativos extends LightningElement {

    expediente;

    processing;

    _recordId;

    @api set recordId(value){
        this._recordId = value;
        getExpedienteNegativosById({recordId: this._recordId}).then(expediente => this.expediente = expediente).catch(err => this.onError(err));
    }

    get recordId(){
        return this._recordId;
    }

    facturarRegaliaEnlist(){
        this.template.querySelector('c-modal').show();
    }

    async confirmFacturarRegaliaEnlist(){
        this.closeModal();
        await doRequest.call(this, async _=> {
            this.processing = true;
            await facturarRegaliaEnlist({expedienteId: this.expediente.Id});
            this.showMessage('', `Se facturaron las regalías Enlist para el expediente ${this.expediente.Name}`, 'success');
            notifyRecordUpdateAvailable([{recordId: this.expediente.Id}]);
            this.processing = false;
        });
    }

    async cerrarExpediente(){
        await doRequest.call(this, async _ => {
            this.processing = true;
            await cerrarExpediente({expedienteId: this.expediente.Id});
            this.showMessage('', `El expediente ${this.expediente.Name} fue cerrado`);
            notifyRecordUpdateAvailable([{recordId: this.expediente.Id}]);
            this.processing = false;
        });
    }

    closeModal(){
        this.template.querySelector('c-modal').hide();
    }

    showMessage(title, message, variant){
        this.dispatchEvent(new ShowToastEvent({title, message, variant}));
    }

    onError(error){
        this.dispatchEvent(errorEvent(error));
        this.processing = false;
    }
}