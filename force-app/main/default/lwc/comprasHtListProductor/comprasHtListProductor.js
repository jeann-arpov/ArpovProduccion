import { LightningElement, track, wire } from 'lwc';
import getComprasHT from '@salesforce/apex/ComprasHTController.getComprasHT';

export default class ComprasList extends LightningElement {
    @track comprasAll = [];
    @track comprasFiltradas = [];
    @track pageSlice = [];
    @track estados = [];
    @track cultivos = [];
    @track variedades = [];

    estadoSeleccionado = 'Todos los Estados';
    cultivoSeleccionado = 'Todos los Cultivos';
    variedadSeleccionada = 'Todas las Variedades';
    searchKey = '';

    // Paginación
    pageSize = 10;
    currentPage = 1;
    disablePrev = true;
    disableNext = false;
    totalRegistros = 0;

    @wire(getComprasHT)
    wiredCompras({ data, error }) {
        if (data) {
            this.comprasAll = data.map(c => ({
                id: c.id,
                fecha: c.fecha ? new Date(c.fecha).toLocaleDateString() : '',
                name: c.compra,
                totalHT: c.totalHt,
                totalUSD: c.totalUsd,
                cultivo: c.cultivo || 'Sin Cultivo',
                variedades: c.variedades || 'Sin Variedad',
                codigoLink: '/' + c.id,
                productor: c.productor || '',
                comercio: c.comercio || '',
                estado: c.estado || ''
            }));

            // Poblar listas únicas para filtros + opciones "Todos"
            this.estados = ['Todos los Estados', ...new Set(this.comprasAll.map(c => c.estado))];
            this.cultivos = ['Todos los Cultivos', ...new Set(this.comprasAll.map(c => c.cultivo))];
            this.variedades = ['Todas las Variedades', ...new Set(this.comprasAll.map(c => c.variedades))];

            this.applyFilters();
        } else if (error) {
            console.error('Error al cargar compras:', error);
        }
    }

    handleFilterChange(event) {
        const datasetId = event.target.dataset.id;
        const value = event.target.value;

        if (datasetId === 'estadoSelect') {
            this.estadoSeleccionado = value;
        } else if (datasetId === 'cultivoSelect') {
            this.cultivoSeleccionado = value;
        } else if (datasetId === 'variedadSelect') {
            this.variedadSeleccionada = value;
        }

        this.applyFilters();
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.applyFilters();
    }

    applyFilters() {
        let data = [...this.comprasAll];

        if (this.estadoSeleccionado && this.estadoSeleccionado !== 'Todos los Estados') {
            data = data.filter(c => c.estado === this.estadoSeleccionado);
        }
        if (this.cultivoSeleccionado && this.cultivoSeleccionado !== 'Todos los Cultivos') {
            data = data.filter(c => c.cultivo === this.cultivoSeleccionado);
        }
        if (this.variedadSeleccionada && this.variedadSeleccionada !== 'Todas las Variedades') {
            data = data.filter(c => c.variedades === this.variedadSeleccionada);
        }
        if (this.searchKey) {
            data = data.filter(c =>
                c.name.toLowerCase().includes(this.searchKey) ||
                (c.productor && c.productor.toLowerCase().includes(this.searchKey))
            );
        }

        this.comprasFiltradas = data;
        this.totalRegistros = data.length;
        this.currentPage = 1;
        this.paginar();
    }

    paginar() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pageSlice = this.comprasFiltradas.slice(start, end);

        this.disablePrev = this.currentPage === 1;
        this.disableNext = end >= this.totalRegistros;
    }

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.paginar();
        }
    }

    handleNext() {
        if ((this.currentPage * this.pageSize) < this.totalRegistros) {
            this.currentPage++;
            this.paginar();
        }
    }

    navigateToCompra(event) {
        const recordId = event.currentTarget.dataset.id;
        const recordName = event.currentTarget.dataset.name;

        // ⚠️ Usar el Name tal cual lo devuelve Salesforce
        const safeName = recordName; 

        // Detectar basePath dinámicamente
        // ej: "/SembraEvolucion/s" o "/Productores/s"
        let basePath = '';
        const pathname = window.location.pathname;

        if (pathname.includes('/SembraEvolucion/s')) {
            basePath = '/SembraEvolucion/s';
        } else if (pathname.includes('/Productores/s')) {
            basePath = '/Productores/s';
        } else {
            // fallback genérico
            basePath = pathname.split('/s')[0] + '/s';
        }

        // Construcción de URL final
        const url = `${basePath}/compra-ht/${recordId}/${safeName}`;

        console.log('🌐 Navegando a:', url);

        // Redirigir
        window.open(url, "_self");
    }
}