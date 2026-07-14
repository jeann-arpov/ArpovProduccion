import { LightningElement, api, wire } from 'lwc';
import { doRequest, errorEvent } from 'c/utils';
import { getRecord, updateRecord } from "lightning/uiRecordApi";

import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import CAMPO_ID from '@salesforce/schema/Licencia__c.Id';
import CAMPO_FECHA_RECHAZO from '@salesforce/schema/Licencia__c.Fecha_de_Rechazo__c';
import CAMPO_ESTADO from '@salesforce/schema/Licencia__c.Estado__c';
import CAMPO_MOTIVO_RECHAZO from '@salesforce/schema/Licencia__c.Motivo_del_Rechazo__c';

export default class RechazarLicenciaObtentor extends LightningElement {

    @api recordId;

    initialized = false;
    licencia;
    motivoRechazo;
    loading = false;

    @wire(getRecord, { recordId: "$recordId", fields: [CAMPO_ESTADO]})
    getLicencia({error, data}){
        if(data){
            console.log(data);
            this.licencia = data;
        }else if(error) console.log(error);
    }

    handleMotivoRechazo(event){
        this.motivoRechazo = event.detail.value;
    }

    openModal(){
        if(this.puedeRechazar){
            this.template.querySelector('c-modal').show();
        }else{
            this.onError(new Error('No puede rechazar una licencia ' + this.estadoLicencia));
        }
    }

    closeModal(){
        this.template.querySelector('c-modal').hide();
    }

    async confirm(event){
        if(this.motivoRechazo){
            const fields = {};
    
            fields[CAMPO_ID.fieldApiName] = this.recordId;
            fields[CAMPO_FECHA_RECHAZO.fieldApiName] = new Date().toISOString();
            fields[CAMPO_ESTADO.fieldApiName] = 'Rechazada';
            fields[CAMPO_MOTIVO_RECHAZO.fieldApiName] = this.motivoRechazo;

            const recordInput = { fields };

            await doRequest.call(this, async _ =>{
                await updateRecord(recordInput);
                await notifyRecordUpdateAvailable([this.recordId]);
                this.closeModal();
            });
            
        }else{
            const input = this.template.querySelector('lightning-textarea');
            input.setCustomValidity('Tiene que ingresar un motivo');
            input.reportValidity();
        }
    }

    renderedCallback(){
        console.log(this.recordId);
        console.log(this.licencia);
    }

    onError(error){
        this.dispatchEvent(errorEvent(error));
    }
    
    get estadoLicencia(){
        return this.licencia.fields.Estado__c.value;
    }

    get puedeRechazar(){
        return ['Creada', 'A validar', 'Validada', 'Licencia Firmada'].includes(this.estadoLicencia);
    }
}