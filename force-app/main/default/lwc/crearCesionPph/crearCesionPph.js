import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CrearCesionPph extends NavigationMixin(LightningElement)  {

    redirect(event) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'cesion-pph'
            },
            state: {
                recordId: 'new',
                type: event.target.dataset.name
            }
        });
    }
}