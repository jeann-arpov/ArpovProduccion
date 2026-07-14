public with sharing class ExportEstadoCuentaCyOPdfController {
    public List<String> tableHeaders { get; private set; }
    public List<List<String>> tableRows { get; private set; }
    public String accountName { get; private set; }
    public String accountCuit { get; private set; }
    public String fechaDesde { get; private set; }
    public String fechaHasta { get; private set; }
    public String totalComprobante { get; private set; }
    public List<String> totalRow { get; private set; }

    public ExportEstadoCuentaCyOPdfController() {
        tableHeaders = new List<String>();
        tableRows = new List<List<String>>();
        accountName = '';
        accountCuit = '';
        fechaDesde = '';
        fechaHasta = '';
        totalComprobante = '0';
        totalRow = new List<String>();

        String accountIdParam = ApexPages.currentPage().getParameters().get('accountId');
        String fechaDesdeParam = ApexPages.currentPage().getParameters().get('fechaDesde');
        String fechaHastaParam = ApexPages.currentPage().getParameters().get('fechaHasta');

        if (String.isBlank(accountIdParam) || String.isBlank(fechaDesdeParam) || String.isBlank(fechaHastaParam)) {
            return;
        }

        Date desde;
        Date hasta;
        try {
            desde = Date.valueOf(fechaDesdeParam);
            hasta = Date.valueOf(fechaHastaParam);
        } catch (Exception e) {
            return;
        }

        ExportEstadoCuentaCyOController.ExportData data =
            ExportEstadoCuentaCyOController.getEstadoCuenta((Id)accountIdParam, desde, hasta);

        List<String> headers = data.headers != null ? data.headers : new List<String>();
        List<List<String>> rows = data.rows != null ? data.rows : new List<List<String>>();

        if (!rows.isEmpty()) {
            accountCuit = rows[0].size() > 0 ? rows[0][0] : '';
            accountName = rows[0].size() > 1 ? rows[0][1] : '';
        }

        // Orden requerido en PDF:
        // Obtentor, N° Comprobante, Vencimiento, Divisa, Total Comprobante, Importe aplicado, Saldo pendiente
        List<Integer> selectedIndexes = new List<Integer>{ 2, 4, 3, 6, 9, 7, 8 };
        List<String> selectedHeaderNames = new List<String>{
            'Obtentor',
            'N° Comprobante',
            'Vencimiento',
            'Divisa',
            'Total Comprobante',
            'Importe aplicado',
            'Saldo pendiente'
        };

        for (Integer i = 0; i < selectedIndexes.size(); i++) {
            Integer sourceIndex = selectedIndexes[i];
            if (sourceIndex < headers.size()) {
                tableHeaders.add(selectedHeaderNames[i]);
            }
        }

        for (List<String> row : rows) {
            List<String> newRow = new List<String>();
            for (Integer sourceIndex : selectedIndexes) {
                if (sourceIndex < row.size()) {
                    newRow.add(row[sourceIndex]);
                }
            }
            tableRows.add(newRow);
        }

        applyArsFormatToAmountColumns();

        Integer saldoPendienteIndex = getSaldoPendienteColumnIndex(tableHeaders);
        Decimal total = 0;
        for (List<String> row : tableRows) {
            if (saldoPendienteIndex < row.size()) {
                total += parseNumber(row[saldoPendienteIndex]);
            }
        }
        totalComprobante = formatNumber(total);
        totalRow = buildTotalRow(tableHeaders.size(), totalComprobante);

        fechaDesde = formatDate(desde);
        fechaHasta = formatDate(hasta);
    }

    private String formatDate(Date value) {
        if (value == null) {
            return '';
        }
        return String.valueOf(value.day()).leftPad(2, '0') + '/' +
            String.valueOf(value.month()).leftPad(2, '0') + '/' +
            String.valueOf(value.year());
    }

    private Integer getTotalComprobanteColumnIndex(List<String> headers) {
        if (headers == null || headers.isEmpty()) {
            return 0;
        }

        for (Integer i = 0; i < headers.size(); i++) {
            String header = headers[i];
            if (header != null) {
                String normalized = header.toLowerCase().normalizeSpace();
                if (normalized.contains('total') && normalized.contains('comprobante') && !normalized.contains('aplicado')) {
                    return i;
                }
            }
        }

        return Math.min(5, headers.size() - 1);
    }

    private Integer getSaldoPendienteColumnIndex(List<String> headers) {
        if (headers == null || headers.isEmpty()) {
            return 0;
        }

        for (Integer i = 0; i < headers.size(); i++) {
            String header = headers[i];
            if (header != null) {
                String normalized = header.toLowerCase().normalizeSpace();
                if (normalized.contains('saldo') && (normalized.contains('pendiente') || normalized.contains('cobrar'))) {
                    return i;
                }
            }
        }

        return Math.max(headers.size() - 1, 0);
    }

    private Decimal parseNumber(String value) {
        if (String.isBlank(value)) {
            return 0;
        }

        String normalized = value.replaceAll('[^0-9,.-]', '');
        if (normalized.contains(',')) {
            normalized = normalized.replace('.', '').replace(',', '.');
        } else {
            Integer lastDot = normalized.lastIndexOf('.');
            if (lastDot > 0) {
                String intPart = normalized.substring(0, lastDot).replace('.', '');
                String decPart = normalized.substring(lastDot);
                normalized = intPart + decPart;
            }
        }

        try {
            return Decimal.valueOf(normalized);
        } catch (Exception e) {
            return 0;
        }
    }

    private String formatNumber(Decimal value) {
        if (value == null) {
            return '0';
        }
        Decimal scaled = value.setScale(2);
        String raw = scaled.toPlainString();
        List<String> parts = raw.split('\\.');
        String integerPart = parts.isEmpty() ? '0' : parts[0];
        String decimalPart = parts.size() > 1 ? parts[1] : '00';
        while (decimalPart.length() < 2) {
            decimalPart += '0';
        }

        Boolean isNegative = integerPart.startsWith('-');
        if (isNegative) {
            integerPart = integerPart.substring(1);
        }

        String withThousands = '';
        Integer count = 0;
        for (Integer i = integerPart.length() - 1; i >= 0; i--) {
            withThousands = integerPart.substring(i, i + 1) + withThousands;
            count++;
            if (count == 3 && i > 0) {
                withThousands = '.' + withThousands;
                count = 0;
            }
        }

        String decimalTwoDigits = decimalPart.substring(0, 2);
        String result = withThousands;
        if (decimalTwoDigits != '00') {
            result += ',' + decimalTwoDigits;
        }
        return isNegative ? '-' + result : result;
    }

    private void applyArsFormatToAmountColumns() {
        if (tableHeaders == null || tableHeaders.isEmpty() || tableRows == null || tableRows.isEmpty()) {
            return;
        }

        Set<Integer> amountIndexes = new Set<Integer>();
        for (Integer i = 0; i < tableHeaders.size(); i++) {
            String header = tableHeaders[i] == null ? '' : tableHeaders[i].toLowerCase().normalizeSpace();
            if (
                header.contains('total aplicado') ||
                header.contains('importe aplicado') ||
                header.contains('saldo a cobrar') ||
                header.contains('saldo pendiente') ||
                (header.contains('total') && header.contains('comprobante'))
            ) {
                amountIndexes.add(i);
            }
        }

        if (amountIndexes.isEmpty()) {
            return;
        }

        for (List<String> row : tableRows) {
            for (Integer idx : amountIndexes) {
                if (idx < row.size()) {
                    row[idx] = formatNumber(parseNumber(row[idx]));
                }
            }
        }
    }

    private List<String> buildTotalRow(Integer totalColumns, String totalValue) {
        List<String> result = new List<String>();
        if (totalColumns == null || totalColumns <= 0) {
            return result;
        }

        for (Integer i = 0; i < totalColumns; i++) {
            result.add('');
        }

        if (totalColumns >= 2) {
            result[totalColumns - 2] = '$';
            result[totalColumns - 1] = totalValue;
        } else {
            result[0] = totalValue;
        }
        return result;
    }
}