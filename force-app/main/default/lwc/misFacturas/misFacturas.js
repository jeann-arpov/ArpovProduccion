import { LightningElement, track, api } from 'lwc';
import getVencimientos from '@salesforce/apex/MisFacturasController.getVencimientos';
//import getPaymentLink from '@salesforce/apex/AgroPagoAuraController_V2.getPaymentLink';
import getAgroPago from '@salesforce/apex/AgroPagoAuraController.getAgroPago';
import {reduceErrors, normalizeCuit} from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
//import basePath from '@salesforce/community/basePath';
import { doRequest } from 'c/utils';
import icons from 'c/icons';

const COLUMNS = [
    {label: 'CUIT', fieldName: 'cuit', fixedWidth: 100, hideDefaultActions: true},
    {label: 'NOMBRE CUENTA', fieldName: 'cuentaName', fixedWidth: 200, hideDefaultActions: true},
    {label: 'CULTIVO', fieldName: 'cultivo', fixedWidth: 100, hideDefaultActions: true},
    {label: 'NRO COMPROBANTE', fieldName: 'numero', fixedWidth: 180, hideDefaultActions: true},
    {label: 'MARCA', fieldName: 'obtentorMarca', fixedWidth: 100, hideDefaultActions: true},
   // {label: 'Comercio', fieldName: 'comercio', hideDefaultActions: true},
    {label: 'FECHA EMISION', fieldName: 'fecha', type: 'date', fixedWidth: 150, sortable: true, hideDefaultActions: true},
    {label: 'IMPORTE (USD)', fieldName: 'total', type: 'currency', fixedWidth: 120, sortable: true, hideDefaultActions: true},
    {label: 'FECHA VENCIMIENTO', fieldName: 'fechaVencimiento', type: 'date', fixedWidth: 150, sortable: true, hideDefaultActions: true},
    //{label: 'Saldo USD', fieldName: 'saldo', type: 'currency', sortable: true, hideDefaultActions: true},
    //{label: 'SALDO ARS', fieldName: 'saldoArs', type: 'currency', sortable: true, fixedWidth: 100, hideDefaultActions: true},
    {label: 'ESTADO', fieldName: 'oppStage', fixedWidth: 150, hideDefaultActions: true },
    {type: 'button-icon', typeAttributes: {alternativeText: 'Ver Factura', iconName: 'utility:file' , fixedWidth: 100, name: 'Ver', class:{fieldName:'iconoClass'}, title: 'Ver', disabled: {fieldName: 'disableVerFactura'}}},
    // {type: 'button', typeAttributes: {label: 'Pagar', name: 'Pagar', title: 'Pagar', disabled: {fieldName: 'disablePagar'}}},
    {type: 'button', typeAttributes: {label: 'Informar Pago', name: 'Informar Pago', variant: 'brand', title: 'Informar Pago', fixedWidth: 100, disabled: {fieldName: 'disableInfPago'}}}
];

export default class MisFacturas extends LightningElement {
    @api type;

    @track vencimientos = [];
    columns = COLUMNS;
    cultivos;
    cultivo = 'Todos';
    marca = 'Todas';
    estado = 'Todos';

    @track sortBy = 'fecha';
    @track sortDirection = 'desc';
    @track searchTerm = '';
    @track totalRegistros = 0; // <<--- Nuevo
    @track selectedCultivo = '';
    @track selectedMarca = '';
    @track selectedEstado = '';

    pageSize = 200;
    @track currentPage = 1;
    @track filteredFacturas = [];
    @track data = [];


    icons = {
        seed: icons.pph.seed
    };
    
    agropago;
    vencimientoPagar;

    initialized = false;
    loading = false;

    async init() {
        this.initialized = true;
console.log('init', this.type);
        await doRequest.call(this, async _ => {
            this.agropago = await getAgroPago();
            const vencimientos = await getVencimientos({type: this.type});
            console.log(JSON.stringify(vencimientos));
            let idx = 0;
            for(let vencimiento of vencimientos){
                console.log(vencimiento);
                // vencimiento.disablePagar = !vencimiento.id || !this.isProductor;
                vencimiento.disableInfPago = !(vencimiento.oppStage == 'Facturada' || vencimiento.oppStage == 'Pedido de Facturacion');
                if(vencimiento.file == null && vencimiento.facturaPVId) vencimiento.file = {id: vencimiento.facturaPVId};
                vencimiento.disableVerFactura = !vencimiento.file;
                vencimiento.iconoClass = !vencimiento.file ? 'icono-disabled' : 'icono';
                if(vencimiento.id == null) vencimiento.id = vencimiento.numero;
                vencimiento.uniqueId = idx;
                idx++;
            }
            
            this.vencimientos = vencimientos;

            const cultivos = [{label: 'Cultivo: Todos', value: 'Todos'}];

            for(let vencimiento of this.vencimientos){
                if(!cultivos.some(o => o.value == vencimiento.cultivo)) cultivos.push({label: `Cultivo: ${vencimiento.cultivo}`, value: vencimiento.cultivo});
            }

            this.cultivos = cultivos;

            this.applyFilters();
        });
    }

    get isProductor() {
        return this.type == "Productor";
    }

    byFechaVencimiento(a, b){
        if(a.fechaVencimiento > b.fechaVencimiento) return 1;
        if(a.fechaVencimiento < b.fechaVencimiento) return -1;
        return 0;
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

    //reemplazando vencimientos por data, podemos hacer que los totales sean dinámicos según que facturas se esten visualizando
    get totalAdeudado() {
        return this.vencimientos.reduce((tot, cur) => tot + (cur.saldo || 0), 0);
    }

    get totales(){
        const totales = [];
        const porCultivo = {};

        for(const vencimiento of this.vencimientos){
            const key = vencimiento.cultivo;
            porCultivo[key] = porCultivo[key] || {key, value: 0};
            porCultivo[key].value += (vencimiento.saldo || 0);
        }

        for(const cultivo in porCultivo){
            totales.push({cultivo: cultivo, label: `Adeudado ${cultivo} USD`, value: porCultivo[cultivo].value});
        }

        console.log('totales: ', totales);

        return totales;
    }

    handleOnInformarPagoClick(vencimiento){
        //const vencimiento = this.vencimientos.find((ven) => ven.id == event.target.dataset.id);

        this.template.querySelector('c-informar-pago').show({
            title:'Informar Pago',
            recordId:vencimiento.opportunityId,
            cuit: vencimiento.cuit,
            comprobante: vencimiento.numero
        });
    }

    handleOnPayClickConfirm(vencimiento){
        this.vencimientoPagar = vencimiento
        console.log(this.vencimientoPagar);

        this.template.querySelector('c-modal').show();
    }

    handleOnSort(event){
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData();
    }

    applySort(list) {
        const sorted = [...list];
        const isReverse = this.sortDirection === 'asc' ? 1 : -1;
        sorted.sort((x, y) => {
            const a = x[this.sortBy] ?? '';
            const b = y[this.sortBy] ?? '';
            return isReverse * ((a > b) - (b > a));
        });
        return sorted;
    }

    sortData() {
        this.filteredFacturas = this.applySort(this.filteredFacturas);
        this.updatePage();
    }

    handleRowAction(event){
        const action = event.detail.action;
        const row = event.detail.row;
        switch (action.name) {
            case 'Ver':
                this.showPdf(row);
                break;
            case 'Pagar':
                this.handleOnPayClickConfirm(row);
                break;
            case 'Informar Pago':
                this.handleOnInformarPagoClick(row);
                break;
            default:
                break;
        }
    }

    handleCultivoSelect(event){
        this.cultivo = event.target.value;
        this.selectedCultivo = event.target.value;
        this.applyFilters();
    }

    handleMarcaSelect(event){
        this.marca = event.target.value;
        this.selectedMarca = event.target.value;
        this.applyFilters();
    }

    handleEstadoSelect(event){
        this.estado = event.target.value;
        this.selectedEstado = event.target.value;
        this.applyFilters();
    }

    closeModal(){
        this.template.querySelector('c-modal').hide();
    }

    // Aplicar filtros y búsqueda
    
    applyFilters() {
        let filtered = [...this.vencimientos];

        if (this.selectedCultivo && this.selectedCultivo !== 'Todos') {
            filtered = filtered.filter(l => l.cultivo === this.selectedCultivo);
        }
        if (this.selectedMarca && this.selectedMarca !== 'Todas') {
            filtered = filtered.filter(l => l.obtentorMarca === this.selectedMarca);
        }
        if (this.selectedEstado && this.selectedEstado !== 'Todos') {
            filtered = filtered.filter(l => l.oppStage === this.selectedEstado);
        }

        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            const searchKeyNorm = normalizeCuit(term);
            filtered = filtered.filter(l =>
                (l.cultivo && l.cultivo.toLowerCase().includes(term)) ||
                (l.obtentorMarca && l.obtentorMarca.toLowerCase().includes(term)) ||
                (l.cuentaName && l.cuentaName.toLowerCase().includes(term)) ||
                (l.numero && l.numero.toLowerCase().includes(term)) ||
                (searchKeyNorm && l.cuit && l.cuit.toLowerCase().includes(searchKeyNorm))
            );
        }

        this.filteredFacturas = this.applySort(filtered);
        this.totalRegistros = this.filteredFacturas.length;
        this.currentPage = 1;
        this.updatePage();
    }

    updatePage() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.data = this.filteredFacturas.slice(start, end);
    }

    get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= Math.ceil(this.filteredFacturas.length / this.pageSize);
    }

    handlePrev() {
        if (!this.disablePrev) {
            this.currentPage--;
            this.updatePage();
        }
    }

    handleNext() {
        if (!this.disableNext) {
            this.currentPage++;
            this.updatePage();
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.applyFilters();
    }

    // async handleOnPayClick(){
    //     this.closeModal();

    //     const url = this.vencimientoPagar.linkDePago || await this.getNewPaymentLink(this.vencimientoPagar);

    //     if(url) window.open(url, '_self');
    // }

    // async getNewPaymentLink(vencimiento){
    //     let paymentLink;

    //     const urlRedirect = `https://${location.host}${basePath}/agropago-redirect`;
        
    //     await doRequest.call(this, async _ => {
    //         const result = await getPaymentLink({recordId: vencimiento.id, urlRedirect: urlRedirect});
    //         console.log(result);
    //         if(result.url){
    //             paymentLink = result.url;
    //         }else{
    //             this.onError(new Error(`Error ${result.code}: ${result.message}`));
    //         }
    //     });

    //     return paymentLink;
    // }

    showPdf(vencimiento){
        //const vencimiento = this.vencimientos.find((ven) => ven.id == event.target.dataset.id);

        this.template.querySelector('c-pdf-reader').show({
            documentId:vencimiento.file.id,
            title:'Factura Eléctronica'
        });
    }

    onPaymentApproved(event) {
        this.init();
    }

    // get totalAPagar(){
    //     return this.vencimientoPagar.saldoArs / (1 - (this.agropago.Comision__c || 0) / 100);
    // }

    // get comision(){
    //     return this.totalAPagar - this.vencimientoPagar.saldoArs;
    // }

    get marcas(){
        const options = [{label: 'Marca: Todas', value: 'Todas'}];
        const vencimientos = !this.cultivo || this.cultivo == 'Todos' ? this.vencimientos : this.vencimientos.filter(v => v.cultivo == this.cultivo);
        for(let vencimiento of vencimientos){
            if(!options.some(m => m.value == vencimiento.obtentorMarca)){
                options.push({label: `Marca: ${vencimiento.obtentorMarca}`, value: vencimiento.obtentorMarca});
            }
        }
        return options;
    }

    get estados(){
        const options = [{label: 'Estado: Todos', value: 'Todos'}];
        for(let vencimiento of this.vencimientos){
            if(vencimiento.oppStage && !options.some(o => o.value == vencimiento.oppStage)){
                options.push({label: `Estado: ${vencimiento.oppStage}`, value: vencimiento.oppStage});
            }
        }
        return options;
    }
}