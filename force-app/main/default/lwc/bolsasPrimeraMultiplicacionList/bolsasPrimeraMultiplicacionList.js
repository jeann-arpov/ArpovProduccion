import { LightningElement, wire, track } from 'lwc';
import getBolsasPrimeraMultiplicacionActual from '@salesforce/apex/UserControllerComunidad.getBolsasPrimeraMultiplicacionActualList';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';

export default class BolsasPrimeraMultiplicacionList extends LightningElement {
    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;
   
    @track ventas = [];
    @track filteredVentas = [];
    @track campanas = [];
    @track categorias = [];
    @track estados = [];

    searchKey = '';
    selectedCampana = '';
    selectedCategoria = '';
    selectedEstado = '';

    @wire(getBolsasPrimeraMultiplicacionActual)
    wiredVentas({ error, data }) {
        if (data) {
            this.ventas = data;
            this.filteredVentas = [...data];

            // listas únicas dinámicas
            this.campanas = [...new Set(data.map(v => v.Campana_Agricola__r?.Name).filter(Boolean))];
            this.categorias = [...new Set(data.map(v => v.Categoria__c).filter(Boolean))];
            this.estados = [...new Set(data.map(v => v.Estado_Licencia__c).filter(Boolean))];
        } else if (error) {
            console.error('Error al obtener bolsas PM:', error);
        }
    }

    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleCampanaChange(event) {
        this.selectedCampana = event.target.value;
        this.applyFilters();
    }

    handleCategoriaChange(event) {
        this.selectedCategoria = event.target.value;
        this.applyFilters();
    }

    handleEstadoChange(event) {
        this.selectedEstado = event.target.value;
        this.applyFilters();
    }

    applyFilters() {
        this.filteredVentas = this.ventas.filter(v => {
            const matchSearch = this.searchKey === '' ||
                (v.Campana_Agricola__r?.Name || '').toLowerCase().includes(this.searchKey) ||
                (v.Destinatario__r?.Name || '').toLowerCase().includes(this.searchKey) ||
                (v.Destinatario__r?.N_CUIT__c || '').toLowerCase().includes(this.searchKey) ||
                (v.Variedad__c || '').toLowerCase().includes(this.searchKey) ||
                (v.Categoria__c || '').toLowerCase().includes(this.searchKey) ||
                (v.Estado_Licencia__c || '').toLowerCase().includes(this.searchKey) ||
                (String(v.Cantidad_Bolsas_40__c) || '').toLowerCase().includes(this.searchKey);

            const matchCampana = this.selectedCampana === '' || v.Campana_Agricola__r?.Name === this.selectedCampana;
            const matchCategoria = this.selectedCategoria === '' || v.Categoria__c === this.selectedCategoria;
            const matchEstado = this.selectedEstado === '' || v.Estado_Licencia__c === this.selectedEstado;

            return matchSearch && matchCampana && matchCategoria && matchEstado;
        });
    }
}