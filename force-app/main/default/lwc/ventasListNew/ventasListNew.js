import { LightningElement, track, wire } from 'lwc';
import getVentas from '@salesforce/apex/VentaListController.getVentas';
import getVentasHT from '@salesforce/apex/VentaListController.getVentasHT';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';

export default class VentasListNew extends LightningElement {
    // ======== Ventas ========
    @track ventas = [];
    @track filteredVentas = [];
    @track searchKey = '';
    @track currentPage = 1;
    pageSize = 10;

    // ======== Ventas HT ========
    @track ventasHT = [];
    @track filteredVentasHT = [];
    @track searchKeyHT = '';
    @track currentPageHT = 1;
    pageSizeHT = 10;

    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    // ======== WIRE VENTAS ========
    @wire(getVentas)
    wiredVentas({ data, error }) {
        if (data) {
            
            this.ventas = data.map(v => ({
                id: v.Id,
                name: v.Name,
                Destinatario__c: v.Destinatario__r?.Name,
                Destinatario_CUIT__c: v.Destinatario_CUIT__c,
                fecha: v.Fecha__c,
                estado: v.Estado__c,
                cultivo: v.Variedad__c,
                variedad: v.Variedad__r?.Name,
                producto: v.Producto__r?.Name,
                comercio: v.Originante__r?.Name,
                productor: v.Destinatario__r?.Name,
                cantidad: v.Cantidad__c,
                canal: v.Canal__c
            }));
            this.filteredVentas = [...this.ventas];
        } else if (error) {
            console.error('Error cargando ventas', error);
        }
    }

    // ======== WIRE VENTAS HT ========
    @wire(getVentasHT)
    wiredVentasHT({ data, error }) {
        console.log('data', JSON.stringify(data))
        if (data) {
            this.ventasHT = data.map(v => ({
                id: v.Id,
                name: v.Name,
                CUIT_Productor__c: v.CUIT_Productor__c,
                fecha: v.CreatedDate,
                estado: v.Estado__c,
                cultivo: v.Cultivo__r?.Name,
                productor: v.Cuenta_Productor__r.Name,
                comercio: v.Comercio__r?.Name,
                totalHT: v.Total_HT__c,
                totalUSD: v.Total_USD__c
            }));
            this.filteredVentasHT = [...this.ventasHT];
        } else if (error) {
            console.error('Error cargando ventas HT', error);
        }
    }

    // ======== GETTERS VENTAS ========
    get totalRegistros() {
        return this.filteredVentas.length;
    }
    get paginatedVentas() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.filteredVentas.slice(start, start + this.pageSize);
    }
    get disablePrev() {
        return this.currentPage === 1;
    }
    get disableNext() {
        return this.currentPage * this.pageSize >= this.filteredVentas.length;
    }

    // ======== GETTERS VENTAS HT ========
    get totalRegistrosHT() {
        return this.filteredVentasHT.length;
    }
    get paginatedVentasHT() {
        const start = (this.currentPageHT - 1) * this.pageSizeHT;
        return this.filteredVentasHT.slice(start, start + this.pageSizeHT);
    }
    get disablePrevHT() {
        return this.currentPageHT === 1;
    }
    get disableNextHT() {
        return this.currentPageHT * this.pageSizeHT >= this.filteredVentasHT.length;
    }

    // ======== HANDLERS VENTAS ========
    handleSearchChange(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.filteredVentas = this.ventas.filter(v =>
            (v.name && v.name.toLowerCase().includes(this.searchKey)) ||
            (v.Destinatario_CUIT__c && v.Destinatario_CUIT__c.toLowerCase().includes(this.searchKey)) ||
            (v.Destinatario__c && v.Destinatario__c.toLowerCase().includes(this.searchKey)) ||
            (v.comercio && v.comercio.toLowerCase().includes(this.searchKey)) ||
            (v.productor && v.productor.toLowerCase().includes(this.searchKey))
        );
    }
    handleNext() {
        if (this.currentPage * this.pageSize < this.filteredVentas.length) {
            this.currentPage++;
        }
    }
    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    // ======== HANDLERS VENTAS HT ========
    handleSearchChangeHT(event) {
        this.searchKeyHT = event.target.value.toLowerCase();
        this.filteredVentasHT = this.ventasHT.filter(v =>
            (v.CUIT_Productor__c && v.CUIT_Productor__c.toLowerCase().includes(this.searchKeyHT)) ||
            (v.name && v.name.toLowerCase().includes(this.searchKeyHT)) ||
            (v.name && v.name.toLowerCase().includes(this.searchKeyHT)) ||
            (v.comercio && v.comercio.toLowerCase().includes(this.searchKeyHT)) ||
            (v.productor && v.productor.toLowerCase().includes(this.searchKeyHT))
        );
    }
    handleNextHT() {
        if (this.currentPageHT * this.pageSizeHT < this.filteredVentasHT.length) {
            this.currentPageHT++;
        }
    }
    handlePrevHT() {
        if (this.currentPageHT > 1) {
            this.currentPageHT--;
        }
    }

    // ======== NAVIGATION ========
    handleRowAction(event) {
        const id = event.currentTarget.dataset.id;
        
    }
    handleRowActionHT(event) {
        const id = event.currentTarget.dataset.id;
        
    }
}