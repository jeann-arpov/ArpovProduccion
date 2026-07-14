import { LightningElement } from 'lwc';
import getData from '@salesforce/apex/MisAsientosContablesController.getData';
import {reduceErrors} from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MisAsientos extends LightningElement {
    initialized = false;
    processing = true;
    asientos = [];
    fechaDesde;
    fechaHasta = new Date().toISOString();
    saldoInicial;
    saldoInicialMO;
    saldoFinal;
    saldoFinalMO;

    init() {
        this.initialized = true;
        const dt = new Date();
        dt.setMonth(dt.getMonth() - 6);
        this.fechaDesde = dt.toISOString();
        this.getData();
    }

    async getData() {
        this.processing = true;

        try {
            const data = await getData({desde: this.fechaDesde, hasta: this.fechaHasta});
            
            this.asientos = data.asientos;
            this.totales = data.totales;
            this.summarize();
        } catch (e) {
            this.onError(e);
        }

        this.processing = false;
    }

    summarize() {
        this.saldoInicial = this.totales.length ? this.totales[0].debe || 0 - this.totales[0].haber || 0 : 0;
        this.saldoInicialMO = this.totales.length ? this.totales[0].debeMO || 0 - this.totales[0].haberMO || 0 : 0;

        this.saldoFinal = this.asientos.reduce((tot, cur) => cur.debe - cur.haber + tot, 0) + this.saldoInicial;
        this.saldoFinalMO = this.asientos.reduce((tot, cur) => cur.debeMO - cur.haberMO + tot, 0) + this.saldoInicialMO;

        console.log(this.saldoFinal, this.saldoFinalMO, this.saldoInicial, this.saldoInicialMO)
    }

    changeFechaDesde(event) {
        this.fechaDesde = event.detail.value;
        this.getData();
    }

    changeFechaHasta(event) {
        this.fechaHasta = event.detail.value;
        this.getData();
    }
    
    renderedCallback() {
        if (!this.initialized) this.init();
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
            mode: 'sticky'
        }));
    }

    showPdf(event){
        const asiento = this.asientos.find((asiento) => asiento.id == event.target.dataset.id);

        this.template.querySelector('c-pdf-reader').show({
            documentId:asiento.file.id,
            title:'Factura Eléctronica'
        });
    }
}