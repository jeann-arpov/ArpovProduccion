import { LightningElement } from 'lwc';
import SVG_ICONS from '@salesforce/resourceUrl/iconos_SE';
import { NavigationMixin } from 'lightning/navigation';
import hasHT from '@salesforce/apex/AdhesionPPH.hasHT';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {reduceErrors} from 'c/utils';

export default class IniciarPph extends NavigationMixin(LightningElement) {
    initialized = false;
    loaded = false;
    hasHTs;

    icons = {
        'file': SVG_ICONS + '/iconos/venta/Icon-feather-file.svg#Icon_feather-file',
        'arrow': SVG_ICONS + '/iconos/font-awesome/right-arrow.svg#right-arrow'
    }

    async init() {
        this.initialized = true;
        
        try {
            this.hasHTs = await hasHT();
            this.loaded = true;
        } catch (e) {
            this.onError(e);
        }
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    redirectAdhesion(e) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
            pageName: 'pre-certificacion',
            }
        })
    }

    redirectComprar(e) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'FormularioNuevaVentaHT',
            }
        })
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
            mode: 'sticky'
        }));
    }
}