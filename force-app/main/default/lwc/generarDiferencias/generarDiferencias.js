import { LightningElement, api } from 'lwc';
import generarDiferencias from '@salesforce/apex/GenerarDiferenciasController.generarDiferencias';
import facturar from '@salesforce/apex/GenerarDiferenciasController.facturar';
import agregarDocumentosAfectados from '@salesforce/apex/GenerarDiferenciasController.agregarDocumentosAfectados';
import {reduceErrors} from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class GenerarDiferencias extends LightningElement {
    progress = 0;
    text = "Generando Diferencias";
    @api recordId;
    @api ids;

    async init() {
        this.initialized = true;
        
        try {
            const cvs = await generarDiferencias({movimientos: this.recordIds});

            let done = 1;
            let total = 2 + cvs.length;

            this.progress = done * 100 / total;

            for (const cv of cvs) {
                this.text = "Generando factura de " + cv.Nro_Comprobante__c;
                await facturar({cvId: cv.Id});
                done++
                this.progress = done * 100 / total;
            }

            this.text = "Agregando documentos afectados";
            if (cvs.length)  await agregarDocumentosAfectados({cvIds: cvs.map(cv => cv.Id)});
            this.progress = 100;
            this.text = "Listo";
        } catch (e) {
            this.onError(e);
        }
    }

    get recordIds() {
        if (this.ids) return this.ids.split(',');
        return [this.recordId];
    }

    renderedCallback() {
        if (!this.initialized && (this.recordId || this.ids)) this.init();
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