/**
 * Valida NC / Remito de Devolución contra FC(s) de origen.
 * Cruce: CUIT Orig/Dest, Campaña, Variedad, Categoría; kilos NC ≤ suma de FC
 * compatibles (una o varias; igualdad permitida). Estado FC: Pendiente,
 * Preprocesado o Procesado (incluye ya convertidas).
 *
 * FC_Origen__c apunta a la FC principal (primera que aporta kilos).
 * También revincula NCs huérfanas cuando llega/reprocesa una FC después.
 */
public with sharing class VentasInformadasNcOrigenUtil {

    public static final String MSG_NC_SIN_ORIGEN = 'NC sin Origen';

    /** Evita recursión al actualizar NCs desde after trigger. */
    @TestVisible
    public static Boolean bypassReenlace = false;

    @TestVisible
    private static final Set<String> ESTADOS_FC_VALIDOS = new Set<String>{
        'Pendiente',
        'Preprocesado',
        'Procesado'
    };

    @TestVisible
    private static final Set<String> ESTADOS_NC_REENLACE = new Set<String>{
        'Pendiente',
        'Preprocesado'
    };

    @TestVisible
    private static final Set<String> TIPOS_NC = new Set<String>{
        'NC',
        'Remito de Devolución',
        'Remito de Devolucion'
    };

    @TestVisible
    private static final Set<String> TIPOS_FC = new Set<String>{
        'FC',
        'Remito',
        'REMITO'
    };

    public static Boolean esNc(Ventas_Informadas__c venta) {
        return venta != null && TIPOS_NC.contains(venta.Tipo_de_Comprobante__c);
    }

    public static Boolean esFc(Ventas_Informadas__c venta) {
        return venta != null && TIPOS_FC.contains(venta.Tipo_de_Comprobante__c);
    }

    public static Boolean esNcSinOrigen(Ventas_Informadas__c venta) {
        return venta != null
            && String.isNotBlank(venta.Resultado__c)
            && venta.Resultado__c.contains(MSG_NC_SIN_ORIGEN);
    }

    public static Boolean requiereFcOrigenParaConvertir(Ventas_Informadas__c venta) {
        return esNc(venta);
    }

    public static Boolean tieneFcOrigen(Ventas_Informadas__c venta) {
        return venta != null && venta.FC_Origen__c != null;
    }

    public static Decimal kilosAbs(Ventas_Informadas__c venta) {
        if (venta == null || venta.Cantidad_de_Bolsas__c == null) {
            return null;
        }
        return venta.Cantidad_de_Bolsas__c.abs();
    }

    public static String categoriaNorm(Ventas_Informadas__c venta) {
        if (venta == null) {
            return '';
        }
        String raw = String.isNotBlank(venta.Categoria__c)
            ? venta.Categoria__c
            : venta.Categoria_Portal__c;
        String norm = lwcVentasImportFromExcel.normalizeCategoria(raw);
        return blankToEmpty(norm);
    }

    public static String variedadNorm(Ventas_Informadas__c venta) {
        return venta == null ? '' : blankToEmpty(venta.Variedad__c).trim();
    }

    /**
     * Claves de match: por año de campaña y, si hay, por Campaña Agrícola Id
     * (así matchea aunque uno tenga solo lookup y el otro el año).
     */
    public static List<String> clavesMatch(Ventas_Informadas__c venta) {
        List<String> claves = new List<String>();
        if (venta == null) {
            return claves;
        }
        String cuitO = blankToEmpty(CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c));
        String cuitD = blankToEmpty(CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c));
        String variedad = variedadNorm(venta);
        String categoria = categoriaNorm(venta);
        String base =
            cuitO + '|' + cuitD + '|' + variedad + '|' + categoria + '|';

        if (String.isNotBlank(venta.Campana_de_Ventas__c)) {
            claves.add(base + venta.Campana_de_Ventas__c.trim());
        }
        if (venta.Campana_Agricola__c != null) {
            claves.add(base + String.valueOf(venta.Campana_Agricola__c));
        }
        // Sin campaña: aún así intentar match por el resto (último recurso).
        if (claves.isEmpty()) {
            claves.add(base);
        }
        return claves;
    }

    /** Compat: primera clave. */
    public static String claveMatch(Ventas_Informadas__c venta) {
        List<String> claves = clavesMatch(venta);
        return claves.isEmpty() ? null : claves[0];
    }

    public static void aplicar(List<Ventas_Informadas__c> ventas) {
        aplicar(ventas, null);
    }

    /**
     * Para cada NC del listado busca FC(s) candidatas (DB + FCs del mismo lote),
     * setea FC_Origen__c o marca Resultado = NC sin Origen.
     * Kilos NC ≤ suma de kilos de FC compatibles (1 o N; igualdad permitida).
     */
    public static void aplicar(List<Ventas_Informadas__c> ventas, Set<Id> omitirIds) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }

        List<Ventas_Informadas__c> ncs = new List<Ventas_Informadas__c>();
        List<Ventas_Informadas__c> fcsScope = new List<Ventas_Informadas__c>();
        Set<String> cuitsO = new Set<String>();
        Set<String> cuitsD = new Set<String>();
        Set<String> variedades = new Set<String>();
        Set<Id> ncIds = new Set<Id>();

        for (Ventas_Informadas__c venta : ventas) {
            if (venta == null) {
                continue;
            }
            if (omitirIds != null && venta.Id != null && omitirIds.contains(venta.Id)) {
                continue;
            }
            if (esNc(venta)) {
                ncs.add(venta);
                if (venta.Id != null) {
                    ncIds.add(venta.Id);
                }
                addIfNotBlank(cuitsO, CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c));
                addIfNotBlank(cuitsD, CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c));
                addIfNotBlank(variedades, variedadNorm(venta));
            } else if (esFc(venta)) {
                fcsScope.add(venta);
            }
        }

        if (ncs.isEmpty()) {
            return;
        }

        Map<String, List<Ventas_Informadas__c>> fcsPorClave = new Map<String, List<Ventas_Informadas__c>>();
        Map<Id, Decimal> kilosDisponibles = new Map<Id, Decimal>();

        for (Ventas_Informadas__c fc : fcsScope) {
            registrarFcCandidata(fc, fcsPorClave, kilosDisponibles, ncIds);
        }

        cargarFcsDesdeDb(cuitsO, cuitsD, variedades, fcsPorClave, kilosDisponibles, ncIds);
        vincularNcs(ncs, fcsPorClave, kilosDisponibles);

        // Con FC Origen: calcular bolsas (si hay producto) y dejar Resultado OK como en PROD.
        ConvertirVentasInformadasResumenUtil.aplicarCalculoBolsasSiCorresponde(ncs);
        for (Ventas_Informadas__c nc : ncs) {
            if (nc.FC_Origen__c == null) {
                continue;
            }
            nc.Resultado__c = ConvertirVentasInformadasResumenUtil.resolverResultadoFinal(
                nc,
                nc.Resultado__c
            );
            // Sin bolsas aún calculadas pero con FC vinculada → OK (ícono NC).
            if (String.isBlank(nc.Resultado__c)) {
                nc.Resultado__c = 'OK';
            }
        }
    }

    /**
     * Cuando se crea/reprocesa una FC después de una NC: busca NCs sin FC_Origen
     * compatibles y las vincula. Devuelve NCs a actualizar (no están en el scope).
     */
    public static List<Ventas_Informadas__c> reenlazarNcsHuerfanas(
        List<Ventas_Informadas__c> ventas,
        Set<Id> excluirNcIds
    ) {
        List<Ventas_Informadas__c> resultado = new List<Ventas_Informadas__c>();
        if (ventas == null || ventas.isEmpty() || bypassReenlace) {
            return resultado;
        }

        List<Ventas_Informadas__c> fcs = new List<Ventas_Informadas__c>();
        Set<String> cuitsO = new Set<String>();
        Set<String> cuitsD = new Set<String>();
        Set<String> variedades = new Set<String>();

        for (Ventas_Informadas__c venta : ventas) {
            if (!esFc(venta) || venta.Id == null) {
                continue;
            }
            fcs.add(venta);
            addIfNotBlank(cuitsO, CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c));
            addIfNotBlank(cuitsD, CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c));
            addIfNotBlank(variedades, variedadNorm(venta));
        }
        if (fcs.isEmpty() || variedades.isEmpty() || cuitsO.isEmpty() || cuitsD.isEmpty()) {
            return resultado;
        }

        // Primero NCs huérfanas filtradas por CUIT (evita escanear 100k+ FC si no hay nada que reenlazar).
        Set<String> cuitsOVar = variantesCuit(cuitsO);
        Set<String> cuitsDVar = variantesCuit(cuitsD);
        List<Ventas_Informadas__c> ncsAVincular = new List<Ventas_Informadas__c>();
        for (Ventas_Informadas__c nc : [
            SELECT
                Id,
                Tipo_de_Comprobante__c,
                Estado__c,
                Resultado__c,
                FC_Origen__c,
                CUIT_Originante__c,
                CUIT_Destinatario__c,
                Campana_de_Ventas__c,
                Campana_Agricola__c,
                Variedad__c,
                Categoria__c,
                Categoria_Portal__c,
                Cantidad_de_Bolsas__c,
                Cantidad_Bolsas_40__c,
                Venta__c
            FROM Ventas_Informadas__c
            WHERE Tipo_de_Comprobante__c IN :TIPOS_NC
                AND FC_Origen__c = null
                AND Venta__c = null
                AND Estado__c IN :ESTADOS_NC_REENLACE
                AND Variedad__c IN :variedades
                AND CUIT_Originante__c IN :cuitsOVar
                AND CUIT_Destinatario__c IN :cuitsDVar
            ORDER BY CreatedDate ASC
            LIMIT 2000
        ]) {
            if (excluirNcIds != null && excluirNcIds.contains(nc.Id)) {
                continue;
            }
            String cuitO = CrearVentaInformadaLWCController.limpiarCuit(nc.CUIT_Originante__c);
            String cuitD = CrearVentaInformadaLWCController.limpiarCuit(nc.CUIT_Destinatario__c);
            if (!cuitsO.contains(cuitO) || !cuitsD.contains(cuitD)) {
                continue;
            }
            ncsAVincular.add(nc);
        }

        if (ncsAVincular.isEmpty()) {
            return resultado;
        }

        Map<String, List<Ventas_Informadas__c>> fcsPorClave = new Map<String, List<Ventas_Informadas__c>>();
        Map<Id, Decimal> kilosDisponibles = new Map<Id, Decimal>();
        for (Ventas_Informadas__c fc : fcs) {
            registrarFcCandidata(fc, fcsPorClave, kilosDisponibles, null);
        }
        cargarFcsDesdeDb(cuitsO, cuitsD, variedades, fcsPorClave, kilosDisponibles, null);

        vincularNcs(ncsAVincular, fcsPorClave, kilosDisponibles);

        ConvertirVentasInformadasResumenUtil.aplicarCalculoBolsasSiCorresponde(ncsAVincular);

        for (Ventas_Informadas__c nc : ncsAVincular) {
            if (nc.FC_Origen__c != null) {
                // Tras quitar "NC sin Origen", recalcular OK / bolsas (con cálculo desde kilos si falta).
                nc.Resultado__c = ConvertirVentasInformadasResumenUtil.resolverResultadoFinal(
                    nc,
                    nc.Resultado__c
                );
                if (String.isBlank(nc.Resultado__c)) {
                    nc.Resultado__c = 'OK';
                }
                resultado.add(nc);
            }
        }
        return resultado;
    }

    private static void vincularNcs(
        List<Ventas_Informadas__c> ncs,
        Map<String, List<Ventas_Informadas__c>> fcsPorClave,
        Map<Id, Decimal> kilosDisponibles
    ) {
        for (Ventas_Informadas__c nc : ncs) {
            Id fcId = encontrarFcOrigen(nc, fcsPorClave, kilosDisponibles);
            if (fcId != null) {
                nc.FC_Origen__c = fcId;
                quitarMensajeNcSinOrigen(nc);
            } else {
                nc.FC_Origen__c = null;
                marcarNcSinOrigen(nc);
            }
        }
    }

    private static void cargarFcsDesdeDb(
        Set<String> cuitsO,
        Set<String> cuitsD,
        Set<String> variedades,
        Map<String, List<Ventas_Informadas__c>> fcsPorClave,
        Map<Id, Decimal> kilosDisponibles,
        Set<Id> ncIds
    ) {
        if (cuitsO.isEmpty() || cuitsD.isEmpty() || variedades.isEmpty()) {
            return;
        }

        // Filtrar por CUIT en SOQL: en TEST hay 350k+ FC; solo por variedad
        // (ej. CATALPA ~19k) + import de 3 filas rompe el límite de 50.001 rows.
        Set<String> cuitsOVar = variantesCuit(cuitsO);
        Set<String> cuitsDVar = variantesCuit(cuitsD);

        for (Ventas_Informadas__c fc : [
            SELECT
                Id,
                Tipo_de_Comprobante__c,
                Estado__c,
                CUIT_Originante__c,
                CUIT_Destinatario__c,
                Campana_de_Ventas__c,
                Campana_Agricola__c,
                Variedad__c,
                Categoria__c,
                Categoria_Portal__c,
                Cantidad_de_Bolsas__c,
                CreatedDate
            FROM Ventas_Informadas__c
            WHERE Tipo_de_Comprobante__c IN :TIPOS_FC
                AND Estado__c IN :ESTADOS_FC_VALIDOS
                AND Variedad__c IN :variedades
                AND CUIT_Originante__c IN :cuitsOVar
                AND CUIT_Destinatario__c IN :cuitsDVar
            ORDER BY CreatedDate ASC
            LIMIT 10000
        ]) {
            String cuitO = CrearVentaInformadaLWCController.limpiarCuit(fc.CUIT_Originante__c);
            String cuitD = CrearVentaInformadaLWCController.limpiarCuit(fc.CUIT_Destinatario__c);
            if (!cuitsO.contains(cuitO) || !cuitsD.contains(cuitD)) {
                continue;
            }
            registrarFcCandidata(fc, fcsPorClave, kilosDisponibles, ncIds);
        }
    }

    /**
     * Variantes de CUIT para SOQL (limpio + con guiones XX-XXXXXXXX-X).
     * Los sets de match en memoria siguen usando solo el CUIT limpio.
     */
    @TestVisible
    private static Set<String> variantesCuit(Set<String> cuits) {
        Set<String> out = new Set<String>();
        if (cuits == null) {
            return out;
        }
        for (String raw : cuits) {
            if (String.isBlank(raw)) {
                continue;
            }
            out.add(raw);
            String cleaned = CrearVentaInformadaLWCController.limpiarCuit(raw);
            if (String.isBlank(cleaned)) {
                continue;
            }
            out.add(cleaned);
            if (cleaned.length() == 11) {
                out.add(
                    cleaned.substring(0, 2) + '-'
                        + cleaned.substring(2, 10) + '-'
                        + cleaned.substring(10)
                );
            }
        }
        return out;
    }

    /**
     * Reserva kilos de una o más FC compatibles hasta cubrir el NC.
     * Devuelve la FC principal (primera que aporta) o null si no alcanza la suma.
     */
    @TestVisible
    private static Id encontrarFcOrigen(
        Ventas_Informadas__c nc,
        Map<String, List<Ventas_Informadas__c>> fcsPorClave,
        Map<Id, Decimal> kilosDisponibles
    ) {
        Decimal kilosNc = kilosAbs(nc);
        if (kilosNc == null) {
            return null;
        }

        List<Ventas_Informadas__c> candidatas = new List<Ventas_Informadas__c>();
        Set<Id> yaIncluidas = new Set<Id>();
        for (String clave : clavesMatch(nc)) {
            if (!fcsPorClave.containsKey(clave)) {
                continue;
            }
            for (Ventas_Informadas__c fc : fcsPorClave.get(clave)) {
                if (fc.Id == null || yaIncluidas.contains(fc.Id)) {
                    continue;
                }
                yaIncluidas.add(fc.Id);
                candidatas.add(fc);
            }
        }
        if (candidatas.isEmpty()) {
            return null;
        }

        // Orden estable: más antigua primero (FIFO de cobertura).
        candidatas.sort(new FcCreatedDateAscComparator());

        Decimal restante = kilosNc;
        Id fcPrincipal = null;
        Map<Id, Decimal> consumoTentativo = new Map<Id, Decimal>();

        for (Ventas_Informadas__c fc : candidatas) {
            Decimal disponible = kilosDisponibles.containsKey(fc.Id)
                ? kilosDisponibles.get(fc.Id)
                : kilosAbs(fc);
            if (disponible == null || disponible <= 0) {
                continue;
            }
            Decimal toma = restante < disponible ? restante : disponible;
            consumoTentativo.put(fc.Id, toma);
            if (fcPrincipal == null) {
                fcPrincipal = fc.Id;
            }
            restante -= toma;
            if (restante <= 0) {
                break;
            }
        }

        if (restante > 0 || fcPrincipal == null) {
            return null;
        }

        for (Id fcId : consumoTentativo.keySet()) {
            Decimal disponible = kilosDisponibles.containsKey(fcId)
                ? kilosDisponibles.get(fcId)
                : 0;
            kilosDisponibles.put(fcId, disponible - consumoTentativo.get(fcId));
        }
        return fcPrincipal;
    }

    private class FcCreatedDateAscComparator implements Comparator<Ventas_Informadas__c> {
        public Integer compare(Ventas_Informadas__c a, Ventas_Informadas__c b) {
            if (a == null && b == null) {
                return 0;
            }
            if (a == null) {
                return 1;
            }
            if (b == null) {
                return -1;
            }
            Datetime da = a.CreatedDate;
            Datetime db = b.CreatedDate;
            if (da == null && db == null) {
                return String.valueOf(a.Id).compareTo(String.valueOf(b.Id));
            }
            if (da == null) {
                return 1;
            }
            if (db == null) {
                return -1;
            }
            if (da == db) {
                return String.valueOf(a.Id).compareTo(String.valueOf(b.Id));
            }
            return da < db ? -1 : 1;
        }
    }

    private static void registrarFcCandidata(
        Ventas_Informadas__c fc,
        Map<String, List<Ventas_Informadas__c>> fcsPorClave,
        Map<Id, Decimal> kilosDisponibles,
        Set<Id> ncIds
    ) {
        if (fc == null || fc.Id == null || (ncIds != null && ncIds.contains(fc.Id))) {
            return;
        }
        if (String.isNotBlank(fc.Estado__c) && !ESTADOS_FC_VALIDOS.contains(fc.Estado__c)) {
            return;
        }

        for (String clave : clavesMatch(fc)) {
            if (!fcsPorClave.containsKey(clave)) {
                fcsPorClave.put(clave, new List<Ventas_Informadas__c>());
            }
            Boolean ya = false;
            for (Ventas_Informadas__c existing : fcsPorClave.get(clave)) {
                if (existing.Id == fc.Id) {
                    ya = true;
                    break;
                }
            }
            if (!ya) {
                fcsPorClave.get(clave).add(fc);
            }
        }
        if (!kilosDisponibles.containsKey(fc.Id)) {
            kilosDisponibles.put(fc.Id, kilosAbs(fc));
        }
    }

    @TestVisible
    private static void marcarNcSinOrigen(Ventas_Informadas__c nc) {
        if (nc == null) {
            return;
        }
        if (String.isBlank(nc.Resultado__c)) {
            nc.Resultado__c = MSG_NC_SIN_ORIGEN;
            return;
        }
        if (!nc.Resultado__c.contains(MSG_NC_SIN_ORIGEN)) {
            nc.Resultado__c = nc.Resultado__c + ';' + MSG_NC_SIN_ORIGEN;
        }
    }

    @TestVisible
    private static void quitarMensajeNcSinOrigen(Ventas_Informadas__c nc) {
        if (nc == null || String.isBlank(nc.Resultado__c) || !nc.Resultado__c.contains(MSG_NC_SIN_ORIGEN)) {
            return;
        }
        List<String> partes = new List<String>();
        for (String parte : nc.Resultado__c.split(';')) {
            String trimmed = parte != null ? parte.trim() : '';
            if (String.isNotBlank(trimmed) && trimmed != MSG_NC_SIN_ORIGEN) {
                partes.add(trimmed);
            }
        }
        nc.Resultado__c = partes.isEmpty() ? '' : String.join(partes, ';');
    }

    private static void addIfNotBlank(Set<String> target, String value) {
        if (String.isNotBlank(value)) {
            target.add(value);
        }
    }

    private static String blankToEmpty(String value) {
        return value == null ? '' : value;
    }
}
