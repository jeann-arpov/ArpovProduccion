/**
 * Valida NC / Remito de Devolución contra FC(s) de origen.
 * Cruce: CUIT Orig/Dest, Campaña, Variedad, Categoría; kilos NC ≤ saldo de FC
 * compatibles (una o varias; igualdad permitida). Estado FC: Pendiente,
 * Preprocesado o Procesado (incluye ya convertidas).
 *
 * El saldo de cada FC parte de sus kilos y resta las NC ya vinculadas
 * (FC_Origen__c), aunque hayan entrado en otra carga o transacción.
 * Incidente 3665: si la FC es anterior al ticket 1916, Cantidad_de_Bolsas__c
 * guarda bolsas (el mismo número que Cantidad_Bolsas_40__c) y el saldo
 * se expresa en kilos como bolsas * unidad del producto.
 * Dentro de la misma ejecución, las NC del lote también se descuentan entre sí.
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
     * Kilos NC ≤ saldo de FC compatibles (1 o N; igualdad permitida).
     * El saldo ya no incluye los kilos de NC vinculadas en otras cargas.
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

        List<Ventas_Informadas__c> fcsDb = consultarFcsDesdeDb(cuitsO, cuitsD, variedades);
        Map<Id, Decimal> unidadPorProducto = new Map<Id, Decimal>();
        cargarUnidades(unidadPorProducto, ncs);
        cargarUnidades(unidadPorProducto, fcsScope);
        cargarUnidades(unidadPorProducto, fcsDb);

        Map<String, List<Ventas_Informadas__c>> fcsPorClave = new Map<String, List<Ventas_Informadas__c>>();
        Map<Id, Decimal> kilosDisponibles = new Map<Id, Decimal>();

        for (Ventas_Informadas__c fc : fcsScope) {
            registrarFcCandidata(fc, fcsPorClave, kilosDisponibles, ncIds, unidadPorProducto);
        }
        for (Ventas_Informadas__c fc : fcsDb) {
            registrarFcCandidata(fc, fcsPorClave, kilosDisponibles, ncIds, unidadPorProducto);
        }

        descontarNcsYaVinculadas(fcsPorClave, kilosDisponibles, ncIds, unidadPorProducto);
        vincularNcs(ncs, fcsPorClave, kilosDisponibles, unidadPorProducto);

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
                Kilos_por_Bolsa__c,
                Producto__c,
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

        List<Ventas_Informadas__c> fcsDb = consultarFcsDesdeDb(cuitsO, cuitsD, variedades);
        Map<Id, Decimal> unidadPorProducto = new Map<Id, Decimal>();
        cargarUnidades(unidadPorProducto, ncsAVincular);
        cargarUnidades(unidadPorProducto, fcs);
        cargarUnidades(unidadPorProducto, fcsDb);

        Map<String, List<Ventas_Informadas__c>> fcsPorClave = new Map<String, List<Ventas_Informadas__c>>();
        Map<Id, Decimal> kilosDisponibles = new Map<Id, Decimal>();
        for (Ventas_Informadas__c fc : fcs) {
            registrarFcCandidata(fc, fcsPorClave, kilosDisponibles, null, unidadPorProducto);
        }
        for (Ventas_Informadas__c fc : fcsDb) {
            registrarFcCandidata(fc, fcsPorClave, kilosDisponibles, null, unidadPorProducto);
        }
        descontarNcsYaVinculadas(fcsPorClave, kilosDisponibles, excluirNcIds, unidadPorProducto);

        vincularNcs(ncsAVincular, fcsPorClave, kilosDisponibles, unidadPorProducto);

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
        Map<Id, Decimal> kilosDisponibles,
        Map<Id, Decimal> unidadPorProducto
    ) {
        cargarUnidades(unidadPorProducto, ncs);
        for (Ventas_Informadas__c nc : ncs) {
            Id fcId = encontrarFcOrigen(nc, fcsPorClave, kilosDisponibles, unidadPorProducto);
            if (fcId != null) {
                nc.FC_Origen__c = fcId;
                quitarMensajeNcSinOrigen(nc);
            } else {
                nc.FC_Origen__c = null;
                marcarNcSinOrigen(nc);
            }
        }
    }

    private static List<Ventas_Informadas__c> consultarFcsDesdeDb(
        Set<String> cuitsO,
        Set<String> cuitsD,
        Set<String> variedades
    ) {
        List<Ventas_Informadas__c> fcs = new List<Ventas_Informadas__c>();
        if (cuitsO.isEmpty() || cuitsD.isEmpty() || variedades.isEmpty()) {
            return fcs;
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
                Cantidad_Bolsas_40__c,
                Kilos_por_Bolsa__c,
                Producto__c,
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
            fcs.add(fc);
        }
        return fcs;
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
     * Resta del saldo las NC que ya tienen FC_Origen, en orden de creación.
     * No incluye las NC que esta ejecución va a evaluar de nuevo.
     * El saldo es de toda la org: una carga no puede reusar kilos ya tomados
     * por una NC que el usuario que informa no alcanza a ver.
     */
    private static void descontarNcsYaVinculadas(
        Map<String, List<Ventas_Informadas__c>> fcsPorClave,
        Map<Id, Decimal> kilosDisponibles,
        Set<Id> excluirNcIds,
        Map<Id, Decimal> unidadPorProducto
    ) {
        if (kilosDisponibles == null || kilosDisponibles.isEmpty()) {
            return;
        }
        List<Ventas_Informadas__c> previas = new SaldoNcQuery().ncsVinculadas(
            kilosDisponibles.keySet(),
            excluirNcIds
        );
        cargarUnidades(unidadPorProducto, previas);
        previas.sort(new FcCreatedDateAscComparator());
        for (Ventas_Informadas__c nc : previas) {
            reservarKilos(nc, fcsPorClave, kilosDisponibles, false, unidadPorProducto);
        }
    }

    /**
     * Reserva kilos de una o más FC compatibles hasta cubrir el NC.
     * Devuelve la FC principal (primera que aporta) o null si no alcanza la suma.
     */
    @TestVisible
    private static Id encontrarFcOrigen(
        Ventas_Informadas__c nc,
        Map<String, List<Ventas_Informadas__c>> fcsPorClave,
        Map<Id, Decimal> kilosDisponibles,
        Map<Id, Decimal> unidadPorProducto
    ) {
        return reservarKilos(nc, fcsPorClave, kilosDisponibles, true, unidadPorProducto);
    }

    /**
     * @param exigirCoberturaTotal true: solo descuenta si la suma de FC alcanza
     *        (NC nueva). false: descuenta lo que haya y, si falta, carga el
     *        resto en la FC_Origen ya guardada (NC histórica).
     */
    private static Id reservarKilos(
        Ventas_Informadas__c nc,
        Map<String, List<Ventas_Informadas__c>> fcsPorClave,
        Map<Id, Decimal> kilosDisponibles,
        Boolean exigirCoberturaTotal,
        Map<Id, Decimal> unidadPorProducto
    ) {
        Decimal kilosNc = kilosParaCruce(nc, unidadPorProducto);
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

        if (!candidatas.isEmpty()) {
            candidatas.sort(new FcCreatedDateAscComparator());
        }

        Decimal restante = kilosNc;
        Id fcPrincipal = null;
        Map<Id, Decimal> consumoTentativo = new Map<Id, Decimal>();

        for (Ventas_Informadas__c fc : candidatas) {
            Decimal disponible = kilosDisponibles.containsKey(fc.Id)
                ? kilosDisponibles.get(fc.Id)
                : kilosParaCruce(fc, unidadPorProducto);
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

        if (exigirCoberturaTotal == true && (restante > 0 || fcPrincipal == null)) {
            return null;
        }

        aplicarConsumo(kilosDisponibles, consumoTentativo);

        if (restante > 0 && nc != null && nc.FC_Origen__c != null
            && kilosDisponibles.containsKey(nc.FC_Origen__c)) {
            Decimal disponible = kilosDisponibles.get(nc.FC_Origen__c);
            if (disponible == null) {
                disponible = 0;
            }
            kilosDisponibles.put(nc.FC_Origen__c, disponible - restante);
            if (fcPrincipal == null) {
                fcPrincipal = nc.FC_Origen__c;
            }
        }
        return fcPrincipal;
    }

    private static void aplicarConsumo(
        Map<Id, Decimal> kilosDisponibles,
        Map<Id, Decimal> consumoTentativo
    ) {
        if (consumoTentativo == null || consumoTentativo.isEmpty()) {
            return;
        }
        for (Id fcId : consumoTentativo.keySet()) {
            Decimal disponible = kilosDisponibles.containsKey(fcId)
                ? kilosDisponibles.get(fcId)
                : 0;
            kilosDisponibles.put(fcId, disponible - consumoTentativo.get(fcId));
        }
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
        Set<Id> ncIds,
        Map<Id, Decimal> unidadPorProducto
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
            kilosDisponibles.put(fc.Id, kilosParaCruce(fc, unidadPorProducto));
        }
    }

    /**
     * Kilos del cruce. Si Cantidad_de_Bolsas__c y Cantidad_Bolsas_40__c son
     * iguales y no cierran con la unidad del producto, el campo de kilos
     * todavía guarda bolsas (carga anterior al ticket 1916).
     */
    @TestVisible
    private static Decimal kilosParaCruce(
        Ventas_Informadas__c venta,
        Map<Id, Decimal> unidadPorProducto
    ) {
        Decimal kilos = kilosAbs(venta);
        if (
            kilos == null
            || !campoConsultado(venta, 'Cantidad_Bolsas_40__c')
            || venta.Cantidad_Bolsas_40__c == null
            || !campoConsultado(venta, 'Producto__c')
            || venta.Producto__c == null
            || unidadPorProducto == null
            || !unidadPorProducto.containsKey(venta.Producto__c)
        ) {
            return kilos;
        }
        Decimal unidad = unidadPorProducto.get(venta.Producto__c);
        if (unidad == null || unidad <= 1) {
            return kilos;
        }
        Decimal bolsas = venta.Cantidad_Bolsas_40__c.abs();
        if (bolsas != kilos) {
            return kilos;
        }
        Decimal kilosPorBolsa = 1;
        if (
            campoConsultado(venta, 'Kilos_por_Bolsa__c')
            && venta.Kilos_por_Bolsa__c != null
            && venta.Kilos_por_Bolsa__c != 0
        ) {
            kilosPorBolsa = venta.Kilos_por_Bolsa__c;
        }
        Decimal bolsasEsperadas = BatchApexProcesaVentasInformadas.calcularBolsasDesdeKilos(
            kilos,
            kilosPorBolsa,
            unidad
        );
        if (bolsasEsperadas == bolsas) {
            return kilos;
        }
        return bolsas * unidad / kilosPorBolsa;
    }

    private static void cargarUnidades(
        Map<Id, Decimal> unidadPorProducto,
        List<Ventas_Informadas__c> ventas
    ) {
        if (unidadPorProducto == null || ventas == null || ventas.isEmpty()) {
            return;
        }
        Set<Id> faltan = new Set<Id>();
        for (Ventas_Informadas__c venta : ventas) {
            if (
                venta == null
                || !campoConsultado(venta, 'Producto__c')
                || venta.Producto__c == null
                || unidadPorProducto.containsKey(venta.Producto__c)
            ) {
                continue;
            }
            faltan.add(venta.Producto__c);
        }
        if (faltan.isEmpty()) {
            return;
        }
        for (Product2 producto : [
            SELECT Id, Unidad_de_Medida__c
            FROM Product2
            WHERE Id IN :faltan
        ]) {
            unidadPorProducto.put(producto.Id, parseUnidadMedida(producto.Unidad_de_Medida__c));
        }
        for (Id productoId : faltan) {
            if (!unidadPorProducto.containsKey(productoId)) {
                unidadPorProducto.put(productoId, null);
            }
        }
    }

    private static Boolean campoConsultado(SObject registro, String campo) {
        return registro != null && registro.isSet(campo);
    }

    private static Decimal parseUnidadMedida(String unidad) {
        if (String.isBlank(unidad)) {
            return null;
        }
        if (unidad == 'Granel') {
            return 1;
        }
        try {
            Decimal qty = Decimal.valueOf(unidad.trim());
            return qty == 0 ? null : qty;
        } catch (Exception e) {
            return null;
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

    /**
     * Lee las NC ya vinculadas sin sharing: el cupo de la FC es único
     * para toda la org, no depende de qué registros ve el usuario que carga.
     */
    private without sharing class SaldoNcQuery {
        List<Ventas_Informadas__c> ncsVinculadas(Set<Id> fcIds, Set<Id> excluir) {
            List<Ventas_Informadas__c> acumulado = new List<Ventas_Informadas__c>();
            if (fcIds == null || fcIds.isEmpty()) {
                return acumulado;
            }
            List<Id> ids = new List<Id>(fcIds);
            for (Integer i = 0; i < ids.size(); i += 400) {
                Set<Id> lote = new Set<Id>();
                Integer fin = Math.min(i + 400, ids.size());
                for (Integer j = i; j < fin; j++) {
                    lote.add(ids[j]);
                }
                acumulado.addAll(consultar(lote, excluir));
            }
            return acumulado;
        }

        List<Ventas_Informadas__c> consultar(Set<Id> fcIds, Set<Id> excluir) {
            Set<String> tipos = TIPOS_NC;
            String soql =
                'SELECT Id, CreatedDate, Tipo_de_Comprobante__c, FC_Origen__c, ' +
                'CUIT_Originante__c, CUIT_Destinatario__c, Campana_de_Ventas__c, ' +
                'Campana_Agricola__c, Variedad__c, Categoria__c, Categoria_Portal__c, ' +
                'Cantidad_de_Bolsas__c, Cantidad_Bolsas_40__c, Kilos_por_Bolsa__c, Producto__c ' +
                'FROM Ventas_Informadas__c ' +
                'WHERE FC_Origen__c IN :fcIds ' +
                'AND Tipo_de_Comprobante__c IN :tipos';
            if (excluir != null && !excluir.isEmpty()) {
                soql += ' AND Id NOT IN :excluir';
            }
            soql += ' ORDER BY CreatedDate ASC, Id ASC LIMIT 10000';
            return Database.query(soql);
        }
    }
}
