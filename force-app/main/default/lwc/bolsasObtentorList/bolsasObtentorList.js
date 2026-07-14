import { LightningElement, wire, track } from 'lwc';
import getBolsasObtentorCampaniaActiva from '@salesforce/apex/UserControllerComunidad.getBolsasObtentorCampaniaActivaList';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import { normalizeCuit } from 'c/utils';

export default class BolsasObtentorList extends LightningElement {
    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    @track ventas = [];          // todos los CUITs únicos
    @track filteredVentas = [];  // lista filtrada
    searchKey = '';

    // 🔹 Paginación
    currentPage = 1;
    pageSize = 10;

    @wire(getBolsasObtentorCampaniaActiva)
    wiredVentas({ error, data }) {
        if (data) {
            console.log('👉 Data recibida:', JSON.stringify(data));
            // data ya es [{ cuit: '20-123...', razonSocial: 'Cliente X'}, ...]
            this.ventas = data.map(v => ({
                id: v.cuit,        // usamos el CUIT como id
                cuit: v.cuit,
                razonSocial: v.razonSocial
            }));
            this.filteredVentas = [...this.ventas];
        } else if (error) {
            console.error('Error al obtener bolsas:', error);
        }
    }

    // ======== GETTERS ========
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

    // ======== HANDLERS ========
    handleSearchChange(event) {
        const rawValue = event.target.value.toLowerCase();
        this.searchKey = rawValue;
        const searchKeyNorm = normalizeCuit(rawValue);
        this.filteredVentas = this.ventas.filter(v =>
            (searchKeyNorm && v.cuit && v.cuit.toLowerCase().includes(searchKeyNorm)) ||
            (v.razonSocial && v.razonSocial.toLowerCase().includes(this.searchKey))
        );
        this.currentPage = 1;
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
}