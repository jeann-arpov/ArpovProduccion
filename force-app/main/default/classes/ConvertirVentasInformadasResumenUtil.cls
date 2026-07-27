public with sharing class ConvertirVentasInformadasResumenUtil {

    public class Resumen {
        public Integer totalSeleccionados { get; private set; }
        public Integer convertibles { get; private set; }
        public Integer bolsasCero { get; private set; }
        public Integer noElegibles { get; private set; }
        public Integer autoventasNoConvertibles { get; private set; }

        public Boolean tieneAdvertencia {
            get { return bolsasCero > 0 || noElegibles > 0 || autoventasNoConvertibles > 0; }
        }

        public String mensajeAdvertencia { get; private set; }

        private Resumen(
            Integer totalSeleccionados,
            Integer convertibles,
            Integer bolsasCero,
            Integer noElegibles
        ) {
            this(totalSeleccionados, convertibles, bolsasCero, noElegibles, 0);
        }

        private Resumen(
            Integer totalSeleccionados,
            Integer convertibles,
            Integer bolsasCero,
            Integer noElegibles,
            Integer autoventasNoConvertibles
        ) {
            this.totalSeleccionados = totalSeleccionados;
            this.convertibles = convertibles;
            this.bolsasCero = bolsasCero;
            this.noElegibles = noElegibles;
            this.autoventasNoConvertibles = autoventasNoConvertibles;
            this.mensajeAdvertencia = formatearMensajeAdvertencia(this);
        }
    }

    public static final String MSG_CANTIDAD_BOLSAS_CERO =
        'Cantidad (Bolsas SF) = 0. Verificar Cantidad Kilos Informados';

    /** Ticket 1916: por debajo de este umbral de kilos totales → 0 bolsas. */
    public static final Decimal KILOS_TOTALES_MIN_PARA_BOLSA = 20;

    @TestVisible
    static Resumen buildResumenForTest(
        Integer totalSeleccionados,
        Integer convertibles,
        Integer bolsasCero,
        Integer noElegibles
    ) {
        return new Resumen(totalSeleccionados, convertibles, bolsasCero, noElegibles);
    }

    @TestVisible
    static Resumen buildResumenForTest(
        Integer totalSeleccionados,
        Integer convertibles,
        Integer bolsasCero,
        Integer noElegibles,
        Integer autoventasNoConvertibles
    ) {
        return new Resumen(
            totalSeleccionados,
            convertibles,
            bolsasCero,
            noElegibles,
            autoventasNoConvertibles
        );
    }

    public static Resumen analizar(Set<Id> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) {
            return new Resumen(0, 0, 0, 0);
        }

        List<Ventas_Informadas__c> records = [
            SELECT Cantidad_Bolsas_40__c, Resultado__c, Estado__c, Venta__c,
                   CUIT_Originante__c, CUIT_Destinatario__c, Categoria__c, Categoria_Portal__c,
                   Tipo_de_Comprobante__c, FC_Origen__c
            FROM Ventas_Informadas__c
            WHERE Id IN :recordIds
        ];

        Integer convertibles = 0;
        Integer bolsasCero = 0;
        Integer noElegibles = 0;
        Integer autoventasNoConvertibles = 0;

        for (Ventas_Informadas__c vi : records) {
            if (
                VentasInformadasExclusionUtil.esPendienteValidarAutoventa(vi)
                || VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(vi)
            ) {
                autoventasNoConvertibles++;
                continue;
            }

            if (vi.Resultado__c == MSG_CANTIDAD_BOLSAS_CERO || tieneBolsasCero(vi)) {
                bolsasCero++;
                continue;
            }

            if (!esElegibleParaConvertir(vi)) {
                noElegibles++;
                continue;
            }

            convertibles++;
        }

        return new Resumen(
            records.size(),
            convertibles,
            bolsasCero,
            noElegibles,
            autoventasNoConvertibles
        );
    }

    public static Boolean esElegibleParaConvertir(Ventas_Informadas__c vi) {
        if (vi == null) {
            return false;
        }
        if (
            VentasInformadasNcOrigenUtil.requiereFcOrigenParaConvertir(vi)
            && !VentasInformadasNcOrigenUtil.tieneFcOrigen(vi)
        ) {
            return false;
        }
        return vi.Venta__c == null
            && (vi.Estado__c == null || vi.Estado__c == 'Preprocesado')
            && vi.Resultado__c == 'OK'
            && !VentasInformadasExclusionUtil.esPendienteValidarAutoventa(vi)
            && !VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(vi);
    }

    /** Solo bolsas SF explícitamente en 0. Null = aún no calculado (no es cero). */
    public static Boolean tieneBolsasCero(Ventas_Informadas__c vi) {
        return vi != null && vi.Cantidad_Bolsas_40__c == 0;
    }

    /**
     * Al crear/actualizar: si ya se sabe que bolsas SF = 0 (campo en 0 o kilos &lt; 20),
     * setea Resultado sin esperar a la conversión.
     */
    public static void aplicarValidacionBolsasAlGuardar(List<Ventas_Informadas__c> ventas) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }
        for (Ventas_Informadas__c vi : ventas) {
            if (vi == null) {
                continue;
            }
            Decimal kilos = vi.Cantidad_de_Bolsas__c;
            if (kilos != null && kilos.abs() < KILOS_TOTALES_MIN_PARA_BOLSA) {
                vi.Cantidad_Bolsas_40__c = 0;
            }

            if (vi.Cantidad_Bolsas_40__c != null && vi.Cantidad_Bolsas_40__c > 0) {
                if (vi.Resultado__c == MSG_CANTIDAD_BOLSAS_CERO) {
                    vi.Resultado__c = null;
                }
                continue;
            }

            // null = todavía no calculado (p. ej. kilos ≥ 20 sin producto): no marcar aún.
            if (vi.Cantidad_Bolsas_40__c == null) {
                continue;
            }

            marcarResultadoBolsasCero(vi);
        }
    }

    @TestVisible
    private static void marcarResultadoBolsasCero(Ventas_Informadas__c vi) {
        if (String.isBlank(vi.Resultado__c) || vi.Resultado__c == 'OK') {
            vi.Resultado__c = MSG_CANTIDAD_BOLSAS_CERO;
            return;
        }
        if (!vi.Resultado__c.contains(MSG_CANTIDAD_BOLSAS_CERO)) {
            vi.Resultado__c = vi.Resultado__c + ';' + MSG_CANTIDAD_BOLSAS_CERO;
        }
    }

    /**
     * Calcula Cantidad_Bolsas_40__c desde kilos (misma regla que el preproceso) cuando aún es null.
     * Kilos &lt; 20 → 0 sin producto. Con producto → round(kilos / unidad).
     */
    public static void aplicarCalculoBolsasSiCorresponde(List<Ventas_Informadas__c> ventas) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }

        Set<Id> productoIds = new Set<Id>();
        for (Ventas_Informadas__c vi : ventas) {
            if (vi == null || vi.Cantidad_Bolsas_40__c != null) {
                continue;
            }
            Decimal kilos = vi.Cantidad_de_Bolsas__c;
            if (kilos == null) {
                continue;
            }
            if (kilos.abs() < KILOS_TOTALES_MIN_PARA_BOLSA) {
                vi.Cantidad_Bolsas_40__c = 0;
                continue;
            }
            if (vi.Producto__c != null) {
                productoIds.add(vi.Producto__c);
            }
        }

        Map<Id, Product2> productosById = new Map<Id, Product2>();
        if (!productoIds.isEmpty()) {
            productosById = new Map<Id, Product2>([
                SELECT Id, Unidad_de_Medida__c
                FROM Product2
                WHERE Id IN :productoIds
            ]);
        }

        for (Ventas_Informadas__c vi : ventas) {
            if (vi == null || vi.Cantidad_Bolsas_40__c != null || vi.Producto__c == null) {
                continue;
            }
            Product2 producto = productosById.get(vi.Producto__c);
            Decimal qty = unidadMedidaAQty(producto != null ? producto.Unidad_de_Medida__c : null);
            if (qty == null) {
                continue;
            }
            vi.Cantidad_Bolsas_40__c = BatchApexProcesaVentasInformadas.calcularBolsasDesdeKilos(
                vi.Cantidad_de_Bolsas__c,
                vi.Kilos_por_Bolsa__c,
                qty
            );
        }
    }

    @TestVisible
    private static void aplicarCalculoBolsasSiCorresponde(Ventas_Informadas__c vi) {
        if (vi == null) {
            return;
        }
        aplicarCalculoBolsasSiCorresponde(new List<Ventas_Informadas__c>{ vi });
    }

    /** Granel → 1; valor numérico de Unidad_de_Medida__c (ej. "40"); inválido → null. */
    @TestVisible
    private static Decimal unidadMedidaAQty(String unidad) {
        if (String.isBlank(unidad)) {
            return null;
        }
        if (unidad == 'Granel') {
            return 1;
        }
        try {
            Decimal qty = Decimal.valueOf(unidad);
            return qty == 0 ? null : qty;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Quita el mensaje de bolsas en cero del parcial (se recalcula); conserva otros errores.
     */
    @TestVisible
    private static String limpiarMensajeBolsasCero(String resultadoParcial) {
        if (String.isBlank(resultadoParcial)) {
            return '';
        }
        if (!resultadoParcial.contains(MSG_CANTIDAD_BOLSAS_CERO)) {
            return resultadoParcial;
        }
        List<String> partes = new List<String>();
        for (String parte : resultadoParcial.split(';')) {
            String trimmed = parte != null ? parte.trim() : '';
            if (String.isNotBlank(trimmed) && trimmed != MSG_CANTIDAD_BOLSAS_CERO) {
                partes.add(trimmed);
            }
        }
        return partes.isEmpty() ? '' : String.join(partes, ';');
    }

    /**
     * Resultado final: calcula bolsas si falta; conserva otros errores parciales;
     * bolsas 0 → mensaje; bolsas &gt; 0 → OK; bolsas null → vacío (no forzar OK ni bolsa 0).
     */
    public static String resolverResultadoFinal(Ventas_Informadas__c vi, String resultadoParcial) {
        aplicarCalculoBolsasSiCorresponde(vi);

        String parcial = limpiarMensajeBolsasCero(resultadoParcial);
        if (String.isNotEmpty(parcial)) {
            return parcial;
        }
        if (vi == null || vi.Cantidad_Bolsas_40__c == null) {
            return '';
        }
        if (tieneBolsasCero(vi)) {
            return MSG_CANTIDAD_BOLSAS_CERO;
        }
        return 'OK';
    }

    public static String formatearMensajeAdvertencia(Resumen resumen) {
        if (resumen == null || resumen.totalSeleccionados == 0) {
            return '';
        }

        List<String> lineas = new List<String>{
            'De los ' + resumen.totalSeleccionados + ' registros seleccionados:'
        };

        if (resumen.convertibles > 0) {
            lineas.add('• ' + resumen.convertibles + ' se convertirán correctamente.');
        }

        if (resumen.bolsasCero > 0) {
            lineas.add(
                '• ' + resumen.bolsasCero +
                ' tienen Cantidad (Bolsas SF) = 0 y no se convertirán. Verificar Kilos Totales informados.'
            );
        }

        if (resumen.autoventasNoConvertibles > 0) {
            lineas.add(
                '• ' + resumen.autoventasNoConvertibles +
                ' son autoventas/siembras propias con categoría Original o Pre Básica: quedan pendientes de validar con el comercio y no se convertirán. Si el comercio lo confirma, deben eliminarse manualmente.'
            );
        }

        if (resumen.noElegibles > 0) {
            lineas.add(
                '• ' + resumen.noElegibles +
                ' no son elegibles para convertir (ya procesados o con errores pendientes).'
            );
        }

        if (resumen.convertibles == 0) {
            lineas.add('• Ningún registro se convertirá en este proceso.');
        }

        return String.join(lineas, '\n');
    }

    public static String formatearMensajeResultado(
        Integer convertidas,
        Integer bolsasCero,
        Integer errores
    ) {
        List<String> lineas = new List<String>{ 'Proceso finalizado:' };

        if (convertidas > 0) {
            lineas.add('• ' + convertidas + ' ventas convertidas correctamente.');
        }

        if (bolsasCero > 0) {
            lineas.add(
                '• ' + bolsasCero +
                ' ventas informadas con Cantidad (Bolsas SF) = 0 no se convirtieron. Verificar Kilos Totales informados.'
            );
        }

        if (errores > 0) {
            lineas.add('• ' + errores + ' registros con error al convertir.');
        }

        if (convertidas == 0 && bolsasCero == 0 && errores == 0) {
            return 'Proceso finalizado: no se encontraron registros para convertir.';
        }

        if (convertidas > 0 && bolsasCero == 0 && errores == 0) {
            return 'Proceso finalizado: ' + convertidas + ' ventas convertidas correctamente.';
        }

        return String.join(lineas, '\n');
    }

    public static String formatearResultadoDesdeRegistros(Id loteId, Set<Id> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) {
            return null;
        }

        Integer convertidas = [
            SELECT COUNT()
            FROM Venta__c
            WHERE Lote__c = :loteId
        ];

        List<Ventas_Informadas__c> records = [
            SELECT Resultado__c, Venta__c, Cantidad_Bolsas_40__c, Estado__c
            FROM Ventas_Informadas__c
            WHERE Id IN :recordIds
        ];

        Integer bolsasCero = 0;
        Integer errores = 0;

        for (Ventas_Informadas__c vi : records) {
            if (vi.Venta__c != null) {
                continue;
            }

            if (vi.Resultado__c == MSG_CANTIDAD_BOLSAS_CERO || tieneBolsasCero(vi)) {
                bolsasCero++;
            } else if (
                vi.Resultado__c == 'OK'
                && (vi.Estado__c == null || vi.Estado__c == 'Preprocesado')
            ) {
                errores++;
            }
        }

        return formatearMensajeResultado(convertidas, bolsasCero, errores);
    }

    public static Set<Id> parseRecordIds(String recordIdsCsv) {
        Set<Id> recordIds = new Set<Id>();
        if (String.isBlank(recordIdsCsv)) {
            return recordIds;
        }

        for (String rawId : recordIdsCsv.split(',')) {
            String trimmedId = rawId != null ? rawId.trim() : null;
            if (!String.isBlank(trimmedId)) {
                recordIds.add((Id) trimmedId);
            }
        }

        return recordIds;
    }
}