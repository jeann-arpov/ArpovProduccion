import { LightningElement, api } from 'lwc';
import generarPDFLicenciaInterna from '@salesforce/apex/SolicitarLicencia.generarPDFLicenciaInterna';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import {errorEvent} from 'c/utils';
export default class GenerarLicenciaInterna extends LightningElement {
    @api recordId;
    isExecuting = false;

    @api async invoke(){
        if (this.isExecuting) {
            return;
        }

        this.dispatchEvent(new ShowToastEvent({
            message: 'Generando PDF',
        }));

        this.isExecuting = true;

        try {
            await generarPDFLicenciaInterna({licenciaId: this.recordId});
            window.location.reload();
        } catch (error) {
            this.dispatchEvent(errorEvent(error));
        }

        this.isExecuting = false;
    }
}