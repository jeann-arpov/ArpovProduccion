import { LightningElement, track, api } from 'lwc';
import getVencimientos from '@salesforce/apex/MisFacturasController.getVencimientos';
import getAdjuntosPago from '@salesforce/apex/MisFacturasController.getAdjuntosPago';
import PagoInformadoTooltip from '@salesforce/label/c.PagoInformado_Tooltip';
import { fetchCultivoOptions, fetchCultivoSummary } from 'c/cultivoResumenService';
import { reduceErrors } from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { doRequest } from 'c/utils';
import { trackGa4Event } from 'c/portalGa4Events';
import { syncPortalModal, releasePortalModal } from 'c/seModalLayer';
import { ensureXlsxLoaded, downloadVentasWorkbook } from 'c/ventasInformadasExcelUtil';

const EXPORT_HEADERS = ['Comprobante', 'Fecha', 'Concepto', 'Cultivo', 'Importe', 'Vencimiento', 'Estado'];

function pad(n) {
    return String(n).padStart(2, '0');
}

function formatDate(value) {
    if (!value) return '';
    const dt = new Date(value);
    if (Number.isNaN(dt.getTime())) return '';
    return `${pad(dt.getDate())}/${pad(dt.getMonth() + 1)}/${String(dt.getFullYear()).slice(-2)}`;
}

function formatImporte(total, moneda) {
    if (total == null || total === '') return '';
    const amount = Number(total).toLocaleString('es-AR', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
    const prefix = moneda && String(moneda).toUpperCase().includes('ARS') ? 'ARS' : 'USD';
    return `${prefix} ${amount}`;
}

const STAGES_INFORMAR_PAGO = ['Facturada', 'Pedido de Facturacion'];

function isPagada(stage) {
    return /pagad/i.test(stage || '');
}

function resolveStatus(row) {
    if (isPagada(row.oppStage)) {
        return { label: 'Pagada', tone: 'ok', bucket: 'pagadas' };
    }
    if (row.pagoInformado === true) {
        return { label: 'Pago informado', tone: 'info', bucket: 'facturadas' };
    }
    const due = row.fechaVencimiento ? new Date(row.fechaVencimiento) : null;
    const overdue = due && !Number.isNaN(due.getTime()) && due < new Date();
    if (overdue) {
        return { label: 'Vencida', tone: 'danger', bucket: 'facturadas' };
    }
    return { label: 'Facturada', tone: 'warn', bucket: 'facturadas' };
}

export default class MisFacturasSembraEvolucion extends LightningElement {
    @api type;

    @track vencimientos = [];
    @track data = [];
    @track loading = true;
    @track cultivoOptions = [];
    @track cultivoSummaryRows = [];
    @track selectedCultivoId;
    @track cultivoSummaryTotal = 0;
    @track cultivoSummaryLoading = false;
    @track showCultivoResumen = false;
    @track adjuntos = [];
    @track showDocumentos = false;
    @track documentosLoading = false;
    documentosFactura;
    pagoInformadoTooltip = PagoInformadoTooltip;
    statusFilter = 'todas';
    pageSize = 200;
    initialized = false;

    columns = [
        { label: 'Comprobante', fieldName: 'numero', type: 'link' },
        { label: 'Fecha', fieldName: 'fechaLabel' },
        { label: 'Concepto', fieldName: 'concepto' },
        { label: 'Cultivo', fieldName: 'cultivoLabel' },
        { label: 'Importe', fieldName: 'importeLabel' },
        { label: 'Vto.', fieldName: 'vtoLabel' },
        { label: 'Estado', fieldName: 'statusLabel', type: 'badge', toneField: 'statusTone' },
        { label: '', fieldName: 'action', type: 'action', actionLabel: 'Ver' }
    ];

    mobileFields = [
        { label: 'Fecha', fieldName: 'fechaLabel' },
        { label: 'Concepto', fieldName: 'conceptoLine' },
        { label: 'Importe', fieldName: 'importeLabel' },
        { label: 'Vto.', fieldName: 'vtoLabel' }
    ];

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
    }

    disconnectedCallback() {
        releasePortalModal(this);
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
    }

    renderedCallback() {
        if (!this.initialized) this.init();
        syncPortalModal(this, this.showDocumentos, '.mf-scrim');
    }

    get statusPills() {
        const rows = this.rowsDelCultivo;
        return [
            {
                id: 'todas',
                label: 'Todas',
                count: rows.length,
                selected: this.statusFilter === 'todas'
            },
            {
                id: 'facturadas',
                label: 'Facturadas',
                count: rows.filter((row) => row.bucket === 'facturadas').length,
                selected: this.statusFilter === 'facturadas'
            },
            {
                id: 'pagadas',
                label: 'Pagadas',
                count: rows.filter((row) => row.bucket === 'pagadas').length,
                selected: this.statusFilter === 'pagadas'
            }
        ];
    }

    get selectedCultivoName() {
        if (!this.showCultivoResumen || !this.selectedCultivoId) return '';
        const option = (this.cultivoOptions || []).find((o) => o.value === this.selectedCultivoId);
        return option ? String(option.label || '').trim().toUpperCase() : '';
    }

    // Las facturas sin cultivo se muestran en todas las pestañas para no ocultarlas.
    get rowsDelCultivo() {
        const cultivo = this.selectedCultivoName;
        if (!cultivo) return this.vencimientos;
        return this.vencimientos.filter((row) => {
            const rowCultivo = String(row.cultivo || '').trim().toUpperCase();
            return !rowCultivo || rowCultivo === cultivo;
        });
    }

    async init() {
        this.initialized = true;

        await doRequest.call(this, async () => {
            const vencimientos = await getVencimientos({ type: this.type || 'Productor' });
            const isProductor = (this.type || 'Productor') === 'Productor';

            this.vencimientos = (vencimientos || []).map((vencimiento, idx) => {
                vencimiento.canInformarPago =
                    vencimiento.pagoInformado !== true &&
                    ((Boolean(vencimiento.id) && isProductor) ||
                        STAGES_INFORMAR_PAGO.includes(vencimiento.oppStage));
                if (vencimiento.file == null && vencimiento.facturaPVId) {
                    vencimiento.file = { id: vencimiento.facturaPVId };
                }
                if (vencimiento.id == null) vencimiento.id = vencimiento.numero;
                vencimiento.disableVerFactura = !vencimiento.file;
                vencimiento.uniqueId = String(idx);
                vencimiento.mobileKey = `m-${idx}`;

                const status = resolveStatus(vencimiento);
                vencimiento.fechaLabel = formatDate(vencimiento.fecha);
                vencimiento.vtoLabel = formatDate(vencimiento.fechaVencimiento);
                vencimiento.importeLabel = formatImporte(vencimiento.total, vencimiento.moneda);
                vencimiento.cultivoLabel = vencimiento.cultivo || '—';
                vencimiento.concepto = vencimiento.comercio || vencimiento.productor ? 'Compra HT' : 'Precertificación PPH';
                vencimiento.conceptoLine = `${vencimiento.concepto} · ${vencimiento.cultivoLabel}`;
                vencimiento.statusLabel = status.label;
                vencimiento.statusTone = status.tone;
                vencimiento.actionDisabled = vencimiento.disableVerFactura && !vencimiento.opportunityId;
                vencimiento.bucket = status.bucket;
                return vencimiento;
            });

            await this.loadCultivoResumenOptions();
            this.applyFilters();
        });
    }

    async loadCultivoResumenOptions() {
        try {
            const { options, defaultId } = await fetchCultivoOptions();
            this.cultivoOptions = options;
            this.showCultivoResumen = options.length > 0;

            if (options.length && !this.selectedCultivoId) {
                this.selectedCultivoId = defaultId;
                await this.loadCultivoSummary();
            }
        } catch (error) {
            this.cultivoOptions = [];
            this.showCultivoResumen = false;
        }
    }

    async loadCultivoSummary() {
        if (!this.selectedCultivoId) {
            this.cultivoSummaryRows = [];
            this.cultivoSummaryTotal = 0;
            return;
        }

        this.cultivoSummaryLoading = true;
        try {
            const summary = await fetchCultivoSummary(this.selectedCultivoId);
            this.cultivoSummaryRows = summary.rows;
            this.cultivoSummaryTotal = summary.total;
        } catch (error) {
            this.cultivoSummaryRows = [];
            this.cultivoSummaryTotal = 0;
        } finally {
            this.cultivoSummaryLoading = false;
        }
    }

    handleCultivoResumenSelect(event) {
        this.selectedCultivoId = event.detail?.value;
        this.applyFilters();
        this.loadCultivoSummary();
    }

    get hasPagoInformado() {
        return this.vencimientos.some((row) => row.pagoInformado === true);
    }

    get hasAdjuntos() {
        return this.adjuntos.length > 0;
    }

    get showDocumentosEmpty() {
        return !this.documentosLoading && !this.documentosFactura && !this.hasAdjuntos;
    }

    handlePill(event) {
        this.statusFilter = event.detail.id;
        this.applyFilters();
    }

    applyFilters() {
        let rows = [...this.rowsDelCultivo];
        if (this.statusFilter !== 'todas') {
            rows = rows.filter((row) => row.bucket === this.statusFilter);
        }
        this.data = rows;
    }

    handleRowAction(event) {
        const row = event.detail.row;
        if (!row) return;
        if (event.detail.action === 'secondary') {
            this.handleInformarPago(row);
            return;
        }
        this.openDocumentos(row);
    }

    handleInformarPago(vencimiento) {
        this.template.querySelector('c-informar-pago')?.show({
            title: 'Informar Pago',
            recordId: vencimiento.opportunityId,
            cuit: vencimiento.cuit,
            comprobante: vencimiento.numero,
            razonSocial: vencimiento.cuentaName,
            numero: vencimiento.numero,
            informarFactura: true,
            variant: 'sg',
            successMessage: 'Información de pago registrada exitosamente.'
        });
    }

    handlePagoInformado() {
        this.init();
    }

    async openDocumentos(vencimiento) {
        this.documentosFactura = vencimiento.file ? vencimiento : null;
        this.adjuntos = [];
        this.showDocumentos = true;
        if (!vencimiento.opportunityId) return;
        this.documentosLoading = true;
        try {
            this.adjuntos = (await getAdjuntosPago({ opportunityId: vencimiento.opportunityId })) || [];
        } catch (error) {
            this.onError(error);
        } finally {
            this.documentosLoading = false;
        }
    }

    handleVerFacturaPdf() {
        const factura = this.documentosFactura;
        this.closeDocumentos();
        if (factura) this.showPdf(factura);
    }

    closeDocumentos() {
        this.showDocumentos = false;
        this.adjuntos = [];
        this.documentosFactura = null;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    async handleExport() {
        const rows = this.data || [];
        if (!rows.length) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Sin facturas',
                    message: 'No hay facturas para exportar con el filtro actual.',
                    variant: 'info'
                })
            );
            return;
        }

        try {
            await ensureXlsxLoaded(this);
            const exportRows = rows.map((row) => ({
                Comprobante: row.numero || '',
                Fecha: row.fechaLabel || '',
                Concepto: row.concepto || '',
                Cultivo: row.cultivoLabel || '',
                Importe: row.importeLabel || '',
                Vencimiento: row.vtoLabel || '',
                Estado: row.statusLabel || ''
            }));
            const dateSuffix = new Date().toISOString().split('T')[0];
            const cultivoSuffix = this.selectedCultivoName ? `${this.selectedCultivoName.toLowerCase()}_` : '';
            downloadVentasWorkbook(
                `facturas_${cultivoSuffix}${this.statusFilter}_${dateSuffix}.xlsx`,
                exportRows,
                EXPORT_HEADERS,
                'Facturas'
            );
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Éxito',
                    message: `Se exportaron ${rows.length} facturas.`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.onError(error);
        }
    }

    showPdf(vencimiento) {
        if (!vencimiento.file) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Sin archivo',
                    message: 'Esta factura no tiene un PDF disponible.',
                    variant: 'info'
                })
            );
            return;
        }

        if (this.type === 'Comercio') {
            trackGa4Event('factura_vista', {
                portal: 'Comercio',
                origen: 'mis_facturas'
            });
        }

        this.template.querySelector('c-pdf-reader').show({
            documentId: vencimiento.file.id,
            title: 'Factura Eléctronica'
        });
    }

    onError(e) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: reduceErrors(e).join('\n'),
                variant: 'error',
                mode: 'sticky'
            })
        );
    }
}
