import xlsx from "@salesforce/resourceUrl/XLSX";
import { loadScript } from "lightning/platformResourceLoader";
import { normalizeCuit } from "c/utils";
import { buildXlsxBytes } from "./xlsxStore";

let xlsxLoadPromise;

export function ensureXlsxLoaded(component) {
  if (typeof XLSX !== "undefined") {
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
    filtered = filtered.filter(
      (v) =>
        v.numero?.toString().toLowerCase().includes(term) ||
        v.destinatario?.toLowerCase().includes(term) ||
        v.variedad?.toLowerCase().includes(term) ||
        (termNorm && v.cuitDest?.toLowerCase().includes(termNorm))
    );
  }

  Object.keys(columnFilters || {}).forEach((field) => {
    const filterValue = columnFilters[field];
    if (filterValue) {
      if (field === "cuitDest") {
        const termNorm = normalizeCuit(filterValue);
        filtered = filtered.filter(
          (v) =>
            termNorm &&
            normalizeCuit(v[field]?.toString() || "").includes(termNorm)
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
    let aVal = a[sortField] || "";
    let bVal = b[sortField] || "";

    if (typeof aVal === "number" && typeof bVal === "number") {
      return sortDirection === "asc" ? aVal - bVal : bVal - aVal;
    }

    aVal = aVal.toString().toLowerCase();
    bVal = bVal.toString().toLowerCase();

    if (aVal < bVal) return sortDirection === "asc" ? -1 : 1;
    if (aVal > bVal) return sortDirection === "asc" ? 1 : -1;
    return 0;
  });

  return sorted;
}

export async function exportVentasToExcel(
  // eslint-disable-next-line no-unused-vars -- la exportación ya no carga SheetJS en el host
  _component,
  { ventas, cantidadHeader, getCantidadValue, fileName, sheetName }
) {
  const headers = buildVentasExportHeaders(cantidadHeader);
  const rows = buildVentasExportRows(ventas, cantidadHeader, getCantidadValue);
  downloadVentasWorkbook(fileName, rows, headers, sheetName);
}

export function exportVentasToCsv({
  ventas,
  cantidadHeader,
  getCantidadValue,
  fileName
}) {
  const headers = buildVentasExportHeaders(cantidadHeader);
  const rows = buildVentasExportRows(ventas, cantidadHeader, getCantidadValue);
  const csvContent = buildVentasCsvContent(headers, rows);
  downloadVentasCsv(fileName, csvContent);
}

function escapeCsvField(value) {
  const text = value == null ? "" : String(value);
  return `"${text.replace(/"/g, '""')}"`;
}

export function buildVentasCsvContent(headers, rows) {
  const lines = [headers.map(escapeCsvField).join(",")];
  rows.forEach((row) => {
    lines.push(headers.map((header) => escapeCsvField(row[header])).join(","));
  });
  return "\uFEFF" + lines.join("\n");
}

export function downloadVentasCsv(fileName, csvContent) {
  const safeName = fileName.endsWith(".csv") ? fileName : `${fileName}.csv`;
  downloadBytes(safeName, encodeDownloadBytes(csvContent));
}

function yieldToBrowser() {
  return new Promise((resolve) => {
    // Deja cerrar el modal y pintar el indicador antes de armar el archivo.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(resolve, 0);
  });
}

export async function exportVentas(
  component,
  { format, ventas, cantidadHeader, getCantidadValue, fileName, sheetName }
) {
  await yieldToBrowser();
  if (format === "csv") {
    exportVentasToCsv({ ventas, cantidadHeader, getCantidadValue, fileName });
    return;
  }
  await exportVentasToExcel(component, {
    ventas,
    cantidadHeader,
    getCantidadValue,
    fileName,
    sheetName
  });
}

export function buildVentasExportHeaders(cantidadHeader) {
  return [
    "Estado",
    "Campaña Agrícola",
    "Destinatario",
    "CUIT Destinatario",
    "Variedad",
    "Categoría",
    cantidadHeader,
    "Tipo Comprobante",
    "Fecha Facturación",
    "N° Comprobante",
    "Línea de Comprobante",
    "Venta Informada",
    "Provincia",
    "Localidad"
  ];
}

export function buildVentasExportRows(
  ventas,
  cantidadHeader,
  getCantidadValue
) {
  return ventas.map((v) => ({
    Estado: v.estado || "",
    "Campaña Agrícola": v.campanaAgri || "",
    Destinatario: v.destinatario || "",
    "CUIT Destinatario": v.cuitDest || "",
    Variedad: v.variedad || "",
    Categoría: v.categoria || "",
    [cantidadHeader]: getCantidadValue(v),
    "Tipo Comprobante": v.tipoCompExterno || "",
    "Fecha Facturación": v.fechaFact || "",
    "N° Comprobante": v.numero || "",
    "Línea de Comprobante": v.lineaComprobante || "",
    "Venta Informada": v.name || "",
    Provincia: v.provinciaUbicacion || "",
    Localidad: v.localidadUbicacion || ""
  }));
}

/**
 * Descarga un workbook XLSX. El archivo se arma sin SheetJS y se baja con Blob,
 * para que Experience Cloud no congele la pestaña al exportar.
 */
export function downloadVentasWorkbook(
  fileName,
  rows,
  headers,
  sheetName = "Ventas"
) {
  downloadVentasWorkbookSheets(fileName, [{ name: sheetName, rows, headers }]);
}

export function downloadVentasWorkbookSheets(fileName, sheets) {
  const safeName = fileName.endsWith(".xlsx") ? fileName : `${fileName}.xlsx`;
  downloadBytes(safeName, buildXlsxBytes(sheets));
}

function encodeDownloadBytes(text) {
  if (typeof TextEncoder !== "undefined") {
    return new TextEncoder().encode(text);
  }
  const utf8 = unescape(encodeURIComponent(text));
  const out = new Uint8Array(utf8.length);
  for (let i = 0; i < utf8.length; i++) {
    out[i] = utf8.charCodeAt(i);
  }
  return out;
}

function downloadBytes(fileName, bytes) {
  const link = document.createElement("a");
  link.download = fileName;
  link.style.display = "none";
  let objectUrl;
  try {
    const blob = new Blob([bytes], { type: "application/octet-stream" });
    objectUrl = URL.createObjectURL(blob);
    link.href = objectUrl;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.warn(
      "No se pudo crear el Blob de descarga. Se usa data URL.",
      error
    );
    link.href = "data:application/octet-stream;base64," + bytesToBase64(bytes);
  }
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  if (objectUrl) {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => URL.revokeObjectURL(objectUrl), 2000);
  }
}

function bytesToBase64(bytes) {
  let binary = "";
  const chunkSize = 8192;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}
