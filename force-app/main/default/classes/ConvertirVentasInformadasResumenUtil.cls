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
                   CUIT_Originante__c, CUIT_Destinatario__c, Categoria__c, Categoria_Portal__c
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
        return vi.Venta__c == null
            && (vi.Estado__c == null || vi.Estado__c == 'Preprocesado')
            && vi.Resultado__c == 'OK'
            && !VentasInformadasExclusionUtil.esPendienteValidarAutoventa(vi)
            && !VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(vi);
    }

    public static Boolean tieneBolsasCero(Ventas_Informadas__c vi) {
        return vi.Cantidad_Bolsas_40__c == null || vi.Cantidad_Bolsas_40__c == 0;
    }

    /**
     * Resultado final del preproceso: conserva errores parciales; si no hay errores,
     * marca bolsas en cero o OK según Cantidad_Bolsas_40__c.
     */
    public static String resolverResultadoFinal(Ventas_Informadas__c vi, String resultadoParcial) {
        if (String.isNotEmpty(resultadoParcial)) {
            return resultadoParcial;
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