import xlsx from '@salesforce/resourceUrl/XLSX';
import { loadScript } from 'lightning/platformResourceLoader';
import { normalizeCuit } from 'c/utils';

let xlsxLoadPromise;

export function ensureXlsxLoaded(component) {
    if (typeof XLSX !== 'undefined') {
        return Promise.resolve();
    }
    if (!xlsxLoadPromise) {
        xlsxLoadPromise = loadScript(component, xlsx);
    }
    return xlsxLoadPromise;
}

export function hasActiveFilters(searchTerm, columnFilters) {
    if (searchTerm && String(searchTerm).trim()) {
        return true;
    }
    return Object.values(columnFilters || {}).some(
        (value) => value && String(value).trim()
    );
}

export function filterVentas(ventas, searchTerm, columnFilters) {
    let filtered = [...ventas];

    if (searchTerm) {
        const term = searchTerm.toLowerCase();
        const termNorm = normalizeCuit(term);
        filtered = filtered.filter((v) =>
            v.numero?.toString().toLowerCase().includes(term) ||
            v.destinatario?.toLowerCase().includes(term) ||
            v.variedad?.toLowerCase().includes(term) ||
            (termNorm && v.cuitDest?.toLowerCase().includes(termNorm))
        );
    }

    Object.keys(columnFilters || {}).forEach((field) => {
        const filterValue = columnFilters[field];
        if (filterValue) {
            if (field === 'cuitDest') {
                const termNorm = normalizeCuit(filterValue);
                filtered = filtered.filter((v) =>
                    termNorm && normalizeCuit(v[field]?.toString() || '').includes(termNorm)
                );
            } else {
                const term = filterValue.toLowerCase();
                filtered = filtered.filter((v) =>
                    v[field]?.toString().toLowerCase().includes(term)
                );
            }
        }
    });

    return filtered;
}

export function sortVentas(ventas, sortField, sortDirection) {
    if (!sortField) {
        return [...ventas];
    }

    const sorted = [...ventas];
    sorted.sort((a, b) => {
        let aVal = a[sortField] || '';
        let bVal = b[sortField] || '';

        if (typeof aVal === 'number' && typeof bVal === 'number') {
            return sortDirection === 'asc' ? aVal - bVal : bVal - aVal;
        }

        aVal = aVal.toString().toLowerCase();
        bVal = bVal.toString().toLowerCase();

        if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1;
        if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1;
        return 0;
    });

    return sorted;
}

export async function exportVentasToExcel(component, { ventas, cantidadHeader, getCantidadValue, fileName, sheetName }) {
    await ensureXlsxLoaded(component);
    const headers = buildVentasExportHeaders(cantidadHeader);
    const rows = buildVentasExportRows(ventas, cantidadHeader, getCantidadValue);
    downloadVentasWorkbook(fileName, rows, headers, sheetName);
}

export function exportVentasToCsv({ ventas, cantidadHeader, getCantidadValue, fileName }) {
    const headers = buildVentasExportHeaders(cantidadHeader);
    const rows = buildVentasExportRows(ventas, cantidadHeader, getCantidadValue);
    const csvContent = buildVentasCsvContent(headers, rows);
    downloadVentasCsv(fileName, csvContent);
}

function escapeCsvField(value) {
    const text = value == null ? '' : String(value);
    return `"${text.replace(/"/g, '""')}"`;
}

export function buildVentasCsvContent(headers, rows) {
    const lines = [headers.map(escapeCsvField).join(',')];
    rows.forEach((row) => {
        lines.push(headers.map((header) => escapeCsvField(row[header])).join(','));
    });
    return '\uFEFF' + lines.join('\n');
}

export function downloadVentasCsv(fileName, csvContent) {
    const base64 = window.btoa(unescape(encodeURIComponent(csvContent)));
    const safeName = fileName.endsWith('.csv') ? fileName : `${fileName}.csv`;
    const link = document.createElement('a');
    link.href = 'data:application/octet-stream;base64,' + base64;
    link.download = safeName;
    link.style.display = 'none';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

export async function exportVentas(component, { format, ventas, cantidadHeader, getCantidadValue, fileName, sheetName }) {
    if (format === 'csv') {
        exportVentasToCsv({ ventas, cantidadHeader, getCantidadValue, fileName });
        return;
    }
    await exportVentasToExcel(component, { ventas, cantidadHeader, getCantidadValue, fileName, sheetName });
}

export function buildVentasExportHeaders(cantidadHeader) {
    return [
        'Estado',
        'Campaña Agrícola',
        'Destinatario',
        'CUIT Destinatario',
        'Variedad',
        'Categoría',
        cantidadHeader,
        'Tipo Comprobante',
        'Fecha Facturación',
        'N° Comprobante',
        'Línea de Comprobante',
        'Venta Informada'
    ];
}

export function buildVentasExportRows(ventas, cantidadHeader, getCantidadValue) {
    return ventas.map((v) => ({
        Estado: v.estado || '',
        'Campaña Agrícola': v.campanaAgri || '',
        Destinatario: v.destinatario || '',
        'CUIT Destinatario': v.cuitDest || '',
        Variedad: v.variedad || '',
        Categoría: v.categoria || '',
        [cantidadHeader]: getCantidadValue(v),
        'Tipo Comprobante': v.tipoCompExterno || '',
        'Fecha Facturación': v.fechaFact || '',
        'N° Comprobante': v.numero || '',
        'Línea de Comprobante': v.lineaComprobante || '',
        'Venta Informada': v.name || ''
    }));
}

/**
 * Descarga un workbook XLSX vía data URL + octet-stream (compatible con Locker / Experience Cloud).
 */
export function downloadVentasWorkbook(fileName, rows, headers, sheetName = 'Ventas') {
    const ws = XLSX.utils.json_to_sheet(rows, { header: headers });
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, sheetName);

    const base64 = XLSX.write(wb, { bookType: 'xlsx', type: 'base64' });
    const safeName = fileName.endsWith('.xlsx') ? fileName : `${fileName}.xlsx`;

    const link = document.createElement('a');
    link.href = 'data:application/octet-stream;base64,' + base64;
    link.download = safeName;
    link.style.display = 'none';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}