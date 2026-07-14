import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SolicitarLicenciaButton2 extends NavigationMixin(LightningElement) {

    redirect(){
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: 'https://phazp0897appwebgui.azurewebsites.net/'
            }
        },
        true // Replaces the current page in your browser history with the URL
      );
    }
}