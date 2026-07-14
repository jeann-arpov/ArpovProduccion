import { LightningElement, track } from 'lwc';
import getLoadData from '@salesforce/apex/CuentaGranaria.getLoadData';
import getHectareasTecnologicas from '@salesforce/apex/ComprasHTController.getHectareasTecnologicas';
import { reduceErrors } from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import IMAGENES from '@salesforce/resourceUrl/CuentaGranariaIcons';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';

export default class CompraHTNewProductor extends NavigationMixin(LightningElement) {
    initialized = false;
    processing = true;

    // Data
    hectareasTecnologicas = [];
    cultivos;
    cultivoId;
    total = 0;

    // Filtrado + búsqueda
    searchTerm = '';
    filteredRows = [];
    @track pageSlice = [];

    // Paginación
    pageSize = 5;
    currentPage = 1;

    // Iconos
    iconCebadaUrl = `${resourcePortal}/resourcePortal/images/prd-cebada.svg`;
    iconSojaUrl   = `${resourcePortal}/resourcePortal/images/prd-soja.svg`;
    iconTrigoUrl  = `${resourcePortal}/resourcePortal/images/prd-trigo.svg`;
    iconoCultivo  = IMAGENES + '/cultivo.svg';
    iconSearchUrl = `${resourcePortal}/resourcePortal/images/icon-search.svg`;

    // Cultivos decorados para step
    get decoratedCultivos() {
        if (!this.cultivos) return [];
        return this.cultivos.map(c => {
            return {
                ...c,
                id: c.value,
                nombre: c.label,
                icono: this.getIcon(c.label),
                cssClass: 'item' + (this.cultivoId === c.value ? ' selected' : '')
            };
        });
    }

    getIcon(nombre) {
        switch ((nombre || '').toLowerCase()) {
            case 'soja': return this.iconSojaUrl;
            case 'trigo': return this.iconTrigoUrl;
            case 'cebada': return this.iconCebadaUrl;
            default: return this.iconoCultivo;
        }
    }

    // Selección de cultivo
    handleSelectCultivo(event) {
        this.cultivoId = event.currentTarget.dataset.id;
        this.getHTs();
    }

    // Param por URL
    get paramCultivo() {
        return new URL(window.location.href).searchParams.get("cultivoId");
    }

    // Init
    async init() {
        this.initialized = true;
        try {
            const data = await getLoadData();
            this.cultivos = data.cultivos.map(c => ({ label: c.Name, value: c.Id }));

            if (this.paramCultivo) {
                this.cultivoId = this.paramCultivo;
                await this.getHTs();
            }
        } catch (e) {
            this.onError(e);
        }
        this.processing = false;
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    // Traer HTs
    async getHTs() {
        this.processing = true;
        try {
            this.hectareasTecnologicas = await getHectareasTecnologicas({ cultivoId: this.cultivoId });
            this.applyFilters();
        } catch (e) {
            this.onError(e);
        }
        this.processing = false;
    }

    // Búsqueda
    handleSearchChange(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.applyFilters();
    }

    // Aplicar filtros
    applyFilters() {
        let filtered = [...this.hectareasTecnologicas];

        if (this.searchTerm) {
            filtered = filtered.filter(r =>
                (r.cultivo && r.cultivo.toLowerCase().includes(this.searchTerm)) ||
                (r.biotecnologia && r.biotecnologia.toLowerCase().includes(this.searchTerm)) ||
                (r.comercio && r.comercio.toLowerCase().includes(this.searchTerm)) ||
                (r.origen && r.origen.toLowerCase().includes(this.searchTerm))
            );
        }

        this.filteredRows = filtered;
        this.currentPage = 1;
        this.updatePage();
    }

    // Paginación
    updatePage() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pageSlice = this.filteredRows.slice(start, end);
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

    get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= Math.ceil(this.filteredRows.length / this.pageSize);
    }

    // Totales por biotecnología
    get totalPorBiotecnologia() {
        const groups = {};
        this.total = 0;

        for (const r of this.hectareasTecnologicas) {
            const key = r.biotecnologia;
            groups[key] = groups[key] || { key: r.biotecnologia, value: 0 };
            groups[key].value += r.credito || 0;
            this.total += r.credito || 0;
        }

        return Object.values(groups);
    }

    // Navegación
    viewRecord(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.target.value,
                objectApiName: "Hectareas_Tecnologicas__c",
                actionName: "view"
            }
        });
    }

    // Errores
    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
            mode: 'sticky'
        }));
    }
}