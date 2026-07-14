import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getVentasInformadasProcesadas from '@salesforce/apex/VentasInformadasController.getVentasInformadasProcesadas';
import {
    hasActiveFilters,
    filterVentas,
    sortVentas,
    exportVentas
} from 'c/ventasInformadasExcelUtil';
import {
    buildColumnColStyles,
    createColumnResizeController,
    DEFAULT_WIDTHS_PROCESADAS
} from 'c/ventasInformadasTableResizeUtil';

const UNIDADES = {
    BOLSAS_40: 'Bolsas 40 Kg',
    KILOS: 'Kilos',
    BIGBAGS: 'BigBags 800 Kg'
};

const PAGE_SIZES = [10, 25, 50, 100, 200];

export default class VentasInformadasProcesadasList extends LightningElement {
    @track ventas = [];
    @track currentPage = 1;
    @track pageSize = 200;
    @track sortField = null;
    @track sortDirection = 'asc';
    @track columnFilters = {};
    @track searchTerm = '';
    @track unidadSeleccionada = UNIDADES.BOLSAS_40;
    @track showExportModal = false;
    @track exportFormat = 'xlsx';
    @track exportScope = 'all';
    @track columnWidths = [...DEFAULT_WIDTHS_PROCESADAS];
    @track isResizingColumns = false;
    @track isLoading = true;
    columnResizeController;

    connectedCallback() {
        this.columnResizeController = createColumnResizeController(this);
        this.loadVentas();
    }

    async loadVentas() {
        this.isLoading = true;
        try {
            const data = await getVentasInformadasProcesadas();
            this.ventas = Array.isArray(data) ? [...data] : [];
        } catch (error) {
            console.error('Error al cargar ventas procesadas:', error);
            this.ventas = [];
        } finally {
            this.isLoading = false;
        }
    }

    disconnectedCallback() {
        this.columnResizeController?.destroy();
    }

    get totalCargados() {
        return this.ventas.length;
    }

    get pageSizeValue() {
        return String(this.pageSize);
    }

    get pageSizeComboboxOptions() {
        return PAGE_SIZES.map((size) => ({
            label: String(size),
            value: String(size)
        }));
    }

    get columnColStyles() {
        return buildColumnColStyles(this.columnWidths);
    }

    get tableWrapperClass() {
        return this.isResizingColumns
            ? 'ventas-table-wrapper is-resizing'
            : 'ventas-table-wrapper';
    }

    get totalRegistros() {
        return this.ventasFiltradasYOrdenadas.length;
    }

    get disablePrev() {
        return this.currentPage === 1;
    }

    get disableNext() {
        return this.currentPage >= Math.ceil(this.ventasFiltradasYOrdenadas.length / this.pageSize);
    }

    get ventasFiltradasYOrdenadas() {
        return sortVentas(
            filterVentas(this.ventas, this.searchTerm, this.columnFilters),
            this.sortField,
            this.sortDirection
        );
    }

    get ventasOrdenadas() {
        return sortVentas(this.ventas, this.sortField, this.sortDirection);
    }

    get tieneFiltrosActivos() {
        return hasActiveFilters(this.searchTerm, this.columnFilters);
    }

    get exportTotalTodos() {
        return this.ventasOrdenadas.length;
    }

    get exportTotalFiltrados() {
        return this.ventasFiltradasYOrdenadas.length;
    }

    get exportFormatXlsx() {
        return this.exportFormat === 'xlsx';
    }

    get exportFormatCsv() {
        return this.exportFormat === 'csv';
    }

    get exportScopeFiltered() {
        return this.exportScope === 'filtered';
    }

    get exportScopeAll() {
        return this.exportScope === 'all';
    }

    get ventasPagina() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.ventasFiltradasYOrdenadas
            .slice(start, start + this.pageSize)
            .map((venta) => ({
                ...venta,
                cantidadDisplay: this.formatCantidad(venta)
            }));
    }

    handlePrev() {
        if (this.currentPage > 1) this.currentPage--;
    }

    handleNext() {
        if (this.currentPage < Math.ceil(this.ventasFiltradasYOrdenadas.length / this.pageSize)) this.currentPage++;
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.currentPage = 1;
    }

    handleColumnResizeStart(event) {
        this.columnResizeController?.onStart(event);
    }

    handleColumnResizeClick(event) {
        event.preventDefault();
        event.stopPropagation();
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDirection = 'asc';
        }
    }

    handleColumnFilter(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.columnFilters = { ...this.columnFilters, [field]: value };
        this.currentPage = 1;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.currentPage = 1;
    }

    handleUnidadChange(event) {
        this.unidadSeleccionada = event.target.value;
    }

    formatCantidad(venta) {
        switch (this.unidadSeleccionada) {
            case UNIDADES.KILOS:
                return venta.cantidadKilos ? venta.cantidadKilos.toFixed(2) : '0';
            case UNIDADES.BIGBAGS:
                return venta.cantidadBigBags ? venta.cantidadBigBags.toFixed(2) : '0';
            default:
                return venta.bolsas40 || '0';
        }
    }

    getCantidadFormateada(venta) {
        return this.formatCantidad(venta);
    }

    get unidadLabel() {
        switch(this.unidadSeleccionada) {
            case UNIDADES.KILOS:
                return 'Kilos';
            case UNIDADES.BIGBAGS:
                return 'BigBags';
            default:
                return 'Bolsas 40Kg';
        }
    }

    getSortIcon(field) {
        if (this.sortField !== field) return '';
        return this.sortDirection === 'asc' ? '▲' : '▼';
    }

    handleExportClick() {
        this.exportFormat = 'xlsx';
        this.exportScope = this.tieneFiltrosActivos ? 'filtered' : 'all';
        this.showExportModal = true;
    }

    handleCancelExport() {
        this.showExportModal = false;
    }

    handleExportFormatChange(event) {
        this.exportFormat = event.target.value;
    }

    handleExportScopeChange(event) {
        this.exportScope = event.target.value;
    }

    handleConfirmExport() {
        const ventas = this.exportScope === 'filtered'
            ? this.ventasFiltradasYOrdenadas
            : this.ventasOrdenadas;
        this.showExportModal = false;
        this.ejecutarExportacion(ventas);
    }

    async ejecutarExportacion(ventas) {
        try {
            const dateSuffix = new Date().toISOString().split('T')[0];
            const extension = this.exportFormat === 'csv' ? 'csv' : 'xlsx';
            const fileName = `ventas_procesadas_${dateSuffix}.${extension}`;

            await exportVentas(this, {
                format: this.exportFormat,
                ventas,
                cantidadHeader: `Cantidad (${this.unidadLabel})`,
                getCantidadValue: (v) => this.getCantidadFormateada(v),
                fileName,
                sheetName: 'Ventas Procesadas'
            });

            const formatoLabel = this.exportFormat === 'csv' ? 'CSV' : 'Excel';
            this.showToast('Éxito', `Archivo ${formatoLabel} exportado correctamente`, 'success');
        } catch (error) {
            this.showToast('Error', 'Error al exportar: ' + (error.message || 'Error desconocido'), 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}