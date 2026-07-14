import { LightningElement, api } from 'lwc';
import rectificarAdhesion2 from '@salesforce/apex/AdhesionPPH.rectificarAdhesion2';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { NavigationMixin } from 'lightning/navigation';
import {errorEvent} from 'c/utils';

export default class RectificarPph extends NavigationMixin(LightningElement) {
    @api recordId;
    isExecuting = false;

    @api async invoke() {
        if (this.isExecuting) {
            return;
        }

        this.dispatchEvent(new ShowToastEvent({
            message: 'Realizando la rectificación',
        }));

        this.isExecuting = true;
        const newPlanId = await rectificarAdhesion2({planId: this.recordId}).catch(e => this.dispatchEvent(errorEvent(e)));
        this.isExecuting = false;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: newPlanId,
                actionName: 'view'
            }
        });
    }
}