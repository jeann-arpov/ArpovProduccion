/**
 * Normaliza Ventas Informadas que ingresan por API o insert/update directo,
 * aplicando la misma lógica que Nueva Venta e importación Excel.
 * Se activa/desactiva con el Hierarchy Custom Setting Ventas_Informadas_Settings__c.
 */
public without sharing class VentasInformadasApiNormalizer {

    private static final Map<String, String> TIPO_COMPROBANTE_MAP = new Map<String, String>{
        'FC' => 'FC',
        'NC' => 'NC',
        'Remito' => 'FC',
        'REMITO' => 'FC',
        'Remito de Devolución' => 'NC',
        'Remito de Devolucion' => 'NC'
    };

    @TestVisible
    private static Boolean forceEnabledForTests = false;

    @TestVisible
    public static Boolean tieneCampoTipoComprobanteExterno() {
        return Schema.SObjectType.Ventas_Informadas__c.fields.getMap()
            .containsKey('Tipo_Comprobante_Externo__c');
    }

    @TestVisible
    public static Boolean puedeEscribirTipoComprobanteExterno() {
        return tieneCampoTipoComprobanteExterno();
    }

    @TestVisible
    public static Boolean puedeLeerTipoComprobanteExterno(Ventas_Informadas__c venta) {
        return venta != null
            && tieneCampoTipoComprobanteExterno()
            && venta.getPopulatedFieldsAsMap().containsKey('Tipo_Comprobante_Externo__c');
    }

    /** Compatibilidad con scripts/backfill que consultan SOQL parcial. */
    public static Boolean campoTipoComprobanteExternoDisponible(Ventas_Informadas__c venta) {
        return puedeLeerTipoComprobanteExterno(venta);
    }

    @TestVisible
    public static Boolean isNormalizacionActiva() {
        if (Test.isRunningTest() && forceEnabledForTests) {
            return true;
        }
        Ventas_Informadas_Settings__c cfg = Ventas_Informadas_Settings__c.getOrgDefaults();
        if (cfg != null && cfg.Normalizar_Ingreso_Externo__c == false) {
            return false;
        }
        return true;
    }

    @TestVisible
    public static void normalizarBeforeSave(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Ventas_Informadas__c> oldMap
    ) {
        if (!isNormalizacionActiva() || ventas == null || ventas.isEmpty()) {
            return;
        }

        List<Ventas_Informadas__c> candidatas = new List<Ventas_Informadas__c>();
        for (Ventas_Informadas__c venta : ventas) {
            Ventas_Informadas__c oldV =
                oldMap != null && venta.Id != null ? oldMap.get(venta.Id) : null;
            if (debeNormalizar(venta, oldV)) {
                candidatas.add(venta);
            }
        }
        if (candidatas.isEmpty()) {
            return;
        }

        enriquecerComoPortal(candidatas, true);
    }

    /**
     * Aplica limpieza, variedad INASE, campaña y CUIT como el portal/import.
     * @param strict si true, addError en fallos; si false, acumula avisos sin bloquear DML.
     */
    public static List<String> enriquecerComoPortal(
        List<Ventas_Informadas__c> ventas,
        Boolean strict
    ) {
        List<String> avisos = new List<String>();
        if (ventas == null || ventas.isEmpty()) {
            return avisos;
        }

        for (Ventas_Informadas__c venta : ventas) {
            limpiarCamposBasicos(venta);
            aplicarTipoComprobante(venta);
        }

        List<Map<String, Object>> pseudoRows = new List<Map<String, Object>>();
        for (Ventas_Informadas__c venta : ventas) {
            pseudoRows.add(new Map<String, Object>{
                'Campana_de_Ventas__c' => venta.Campana_de_Ventas__c,
                'Variedad__c' => venta.Variedad__c
            });
        }

        Map<String, Variedad__c> variedadByName =
            lwcVentasImportFromExcel.getVariedadesPorNombre(pseudoRows);
        Map<String, Campana_Agricola__c> campanaByCultivoAno =
            lwcVentasImportFromExcel.getCampanasPorCultivoYAno(pseudoRows, variedadByName);

        for (Ventas_Informadas__c venta : ventas) {
            avisos.addAll(resolverVariedadYCuentas(venta, variedadByName, strict));
            avisos.addAll(resolverCampanaAgricola(venta, variedadByName, campanaByCultivoAno, strict));
        }
        return avisos;
    }

    @TestVisible
    private static Boolean debeNormalizar(Ventas_Informadas__c venta, Ventas_Informadas__c oldV) {
        if (venta == null) {
            return false;
        }
        if (venta.Variedad_INASE__c != null && venta.Campana_Agricola__c != null) {
            return false;
        }
        if (oldV == null) {
            return String.isNotBlank(venta.Variedad__c)
                || String.isNotBlank(venta.CUIT_Originante__c)
                || String.isNotBlank(venta.Campana_de_Ventas__c);
        }
        if (venta.Variedad_INASE__c == null && String.isNotBlank(venta.Variedad__c)) {
            return true;
        }
        if (venta.Campana_Agricola__c == null && String.isNotBlank(venta.Campana_de_Ventas__c)) {
            return true;
        }
        Boolean camposCambio = venta.Variedad__c != oldV.Variedad__c
            || venta.Campana_de_Ventas__c != oldV.Campana_de_Ventas__c
            || venta.CUIT_Originante__c != oldV.CUIT_Originante__c
            || venta.CUIT_Destinatario__c != oldV.CUIT_Destinatario__c
            || venta.Categoria__c != oldV.Categoria__c
            || venta.Tipo_de_Comprobante__c != oldV.Tipo_de_Comprobante__c
            || (puedeLeerTipoComprobanteExterno(venta)
                && oldV != null
                && puedeLeerTipoComprobanteExterno(oldV)
                && venta.Tipo_Comprobante_Externo__c != oldV.Tipo_Comprobante_Externo__c);
        return camposCambio
            && (venta.Variedad_INASE__c == null || venta.Campana_Agricola__c == null);
    }

    @TestVisible
    private static void limpiarCamposBasicos(Ventas_Informadas__c venta) {
        venta.CUIT_Destinatario__c = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c);
        venta.CUIT_Originante__c = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);

        String ano = lwcVentasImportFromExcel.primerAnioCampanaText(venta.Campana_de_Ventas__c);
        if (String.isNotBlank(ano)) {
            venta.Campana_de_Ventas__c = ano;
        }

        if (String.isNotBlank(venta.Categoria__c)) {
            venta.Categoria__c = lwcVentasImportFromExcel.normalizeCategoria(venta.Categoria__c);
            venta.Categoria_Portal__c = venta.Categoria__c;
        }

        if (String.isNotBlank(venta.Variedad__c)) {
            venta.Variedad__c = venta.Variedad__c.trim().toUpperCase();
        }

        if (venta.Venta_Interna__c != true) {
            venta.Venta_Interna__c = venta.CUIT_Destinatario__c == venta.CUIT_Originante__c
                && String.isNotBlank(venta.CUIT_Originante__c);
        }

        venta.Kilos_por_Bolsa__c = 1;
    }

    @TestVisible
    private static void aplicarTipoComprobante(Ventas_Informadas__c venta) {
        if (venta == null) {
            return;
        }
        if (!puedeEscribirTipoComprobanteExterno()) {
            if (venta.Tipo_de_Comprobante__c != null
                && TIPO_COMPROBANTE_MAP.containsKey(venta.Tipo_de_Comprobante__c)) {
                venta.Tipo_de_Comprobante__c = TIPO_COMPROBANTE_MAP.get(venta.Tipo_de_Comprobante__c);
            }
            return;
        }

        String externo = puedeLeerTipoComprobanteExterno(venta)
            ? venta.Tipo_Comprobante_Externo__c
            : null;
        if (String.isNotBlank(externo)) {
            String canonExt = lwcVentasImportFromExcel.canonicalTipoComprobanteExterno(externo);
            String normInt = lwcVentasImportFromExcel.normalizeTipoComprobante(externo);
            if (puedeEscribirTipoComprobanteExterno() && canonExt != null) {
                venta.Tipo_Comprobante_Externo__c = canonExt;
            }
            if (normInt != null) {
                venta.Tipo_de_Comprobante__c = normInt;
            } else if (TIPO_COMPROBANTE_MAP.containsKey(externo)) {
                venta.Tipo_de_Comprobante__c = TIPO_COMPROBANTE_MAP.get(externo);
            } else {
                venta.Tipo_de_Comprobante__c = externo;
            }
            return;
        }

        if (venta.Tipo_de_Comprobante__c == null) {
            return;
        }

        String interno = venta.Tipo_de_Comprobante__c;
        String canonExt = lwcVentasImportFromExcel.canonicalTipoComprobanteExterno(interno);
        String normInt = lwcVentasImportFromExcel.normalizeTipoComprobante(interno);
        if (TIPO_COMPROBANTE_MAP.containsKey(interno)) {
            venta.Tipo_Comprobante_Externo__c = interno == 'REMITO' ? 'Remito' : interno;
            venta.Tipo_de_Comprobante__c = TIPO_COMPROBANTE_MAP.get(interno);
        } else if (normInt != null) {
            venta.Tipo_de_Comprobante__c = normInt;
            if (puedeEscribirTipoComprobanteExterno() && canonExt != null) {
                venta.Tipo_Comprobante_Externo__c = canonExt;
            }
        } else if (puedeEscribirTipoComprobanteExterno()) {
            venta.Tipo_Comprobante_Externo__c = canonExt != null ? canonExt : interno;
        }
    }

    @TestVisible
    private static List<String> resolverVariedadYCuentas(
        Ventas_Informadas__c venta,
        Map<String, Variedad__c> variedadByName,
        Boolean strict
    ) {
        List<String> avisos = new List<String>();
        if (String.isBlank(venta.Variedad__c)) {
            return avisos;
        }

        Variedad__c variedad = variedadByName.get(lwcVentasImportFromExcel.variedadKey(venta.Variedad__c));
        if (variedad == null) {
            String msg =
                'La Variedad "' + venta.Variedad__c + '" no existe en Salesforce. Verificá el cultivar INASE.';
            if (strict == true) {
                venta.addError(msg);
            } else {
                avisos.add(registroRef(venta) + msg);
            }
            return avisos;
        }

        venta.Variedad_INASE__c = variedad.Id;
        if (variedad.Cultivo__c != null) {
            venta.Cultivo__c = variedad.Cultivo__c;
        }
        if (String.isNotBlank(variedad.Cultivar_Inase__c)) {
            venta.Variedad__c = variedad.Cultivar_Inase__c;
        }
        return avisos;
    }

    @TestVisible
    private static List<String> resolverCampanaAgricola(
        Ventas_Informadas__c venta,
        Map<String, Variedad__c> variedadByName,
        Map<String, Campana_Agricola__c> campanaByCultivoAno,
        Boolean strict
    ) {
        List<String> avisos = new List<String>();
        if (String.isBlank(venta.Campana_de_Ventas__c)) {
            String msg = 'Falta Campaña Agrícola (año).';
            if (strict == true) {
                venta.addError(msg);
            } else {
                avisos.add(registroRef(venta) + msg);
            }
            return avisos;
        }
        if (String.isBlank(venta.Variedad__c)) {
            String msg = 'Indicá la Variedad para resolver la Campaña Agrícola.';
            if (strict == true) {
                venta.addError(msg);
            } else {
                avisos.add(registroRef(venta) + msg);
            }
            return avisos;
        }

        Variedad__c variedad = variedadByName.get(lwcVentasImportFromExcel.variedadKey(venta.Variedad__c));
        if (variedad == null) {
            return avisos;
        }

        lwcVentasImportFromExcel.applyCampanaAgricola(venta, campanaByCultivoAno, variedad);
        if (venta.Campana_Agricola__c == null) {
            String msg =
                'No existe Campaña Agrícola para el cultivo de la variedad y el año '
                    + venta.Campana_de_Ventas__c;
            if (strict == true) {
                venta.addError(msg);
            } else {
                avisos.add(registroRef(venta) + msg);
            }
        }
        return avisos;
    }

    private static String registroRef(Ventas_Informadas__c venta) {
        return venta != null && venta.Id != null ? String.valueOf(venta.Id) + ': ' : '';
    }
}