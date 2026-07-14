import { LightningElement, api } from 'lwc';
import validateRecord from '@salesforce/apex/CesionPPH.validateRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import {errorEvent} from 'c/utils';

export default class ValidarCesionPph extends LightningElement {
    @api recordId;
    isExecuting = false;

    @api async invoke() {
        if (this.isExecuting) {
            return;
        }

        this.dispatchEvent(new ShowToastEvent({
            message: 'Realizando la validación',
        }));

        this.isExecuting = true;

        try {
            await validateRecord({recordId: this.recordId});

            this.dispatchEvent(new ShowToastEvent({
                message: 'Se ha realizado la validación',
                variant: 'success'
            }));

            notifyRecordUpdateAvailable([{recordId: this.recordId}]);
        } catch (e) {
            this.dispatchEvent(errorEvent(e));
        }

        this.isExecuting = false;
    }
}