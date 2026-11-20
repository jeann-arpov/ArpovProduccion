/**
 * XLSX mínimo (ZIP sin compresión + celdas inline).
 * No usa SheetJS: en Experience Cloud, XLSX.write sobre el proxy de Locker
 * bloquea el hilo principal y Chrome muestra "Esta página no responde",
 * con cualquier cantidad de filas.
 */

const CRC_TABLE = (() => {
    const table = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
        let c = n;
        for (let k = 0; k < 8; k++) {
            c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
        }
        table[n] = c >>> 0;
    }
    return table;
})();

const STYLES_XML = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/></numFmts>
<fonts count="1"><font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/></font></fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
</cellXfs>
</styleSheet>`;

function crc32(bytes) {
    let c = 0xffffffff;
    for (let i = 0; i < bytes.length; i++) {
        c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
    }
    return (c ^ 0xffffffff) >>> 0;
}

function encodeUtf8(text) {
    if (typeof TextEncoder !== 'undefined') {
        return new TextEncoder().encode(text);
    }
    const utf8 = unescape(encodeURIComponent(text));
    const out = new Uint8Array(utf8.length);
    for (let i = 0; i < utf8.length; i++) {
        out[i] = utf8.charCodeAt(i);
    }
    return out;
}

function concatBytes(parts) {
    let length = 0;
    parts.forEach((part) => {
        length += part.length;
    });
    const out = new Uint8Array(length);
    let offset = 0;
    parts.forEach((part) => {
        out.set(part, offset);
        offset += part.length;
    });
    return out;
}

function u16(value) {
    return Uint8Array.of(value & 0xff, (value >>> 8) & 0xff);
}

function u32(value) {
    return Uint8Array.of(value & 0xff, (value >>> 8) & 0xff, (value >>> 16) & 0xff, (value >>> 24) & 0xff);
}

function dosDateTime(date) {
    const time =
        ((date.getHours() & 0x1f) << 11) |
        ((date.getMinutes() & 0x3f) << 5) |
        (Math.floor(date.getSeconds() / 2) & 0x1f);
    const day =
        (((date.getFullYear() - 1980) & 0x7f) << 9) |
        (((date.getMonth() + 1) & 0x0f) << 5) |
        (date.getDate() & 0x1f);
    return { time, day };
}

function zipStore(files) {
    const { time, day } = dosDateTime(new Date());
    const locals = [];
    const centrals = [];
    let offset = 0;

    files.forEach((file) => {
        const name = encodeUtf8(file.name);
        const data = file.data;
        const crc = crc32(data);
        const local = concatBytes([
            u32(0x04034b50),
            u16(20),
            u16(0),
            u16(0),
            u16(time),
            u16(day),
            u32(crc),
            u32(data.length),
            u32(data.length),
            u16(name.length),
            u16(0),
            name,
            data
        ]);
        locals.push(local);
        centrals.push(
            concatBytes([
                u32(0x02014b50),
                u16(20),
                u16(20),
                u16(0),
                u16(0),
                u16(time),
                u16(day),
                u32(crc),
                u32(data.length),
                u32(data.length),
                u16(name.length),
                u16(0),
                u16(0),
                u16(0),
                u16(0),
                u32(0),
                u32(offset),
                name
            ])
        );
        offset += local.length;
    });

    const central = concatBytes(centrals);
    const eocd = concatBytes([
        u32(0x06054b50),
        u16(0),
        u16(0),
        u16(files.length),
        u16(files.length),
        u32(central.length),
        u32(offset),
        u16(0)
    ]);
    return concatBytes([...locals, central, eocd]);
}

function xmlEscape(value) {
    return String(value == null ? '' : value)
        .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function columnName(index) {
    let n = index + 1;
    let name = '';
    while (n > 0) {
        const rem = (n - 1) % 26;
        name = String.fromCharCode(65 + rem) + name;
        n = Math.floor((n - 1) / 26);
    }
    return name;
}

function safeSheetName(name, used) {
    const cleaned = String(name || 'Hoja')
        .replace(/[\\/*?:[\]]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 31) || 'Hoja';
    let candidate = cleaned;
    let i = 2;
    while (used.has(candidate)) {
        const suffix = ` ${i}`;
        candidate = `${cleaned.slice(0, 31 - suffix.length)}${suffix}`;
        i++;
    }
    used.add(candidate);
    return candidate;
}

function isDateValue(value) {
    return Object.prototype.toString.call(value) === '[object Date]' && !Number.isNaN(value.getTime());
}

function excelSerial(date) {
    const utc = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
    return Math.round((utc - Date.UTC(1899, 11, 30)) / 86400000);
}

function cellXml(column, rowNumber, value) {
    const ref = `${column}${rowNumber}`;
    if (isDateValue(value)) {
        return `<c r="${ref}" s="1" t="n"><v>${excelSerial(value)}</v></c>`;
    }
    if (typeof value === 'number' && Number.isFinite(value)) {
        return `<c r="${ref}" t="n"><v>${value}</v></c>`;
    }
    const raw = value == null ? '' : String(value);
    const space = /^\s|\s$/.test(raw) ? ' xml:space="preserve"' : '';
    return `<c r="${ref}" t="inlineStr"><is><t${space}>${xmlEscape(raw)}</t></is></c>`;
}

function rowXml(rowNumber, values) {
    const cells = values.map((value, index) => cellXml(columnName(index), rowNumber, value));
    return `<row r="${rowNumber}">${cells.join('')}</row>`;
}

function worksheetXml(headers, rows) {
    const headerList = headers || [];
    const lines = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
        rowXml(1, headerList)
    ];
    (rows || []).forEach((row, index) => {
        const values = headerList.map((header) => (row == null ? '' : row[header]));
        lines.push(rowXml(index + 2, values));
    });
    lines.push('</sheetData></worksheet>');
    return lines.join('');
}

function contentTypesXml(sheetCount) {
    const overrides = [
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    ];
    for (let i = 1; i <= sheetCount; i++) {
        overrides.push(
            `<Override PartName="/xl/worksheets/sheet${i}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`
        );
    }
    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
${overrides.join('')}
</Types>`;
}

function workbookXml(sheetNames) {
    const sheets = sheetNames
        .map(
            (name, index) =>
                `<sheet name="${xmlEscape(name)}" sheetId="${index + 1}" r:id="rId${index + 1}"/>`
        )
        .join('');
    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>${sheets}</sheets>
</workbook>`;
}

function workbookRelsXml(sheetCount) {
    const rels = [];
    for (let i = 1; i <= sheetCount; i++) {
        rels.push(
            `<Relationship Id="rId${i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i}.xml"/>`
        );
    }
    rels.push(
        `<Relationship Id="rId${sheetCount + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>`
    );
    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${rels.join('')}
</Relationships>`;
}

const ROOT_RELS = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>`;

export function buildXlsxBytes(sheets) {
    const source = sheets && sheets.length ? sheets : [{ name: 'Hoja', headers: [], rows: [] }];
    const usedNames = new Set();
    const named = source.map((sheet) => ({
        name: safeSheetName(sheet.name, usedNames),
        headers: sheet.headers || [],
        rows: sheet.rows || []
    }));

    const files = [
        { name: '[Content_Types].xml', data: encodeUtf8(contentTypesXml(named.length)) },
        { name: '_rels/.rels', data: encodeUtf8(ROOT_RELS) },
        { name: 'xl/workbook.xml', data: encodeUtf8(workbookXml(named.map((sheet) => sheet.name))) },
        { name: 'xl/_rels/workbook.xml.rels', data: encodeUtf8(workbookRelsXml(named.length)) },
        { name: 'xl/styles.xml', data: encodeUtf8(STYLES_XML) }
    ];
    named.forEach((sheet, index) => {
        files.push({
            name: `xl/worksheets/sheet${index + 1}.xml`,
            data: encodeUtf8(worksheetXml(sheet.headers, sheet.rows))
        });
    });
    return zipStore(files);
}
