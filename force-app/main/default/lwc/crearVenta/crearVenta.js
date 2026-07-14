import { LightningElement,track, api } from 'lwc';
import {CompraVentaMixin} from 'c/utilsHT';
import searchProductores from '@salesforce/apex/CrearVentaController.searchProductores';
import getData from '@salesforce/apex/CrearVentaController.getData';
import finalizarVenta from '@salesforce/apex/CrearVentaController.finalizarVenta';
import anular from '@salesforce/apex/CrearVentaController.anular';
/*import crearCVS from '@salesforce/apex/CrearVentaController.crearCVS';
import generarFE from '@salesforce/apex/CrearVentaController.generarFE';
import generarPDF from '@salesforce/apex/CrearVentaController.generarPDF';*/
import getSemilleroData from '@salesforce/apex/CrearVentaController.getSemilleroData';
import getProductsData from '@salesforce/apex/CrearVentaController.getProductsData';
import { NavigationMixin } from 'lightning/navigation';
import basePath from '@salesforce/community/basePath';


export default class CrearVenta extends CompraVentaMixin(LightningElement) {
    productor;
  //  @track showFinanciamientoColumn = false;
    
    getData(isFirstLoad) {
        return getData({ventaId: this.recordId, isFirstLoad});
     }
 
     setData(data) {
         this.setDataAndItems(data, data.record ? data.record.Lineas_de_Venta_HT__r : null);
         this.productor = data.record ? data.record.Cuenta_Productor__r : null;
         
     }
 
     get pageRecordId() {
         if (window.location.href.includes('venta-ht/') && !window.location.href.includes('venta-ht/Venta_HT__c/')) return window.location.href.split('venta-ht/')[1].split('/')[0];
         return new URL(window.location.href).searchParams.get("recordId");
     }

     get community() {
        return 'Venta';
    }

    get isPortalObtentor(){
        return basePath.includes('Obtentor');
    }
    get cultivoNombre() {
        const seleccionado = (this.cultivos || []).find(c => c.value === this.cultivo);
        return seleccionado ? seleccionado.label : '';
    }


    addRow(event) {
        const rows = Array.from(this.template.querySelectorAll('c-crear-linea-venta'));
        if (rows.length && this.productor == null && !this.data.record) return this.onError('Debe seleccionar un productor');
        this.addRowInternal(rows);
    }

    saveRow(event) {
        if (this.productor == null && !this.data.record) return this.onError('Debe seleccionar un productor');
        event.target.save(this.recordId, this.cultivo, this.productor.Id);
    }

    productorSelected(event) {
        const selection = event.target.getSelection();
        this.productor = selection.length ? selection[0].record : null;
        this.getProductos();
    }

    get hasOperadorCobranza() {
        return this.productor && this.productor.Operador_de_Cobranza__r != null;
    }

    async finalizar(event) {
        if (this.isChildrenLoading) return this.onError('Espere a que se termine de guardar la línea');
        await this.requestWrap(async () => {
            const data = await finalizarVenta({ventaId: this.recordId, checkDuplicates: this.recordId != this.lastDuplicateCheckId});
            if (data.duplicate) return this.notifyDuplicate();
            this.setData(data);
            if (this.puedeFacturar) await this.facturar();
            this.currentModal = data.pendiente ? "pendiente" : "finalizada";
        });
    }

    notifyDuplicate() {
        this.currentModal = "duplicate-venta";
        this.lastDuplicateCheckId = this.recordId;
    }

    async anular(event) {
        await this.requestWrap(async () => {
            const data = await anular({ventaId: this.recordId});
            this.setData(data);
            this.currentModal = null;
            this.redirectPendientesFacturacion();
        });
    }

    async search(event) {
        const lookup = event.target;
        await searchProductores(event.detail).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }
    /*
    crearCVS() {
        return crearCVS({ventaId: this.recordId});
    }

    generarFE(cvId) {
        return generarFE({ventaId: this.recordId, cvId});
    }

    generarPDF(cvId) {
        return generarPDF({ventaId: this.recordId, cvId});
    }*/

    getSemilleroData() {
        return getSemilleroData({obtentorId: this.semillero, productorId: this.productor.Id});
    }

    get productorMissing() {
        return this.productor == null;
    }

    async getProductos(){
        await this.requestWrap(async () => {
            const products = await getProductsData({cultivoId: this.cultivo, productorId: this.productor.Id});
            console.log('Products recibidos:', products); 
            console.log('Primer producto Unit_Price__c:', products[0]?.Unit_Price__c); 
            this.updateVariedades(products);
        });
    }
    handleTipoHtChange(event) {

        const { isFutura } = event.detail;
        console.log('isFutura extraído:', isFutura);
        //this.showFinanciamientoColumn = isFutura && this.cultivoName === 'SOJA';

    }
   

    
}