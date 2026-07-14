import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import {reduceErrors, doRequest} from 'c/utils';
import searchLicenciatarios from '@salesforce/apex/ConsultaLicenciasController.searchLicenciatarios';
import getLicencias from '@salesforce/apex/ConsultaLicenciasController.getLicenciasLicenciatario';
import getAccount from '@salesforce/apex/ConsultaLicenciasController.getAccount';

export default class ConsultaLicenciasLicenciatario extends NavigationMixin(LightningElement) {
    processing = false;
    licencias = [];
    initialized = false;
    account;

    licencia;

    async init() {
        this.initialized = true;
        this.doRequest = doRequest.bind(this);

        this.doRequest(async _ => {
            this.account = await getAccount();
        });
    }

    async search(event) {
        const lookup = event.target;
        await searchLicenciatarios(event.detail).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
            mode: 'sticky'
        }));
    }

    async updateLicencias(event) {
        if (!event.detail[0]) {
            this.licencias = [];
            return;
        }
        
        this.processing = true;
        
        try {
            this.licencias = await getLicencias({licenciatarioId: event.detail[0]});

            this.licencias.forEach(l => {
                console.log(l.Cuenta_Distribuidor__c + ' - ' + this.account.Id);
                console.log(l.Cuenta_Obtentor__c + ' - ' + this.account.Id);
                console.log(l.Origen__c);
                l.puedeGestionar = (l.Cuenta_Distribuidor__c == this.account.Id || l.Cuenta_Obtentor__c == this.account.Id) && l.Origen__c == 'Portal';
            });
        } catch (e) {
            this.onError(e);
        }

        this.processing = false;
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    gestionar(e) {
        const recordId = e.target.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'solicitar-licencia'
            },
            state: {
                recordId
            }
        });
    }

    verLicencia(event){
        const recordId = event.target.dataset.id;
        this.licencia = this.licencias.find(l => l.Id == recordId);
    }

    ocultarLicencia(){
        this.licencia = null;
    }
}