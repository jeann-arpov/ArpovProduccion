import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEstadoCuenta from '@salesforce/apex/ExportEstadoCuentaCyOController.getEstadoCuenta';
import sendEstadoCuentaEmail from '@salesforce/apex/ExportEstadoCuentaCyOController.sendEstadoCuentaEmail';

export default class ExportEstadoCuentaCyO extends LightningElement {
    @api recordId;
    isExporting = false;
    createdDateFrom;
    createdDateTo;
    email;

    handleDateFromChange(event) {
        this.createdDateFrom = event.detail.value;
    }

    handleDateToChange(event) {
        this.createdDateTo = event.detail.value;
    }

    handleEmailChange(event) {
        this.email = event.detail.value;
    }

    get isExportDisabled() {
        return this.isExporting || !this.createdDateFrom || !this.createdDateTo || !this.email;
    }

    handleExport() {
        if (!this.createdDateFrom || !this.createdDateTo || !this.email) {
            this.showToast('Campos requeridos', 'Selecciona fecha de creación desde y hasta, y proporciona un correo electrónico.', 'warning');
            return;
        }

        if (this.createdDateFrom > this.createdDateTo) {
            this.showToast('Rango inválido', 'La fecha desde no puede ser mayor que la fecha hasta.', 'warning');
            return;
        }

        this.isExporting = true;

        sendEstadoCuentaEmail({
            accountId: this.recordId,
            fechaCreacionDesde: this.createdDateFrom,
            fechaCreacionHasta: this.createdDateTo,
            email: this.email
        })
            .then(() => {
                this.showToast('Envío exitoso', 'El estado de cuenta ha sido enviado al correo electrónico.', 'success');
            })
            .catch((error) => {
                const msg = error?.body?.message || error?.message || 'Error desconocido';
                this.showToast('Error', msg, 'error');
            })
            .finally(() => {
                this.isExporting = false;
            });
    }

    downloadFormattedExcel(headers, rows) {
        const accountName = this.escapeHtml(rows[0]?.[1] || '');
        const accountCuit = this.escapeHtml(rows[0]?.[0] || '');
        const formattedFrom = this.formatInputDate(this.createdDateFrom);
        const formattedTo = this.formatInputDate(this.createdDateTo);

        const tableHeaders = (headers || []).slice(2);
        const tableRows = (rows || []).map((row) => (row || []).slice(2));

        const totalComprobanteIndex = this.getTotalComprobanteColumnIndex(tableHeaders);
        let totalComprobante = 0;
        tableRows.forEach((row) => {
            totalComprobante += this.parseNumber(row[totalComprobanteIndex]);
        });

        const renderHeaderCells = tableHeaders
            .map((header) => `<th>${this.escapeHtml(header)}</th>`)
            .join('');

        const renderBodyRows = tableRows
            .map((row) => `<tr>${row.map((cell) => `<td>${this.escapeHtml(cell)}</td>`).join('')}</tr>`)
            .join('');

        const numEmptyCells = Math.max(tableHeaders.length - 2, 0);
        let totalRowCells = '';
        for (let i = 0; i < numEmptyCells; i++) {
            totalRowCells += '<td></td>';
        }
        totalRowCells += `<td>$</td>` +
            `<td><strong>${this.formatNumber(totalComprobante)}</strong></td>`;

        const html = `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8" />
    <style>
        body { font-family: Calibri, Arial, sans-serif; font-size: 12pt; }
        .sheet { width: 100%; }
        .top { width: 100%; border-collapse: collapse; margin-bottom: 14px; }
        .top td { vertical-align: top; padding: 2px 4px; }
        .title { text-align: center; font-size: 16pt; font-weight: bold; padding: 10px 0; }
        .account-name { font-size: 14pt; font-weight: bold; }
        .account-cuit { font-size: 13pt; font-weight: bold; }
        .date-label { font-weight: bold; width: 85px; }
        .date-value { min-width: 110px; }
        .table { width: 100%; border-collapse: collapse; }
        .table th { background: #008000; color: #ffffff; border: 1px solid #5ba35b; padding: 6px 8px; text-align: left; }
        .table td { border: 1px solid #5ba35b; padding: 6px 8px; }
        .table tfoot td { border-top: 2px solid #5ba35b; font-size: 13pt; }
    </style>
</head>
<body>
    <div class="sheet">
        <div class="title">ESTADO DE CUENTA</div>
        <table class="top">
            <tr>
                <td style="width: 55%;">
                    <div class="account-name">${accountName}</div>
                    <div class="account-cuit">${accountCuit}</div>
                </td>
                <td> </td>
                <td> </td>
                <td> </td>
                <td> </td>
                <td style="width: 20%;">
                    <table>
                        <tr><td class="date-label">Desde:</td><td class="date-value">${this.escapeHtml(formattedFrom)}</td></tr>
                        <tr><td class="date-label">Hasta:</td><td class="date-value">${this.escapeHtml(formattedTo)}</td></tr>
                    </table>
                </td>
            </tr>
        </table>

        <table class="table">
            <thead>
                <tr>${renderHeaderCells}</tr>
            </thead>
            <tbody>
                ${renderBodyRows}
            </tbody>
            <tfoot>
                <tr>${totalRowCells}</tr>
            </tfoot>
        </table>
    </div>
</body>
</html>`;

        const fileName = 'Estado_de_Cuenta_CyO.xls';

        try {
            const blob = new Blob(['\uFEFF' + html], { type: 'application/vnd.ms-excel;charset=utf-8;' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = fileName;
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);
        } catch (e) {
            const link = document.createElement('a');
            link.href = 'data:application/vnd.ms-excel;charset=utf-8,' + encodeURIComponent(html);
            link.download = fileName;
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
    }

    formatInputDate(value) {
        if (!value) return '';
        const parts = String(value).split('-');
        if (parts.length !== 3) return String(value);
        return `${parts[2]}/${parts[1]}/${parts[0]}`;
    }

    parseNumber(value) {
        if (value == null || value === '') return 0;
        const normalized = String(value).replace(/\./g, '').replace(',', '.').replace(/[^0-9.-]/g, '');
        const parsed = Number(normalized);
        return Number.isFinite(parsed) ? parsed : 0;
    }

    formatNumber(value) {
        return new Intl.NumberFormat('es-AR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(value || 0);
    }

    getTotalComprobanteColumnIndex(tableHeaders) {
        if (!tableHeaders || tableHeaders.length === 0) {
            return 0;
        }

        const exactIndex = tableHeaders.findIndex((header) => {
            const normalized = String(header || '')
                .toLowerCase()
                .normalize('NFD')
                .replace(/[\u0300-\u036f]/g, '');
            return normalized.includes('total') && normalized.includes('comprobante') && !normalized.includes('aplicado');
        });

        if (exactIndex >= 0) {
            return exactIndex;
        }

        return Math.min(5, tableHeaders.length - 1);
    }

    escapeHtml(value) {
        if (value == null) return '';
        return String(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant, mode: 'dismissable' })
        );
    }
}