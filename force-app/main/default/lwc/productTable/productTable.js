import { LightningElement, track } from 'lwc';
import getProducts from '@salesforce/apex/ProductTableController.getProducts';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getTotalProducts from '@salesforce/apex/ProductTableController.getTotalProducts';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';

export default class ProductosList extends NavigationMixin(LightningElement) {

    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    @track productos = [];
    @track totalRegistros = 0;

    @track searchTerm = '';
    @track isLoading = true;

    pageSize = 10;
    currentPage = 1;
    totalPages = 1;

    searchTimeout;

    connectedCallback() {
        this.loadProductos();
    }

    async loadProductos() {
        this.isLoading = true;

        try {
            // 🔥 CORRECTO: Apex recibe un MAP, no parámetros sueltos
            const total = await getTotalProducts({
                searchTerm: this.searchTerm || ''
            });

            this.totalRegistros = total;
            this.totalPages = Math.ceil(total / this.pageSize);

            const result = await getProducts({
                pageNumber: this.currentPage,
                pageSize: this.pageSize,
                searchTerm: this.searchTerm || ''
            });

            this.productos = result || [];

        } catch (error) {
            console.error('Error cargando productos:', error);
            this.productos = [];
        }

        this.isLoading = false;
    }
    

   handleRowAction(event) {
    const productId = event.currentTarget.dataset.id;

    this[NavigationMixin.Navigate]({
        type: 'comm__namedPage',
        attributes: {
            name: 'listapreciosdetail__c'
        },
        state: {
            productId: productId
        }
    });

        console.log(productId);
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;

        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        this.searchTimeout = setTimeout(() => {
            this.currentPage = 1;
            this.loadProductos();
        }, 300);
    }

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.loadProductos();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.loadProductos();
        }
    }

    get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    get decoratedProductos() {
        return this.productos.map(p => ({
            id: p.Id,
            marca: p.Marca,
            productoObtentor: p.ProductoObtentor,
            variedad: p.Variedad,
            tipoCompra: p.TipoCompra,
            vigente: p.Vigente,
            fechaCreacion: p.FechaCreacion
        }));
    }
}