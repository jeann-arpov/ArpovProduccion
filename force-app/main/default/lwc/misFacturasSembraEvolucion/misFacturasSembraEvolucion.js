import { LightningElement, track, api } from 'lwc';
import getVencimientos from '@salesforce/apex/MisFacturasController.getVencimientos';
import { reduceErrors } from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { doRequest } from 'c/utils';
import { trackGa4Event } from 'c/portalGa4Events';

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
    const amount = Number(total).toLocaleString('es-AR', { maximumFractionDigits: 0 });
    const prefix = moneda && String(moneda).toUpperCase().includes('ARS') ? 'ARS' : 'USD';
    return `${prefix} ${amount}`;
}

function isPagada(stage) {
    return /pagad/i.test(stage || '');
}

function resolveStatus(row) {
    if (isPagada(row.oppStage)) {
        return { label: 'Pagada', tone: 'ok', bucket: 'pagadas' };
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
    statusFilter = 'todas';
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
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    get countTodas() {
        return this.vencimientos.length;
    }

    get countFacturadas() {
        return this.vencimientos.filter((row) => row.bucket === 'facturadas').length;
    }

    get countPagadas() {
        return this.vencimientos.filter((row) => row.bucket === 'pagadas').length;
    }

    get pillTodasClass() {
        return this.statusFilter === 'todas' ? 'pill is-active' : 'pill';
    }

    get pillFacturadasClass() {
        return this.statusFilter === 'facturadas' ? 'pill is-active' : 'pill';
    }

    get pillPagadasClass() {
        return this.statusFilter === 'pagadas' ? 'pill is-active' : 'pill';
    }

    async init() {
        this.initialized = true;

        await doRequest.call(this, async () => {
            const vencimientos = await getVencimientos({ type: this.type || 'Productor' });

            this.vencimientos = (vencimientos || []).map((vencimiento, idx) => {
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
                vencimiento.actionDisabled = vencimiento.disableVerFactura;
                vencimiento.bucket = status.bucket;
                return vencimiento;
            });

            this.applyFilters();
        });
    }

    handlePill(event) {
        this.statusFilter = event.currentTarget.dataset.filter;
        this.applyFilters();
    }

    applyFilters() {
        let rows = [...this.vencimientos];
        if (this.statusFilter !== 'todas') {
            rows = rows.filter((row) => row.bucket === this.statusFilter);
        }
        this.data = rows;
    }

    handleRowAction(event) {
        const row = event.detail.row;
        if (!row) return;
        this.showPdf(row);
    }

    handleExport() {
        const header = ['Comprobante', 'Fecha', 'Concepto', 'Cultivo', 'Importe', 'Vto', 'Estado'];
        const lines = this.data.map((row) =>
            [row.numero, row.fechaLabel, row.concepto, row.cultivoLabel, row.importeLabel, row.vtoLabel, row.statusLabel]
                .map((value) => `"${String(value || '').replace(/"/g, '""')}"`)
                .join(';')
        );
        const csv = `\uFEFF${[header.join(';'), ...lines].join('\n')}`;
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = 'facturas.csv';
        link.click();
        URL.revokeObjectURL(url);
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
