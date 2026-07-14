import { LightningElement, track} from 'lwc';
import getData from '@salesforce/apex/CrearCompraController.getData';
import finalizarCompra from '@salesforce/apex/CrearCompraController.finalizarCompra';
import anular from '@salesforce/apex/CrearCompraController.anular';
/*import crearCVS from '@salesforce/apex/CrearCompraController.crearCVS';
import generarFE from '@salesforce/apex/CrearCompraController.generarFE';
import generarPDF from '@salesforce/apex/CrearCompraController.generarPDF';*/
import getSemilleroData from '@salesforce/apex/CrearCompraController.getSemilleroData';
import getProductsData from '@salesforce/apex/CrearCompraController.getProductsData';
import {CompraVentaMixin} from 'c/utilsHT';
import { NavigationMixin } from 'lightning/navigation';

export default class CrearCompra extends CompraVentaMixin(LightningElement) {
    showFacturaRegaliaEnlistMsg;
    @track showFinanciamientoColumn = false;

    get showFinanciamientoColumn() {
        return this.preCampaign === 'Futura';
    }

    getData(isFirstLoad) {
       return getData({compraId: this.recordId, isFirstLoad});
    }

    setData(data) {
        this.setDataAndItems(data, data.record ? data.record.Lineas_de_Compra_HT__r : null);
    }

    get pageRecordId() {
        if (window.location.href.includes('compra-ht/') && !window.location.href.includes('compra-ht/Compra_HT__c/')) return window.location.href.split('compra-ht/')[1].split('/')[0];
        return new URL(window.location.href).searchParams.get("recordId");
    }

    get parametroCultivo() {
        const parametro = new URL(window.location.href).searchParams.get("cultivoId");
        return parametro;
    }

    get community() {
        return 'Compra';
    }

    addRow(event) {
        this.addRowInternal(Array.from(this.template.querySelectorAll('c-crear-linea-compra')));
    }

    saveRow(event) {
        event.target.save(this.recordId, this.cultivo);
    }

    async finalizar(event) {
        if (this.isChildrenLoading) return this.onError('Espere a que se termine de guardar la línea');
        await this.requestWrap(async () => {
            const data = await finalizarCompra({compraId: this.recordId, checkDuplicates: this.recordId != this.lastDuplicateCheckId});
            if (data.duplicate) return this.notifyDuplicate();
            this.setData(data);
            if (this.puedeFacturar) await this.facturar();
            this.showFacturaRegaliaEnlistMsg = data.record.Lineas_de_Compra_HT__r.some(linea => ['Enlist E3', 'Conkesta E3'].includes(linea.Producto__r.Variedad2__r.Biotecnologia__c));
            this.currentModal = data.pendiente ? "pendiente" : "finalizada";
        });
    }

    notifyDuplicate() {
        this.currentModal = "duplicate-compra";
        this.lastDuplicateCheckId = this.recordId;
    }

    async anular(event) {
        await this.requestWrap(async () => {
            const data = await anular({compraId: this.recordId});
            this.setData(data);
            this.currentModal = null;
            this.redirectPendientesFacturacion();
        });
    }
    /*
    crearCVS() {
        return crearCVS({compraId: this.recordId});
    }

    generarFE(cvId) {
        return generarFE({compraId: this.recordId, cvId});
    }

    generarPDF(cvId) {
        return generarPDF({compraId: this.recordId, cvId});
    }*/

    getSemilleroData() {
        return getSemilleroData({obtentorId: this.semillero});
    }

    async getProductos(){
        await this.requestWrap(async () => {
            const products = await getProductsData({cultivoId: this.cultivo});
            this.updateVariedades(products);
        });
    }

    handleTipoHtChange(event) {
    const { isFutura } = event.detail;
    
    // //Pre Campaña
    if (isFutura) {
        //this.showFinanciamientoColumn = true;
    } else {
        const template = this.template;
        const lineaCompras = template.querySelectorAll('c-crear-linea-compra');
        const hayFuturas = Array.from(lineaCompras).some(componente => {
            return componente.preCampaign === 'Futura';
        });
      //  this.showFinanciamientoColumn = hayFuturas;
    }
}
}