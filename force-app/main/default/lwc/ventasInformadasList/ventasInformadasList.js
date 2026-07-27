import { LightningElement, track, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import VENTAS_INFORMADAS_REFRESH from '@salesforce/messageChannel/VentasInformadasRefresh__c';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getVentasInformadas from '@salesforce/apex/VentasInformadasController.getVentasInformadasSinProcesar';
import deleteVentaInformada from '@salesforce/apex/VentasInformadasController.deleteVentaInformada';
import getVentaInformadaById from '@salesforce/apex/VentasInformadasController.getVentaInformadaById';
import getProvinciasDestinoParaLookup from '@salesforce/apex/VentasInformadasDestinoGeoService.getProvinciasDestinoParaLookup';
import updateUbicacionVentaProcesada from '@salesforce/apex/VentasInformadasController.updateUbicacionVentaProcesada';
import VentaInformadaModal from 'c/ventaInformadaModal';
import {
    hasActiveFilters,
    filterVentas,
    sortVentas,
    exportVentas
} from 'c/ventasInformadasExcelUtil';
import {
    buildColumnColStyles,
    createColumnResizeController,
    DEFAULT_WIDTHS_SIN_PROCESAR
} from 'c/ventasInformadasTableResizeUtil';

const UNIDADES = {
    BOLSAS_40: 'Bolsas 40 Kg',
    KILOS: 'Kilos',
    BIGBAGS: 'BigBags 800 Kg'
};

const PAGE_SIZES = [10, 25, 50, 100, 200];

function isStineSinUbicacion(venta) {
    return (
        venta?.esStine === true &&
        (!venta.provinciaUbicacionId || !venta.localidadUbicacionId)
    );
}

export default class VentasInformadasList extends NavigationMixin(LightningElement) {
    @wire(MessageContext)
    messageContext;

    @track ventas = [];
    @track ubicacionDraftByVentaId = {};
    @track provinciaOptions = [];
    @track searchTerm = '';
    @track showModal = false;
    @track showExportModal = false;
    @track ventaIdToDelete = null;
    @track sortField = null;
    @track sortDirection = 'asc';
    @track columnFilters = {};
    @track pageSize = 200;
    @track unidadSeleccionada = UNIDADES.BOLSAS_40;
    @track exportFormat = 'xlsx';
    @track exportScope = 'all';
    @track columnWidths = [...DEFAULT_WIDTHS_SIN_PROCESAR];
    @track isResizingColumns = false;
    @track isLoading = true;
    @track savingUbicacionVentaId = null;
    @track soloStineSinUbicacion = false;
    currentPage = 1;
    refreshSubscription = null;
    columnResizeController;

    get totalCargados() {
        return this.ventas.length;
    }

    get stineSinUbicacionCount() {
        return this.ventas.filter(isStineSinUbicacion).length;
    }

    get stineFilterButtonClass() {
        return this.soloStineSinUbicacion
            ? 'btn-stine-filter is-active'
            : 'btn-stine-filter';
    }

    get stineFilterLabel() {
        return `Ventas pendientes de ubicación (${this.stineSinUbicacionCount})`;
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

    connectedCallback() {
        this.columnResizeController = createColumnResizeController(this);
        this.loadVentas();
    }

    disconnectedCallback() {
        if (this.refreshSubscription) {
            unsubscribe(this.refreshSubscription);
            this.refreshSubscription = null;
        }
        this.columnResizeController?.destroy();
    }

    renderedCallback() {
        if (!this.messageContext || this.refreshSubscription) return;
        this.refreshSubscription = subscribe(
            this.messageContext,
            VENTAS_INFORMADAS_REFRESH,
            (message) => {
                if (!message?.action || message.action === 'refresh') {
                    this.refresh();
                }
            }
        );
    }

    @wire(getProvinciasDestinoParaLookup, { searchTerm: '' })
    wiredProvincias({ data, error }) {
        if (data) {
            this.provinciaOptions = data.map((item) => ({
                label: item.title,
                value: item.id
            }));
        } else if (error) {
            console.error('Error cargando provincias:', error);
            this.provinciaOptions = [];
        }
    }

    @api
    refresh() {
        this.currentPage = 1;
        return this.loadVentas();
    }

    async loadVentas() {
        this.isLoading = true;
        try {
            const data = await getVentasInformadas();
            this.ventas = Array.isArray(data) ? [...data] : [];
            this.initUbicacionDrafts(this.ventas);
        } catch (error) {
            console.error('Error cargando ventas informadas:', error);
            this.ventas = [];
            this.ubicacionDraftByVentaId = {};
        } finally {
            this.isLoading = false;
        }
    }

    initUbicacionDrafts(ventas) {
        const drafts = {};
        (ventas || []).forEach((venta) => {
            if (!venta?.id) {
                return;
            }
            drafts[venta.id] = {
                provinciaId: venta.provinciaUbicacionId || null,
                localidadId: venta.localidadUbicacionId || null,
                provinciaLabel: venta.provinciaUbicacion || '',
                localidadLabel: venta.localidadUbicacion || ''
            };
        });
        this.ubicacionDraftByVentaId = drafts;
    }

    get totalRegistros() {
        return this.ventasFiltradasYOrdenadas.length;
    }

    get ventasFiltradasYOrdenadas() {
        let filtered = filterVentas(this.ventas, this.searchTerm, this.columnFilters);
        if (this.soloStineSinUbicacion) {
            filtered = filtered.filter(isStineSinUbicacion);
        }
        return sortVentas(filtered, this.sortField, this.sortDirection);
    }

    get ventasOrdenadas() {
        return sortVentas(this.ventas, this.sortField, this.sortDirection);
    }

    get tieneFiltrosActivos() {
        return hasActiveFilters(this.searchTerm, this.columnFilters) || this.soloStineSinUbicacion;
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
            .map((venta) => this.enrichVentaRow(venta));
    }

    enrichVentaRow(venta) {
        const draft = this.ubicacionDraftByVentaId[venta.id] || {
            provinciaId: venta.provinciaUbicacionId || null,
            localidadId: venta.localidadUbicacionId || null,
            provinciaLabel: venta.provinciaUbicacion || '',
            localidadLabel: venta.localidadUbicacion || ''
        };

        return {
            ...venta,
            cantidadDisplay: this.formatCantidad(venta),
            ubicacionEditable: true,
            ubicacionProvinciaId: draft.provinciaId,
            ubicacionProvinciaLabel: draft.provinciaLabel,
            ubicacionLocalidadId: draft.localidadId,
            ubicacionLocalidadLabel: draft.localidadLabel,
            ubicacionSaving: this.savingUbicacionVentaId === venta.id,
            provinciaCellClass: 'col-ubicacion',
            localidadCellClass: 'col-ubicacion'
        };
    }

    get disablePrev() {
        return this.currentPage === 1;
    }

    get disableNext() {
        return this.currentPage * this.pageSize >= this.ventasFiltradasYOrdenadas.length;
    }

    handleToggleStineSinUbicacion() {
        this.soloStineSinUbicacion = !this.soloStineSinUbicacion;
        this.currentPage = 1;
    }

    async handleUbicacionLookupChange(event) {
        const { ventaId, fieldType, selectedId, selectedLabel } = event.detail || {};
        if (!ventaId || !fieldType) {
            return;
        }

        const current = this.ubicacionDraftByVentaId[ventaId] || {};
        const nextDraft = { ...current };

        if (fieldType === 'provincia') {
            const provinciaChanged = current.provinciaId !== selectedId;
            nextDraft.provinciaId = selectedId;
            nextDraft.provinciaLabel = selectedLabel;
            if (provinciaChanged) {
                nextDraft.localidadId = null;
                nextDraft.localidadLabel = '';
            }
            this.ubicacionDraftByVentaId = {
                ...this.ubicacionDraftByVentaId,
                [ventaId]: nextDraft
            };
            await this.saveUbicacion(ventaId);
            return;
        }

        if (fieldType === 'localidad') {
            nextDraft.localidadId = selectedId;
            nextDraft.localidadLabel = selectedLabel;
            this.ubicacionDraftByVentaId = {
                ...this.ubicacionDraftByVentaId,
                [ventaId]: nextDraft
            };
            await this.saveUbicacion(ventaId);
        }
    }

    async saveUbicacion(ventaId) {
        const draft = this.ubicacionDraftByVentaId[ventaId];
        if (!draft) {
            return;
        }

        this.savingUbicacionVentaId = ventaId;
        try {
            await updateUbicacionVentaProcesada({
                ventaId,
                provinciaUbicacionId: draft.provinciaId || null,
                localidadUbicacionId: draft.localidadId || null
            });

            this.ventas = this.ventas.map((venta) => {
                if (venta.id !== ventaId) {
                    return venta;
                }
                return {
                    ...venta,
                    provinciaUbicacionId: draft.provinciaId,
                    provinciaUbicacion: draft.provinciaLabel,
                    localidadUbicacionId: draft.localidadId,
                    localidadUbicacion: draft.localidadLabel
                };
            });

            this.showToast('Éxito', 'Ubicación actualizada.', 'success');
        } catch (error) {
            const message =
                error?.body?.message ||
                error?.message ||
                'No se pudo guardar provincia/localidad.';
            this.showToast('Error', message, 'error');
            await this.loadVentas();
        } finally {
            this.savingUbicacionVentaId = null;
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.currentPage = 1;
    }

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNext() {
        if (!this.disableNext) {
            this.currentPage++;
        }
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
        switch (this.unidadSeleccionada) {
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
            const fileName = `ventas_informadas_${dateSuffix}.${extension}`;

            await exportVentas(this, {
                format: this.exportFormat,
                ventas,
                cantidadHeader: `Cantidad (${this.unidadLabel})`,
                getCantidadValue: (v) => this.getCantidadFormateada(v),
                fileName,
                sheetName: 'Ventas Informadas'
            });

            const formatoLabel = this.exportFormat === 'csv' ? 'CSV' : 'Excel';
            this.showToast('Éxito', `Archivo ${formatoLabel} exportado correctamente`, 'success');
        } catch (error) {
            this.showToast('Error', 'Error al exportar: ' + (error.message || 'Error desconocido'), 'error');
        }
    }

    handleDetailClick(event) {
        const ventaId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: ventaId,
                actionName: 'view'
            }
        });
    }

    handleDeleteClick(event) {
        this.ventaIdToDelete = event.target.dataset.id;
        this.showModal = true;
    }

    handleCancelDelete() {
        this.showModal = false;
        this.ventaIdToDelete = null;
    }

    async handleConfirmDelete() {
        try {
            await deleteVentaInformada({ ventaId: this.ventaIdToDelete });
            this.showToast('Éxito', 'Venta informada eliminada correctamente', 'success');
            this.showModal = false;
            this.ventaIdToDelete = null;
            await this.loadVentas();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error al eliminar', 'error');
        }
    }

    async handleDuplicateClick(event) {
        const ventaId = event.target.dataset.id;
        try {
            const data = await getVentaInformadaById({ ventaId });
            await VentaInformadaModal.open({
                size: 'large',
                modalTitle: 'Duplicar Venta Informada',
                prefillData: data
            });
            await this.loadVentas();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Error al duplicar', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
