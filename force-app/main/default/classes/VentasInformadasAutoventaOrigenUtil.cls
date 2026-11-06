/**
 * Incidente 3593: autoventa / siembra propia sin una compra previa que le dé origen.
 * Avisa con Resultado = "Autoventa sin Origen" (mismo lugar que "NC sin Origen").
 * El operador no edita Resultado: tilda Validar autoventa y el sistema deja OK.
 *
 * Origen: una Venta donde la cuenta es destinataria (Distribuidor o Comercio),
 * mismo producto y campaña, comprada a un tercero; o una FC informada equivalente
 * todavía no convertida (también si viene en el mismo lote).
 */
public without sharing class VentasInformadasAutoventaOrigenUtil {

    public static final String MSG_AUTOVENTA_SIN_ORIGEN = 'Autoventa sin Origen';

    private static final Set<String> TIPOS_FC = new Set<String>{ 'FC', 'Remito', 'REMITO' };

    public static Boolean esAutoventaSinOrigen(Ventas_Informadas__c venta) {
        return venta != null
            && String.isNotBlank(venta.Resultado__c)
            && venta.Resultado__c.contains(MSG_AUTOVENTA_SIN_ORIGEN);
    }

    /**
     * Alta o edición. Validar autoventa en true deja el Resultado en OK.
     * Escribir OK a mano en Resultado no alcanza: el aviso vuelve.
     */
    public static void aplicar(List<Ventas_Informadas__c> ventas, Map<Id, Ventas_Informadas__c> oldMap) {
        aplicarInterno(ventas, oldMap, null, true);
    }

    /**
     * Reproceso: un OK que ya estaba, o Validar autoventa, no se vuelve a marcar.
     * Si seguía el aviso y no la validaron, se marca de nuevo.
     */
    public static void aplicarEnReproceso(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Ventas_Informadas__c> oldMap,
        Set<Id> omitirIds
    ) {
        aplicarInterno(ventas, oldMap, omitirIds, false);
    }

    private static void aplicarInterno(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Ventas_Informadas__c> oldMap,
        Set<Id> omitirIds,
        Boolean desdePantalla
    ) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }

        List<Ventas_Informadas__c> candidatas = new List<Ventas_Informadas__c>();
        for (Ventas_Informadas__c venta : ventas) {
            if (venta == null || omitida(venta, omitirIds)) {
                continue;
            }
            Ventas_Informadas__c oldV = oldDe(venta, oldMap);
            if (!esAutoventaEvaluable(venta)) {
                if (esAutoventaSinOrigen(venta)) {
                    quitarMensaje(venta, true);
                }
                continue;
            }
            if (operadorYaValido(venta, oldV, desdePantalla)) {
                quitarMensaje(venta, true);
                if (String.isBlank(venta.Resultado__c)) {
                    venta.Resultado__c = 'OK';
                }
                continue;
            }
            if (!sePuedeEvaluar(venta)) {
                continue;
            }
            candidatas.add(venta);
        }

        if (candidatas.isEmpty()) {
            return;
        }

        Set<String> origenes = indexarOrigenes(ventas, candidatas);
        for (Ventas_Informadas__c venta : candidatas) {
            if (tieneOrigen(venta, origenes)) {
                quitarMensaje(venta, true);
            } else {
                marcar(venta);
            }
        }
    }

    @TestVisible
    private static Boolean esAutoventaEvaluable(Ventas_Informadas__c venta) {
        if (venta == null || venta.Venta__c != null || VentasInformadasNcOrigenUtil.esNc(venta)) {
            return false;
        }
        if (VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(venta)) {
            return false;
        }
        if (venta.Venta_Interna__c == true) {
            return true;
        }
        String cuitO = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);
        String cuitD = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c);
        return String.isNotBlank(cuitO) && cuitO == cuitD;
    }

    private static Boolean sePuedeEvaluar(Ventas_Informadas__c venta) {
        if (venta.Originante__c != null && venta.Producto__c != null && venta.Campana_Agricola__c != null) {
            return true;
        }
        return !clavesVariedad(CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c), venta).isEmpty();
    }

    private static Boolean operadorYaValido(
        Ventas_Informadas__c venta,
        Ventas_Informadas__c oldV,
        Boolean desdePantalla
    ) {
        if (clavesCambiaron(venta, oldV)) {
            if (venta.Validar_Autoventa__c == true) {
                venta.Validar_Autoventa__c = false;
            }
            return false;
        }
        if (venta.Validar_Autoventa__c == true) {
            return true;
        }
        if (oldV == null) {
            return false;
        }
        // Un OK previo (ya procesada) se conserva. Pasar el aviso a OK a mano no valida.
        return esOk(oldV.Resultado__c) && (esOk(venta.Resultado__c) || !desdePantalla);
    }

    /**
     * Completar un dato que estaba vacío (el batch resuelve producto o cuenta)
     * no invalida un OK. Sí lo invalida cambiar variedad, categoría, CUIT o producto.
     */
    private static Boolean clavesCambiaron(Ventas_Informadas__c venta, Ventas_Informadas__c oldV) {
        if (oldV == null) {
            return false;
        }
        return cambioRealId(venta.Originante__c, oldV.Originante__c)
            || cambioRealId(venta.Producto__c, oldV.Producto__c)
            || cambioRealId(venta.Campana_Agricola__c, oldV.Campana_Agricola__c)
            || cambioReal(
                CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c),
                CrearVentaInformadaLWCController.limpiarCuit(oldV.CUIT_Originante__c)
            )
            || cambioReal(
                CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c),
                CrearVentaInformadaLWCController.limpiarCuit(oldV.CUIT_Destinatario__c)
            )
            || cambioReal(
                VentasInformadasNcOrigenUtil.variedadNorm(venta),
                VentasInformadasNcOrigenUtil.variedadNorm(oldV)
            )
            || cambioReal(
                VentasInformadasNcOrigenUtil.categoriaNorm(venta),
                VentasInformadasNcOrigenUtil.categoriaNorm(oldV)
            );
    }

    private static Boolean cambioRealId(Id nuevo, Id viejo) {
        return viejo != null && nuevo != viejo;
    }

    private static Boolean cambioReal(String nuevo, String viejo) {
        String actual = nuevo == null ? '' : nuevo;
        String anterior = viejo == null ? '' : viejo;
        return String.isNotBlank(anterior) && actual != anterior;
    }

    private static Set<String> indexarOrigenes(
        List<Ventas_Informadas__c> ventas,
        List<Ventas_Informadas__c> candidatas
    ) {
        Set<String> claves = new Set<String>();
        Set<Id> excluir = new Set<Id>();
        Set<Id> cuentas = new Set<Id>();
        Set<Id> productos = new Set<Id>();
        Set<Id> campanas = new Set<Id>();
        Set<String> cuits = new Set<String>();
        Set<String> variedades = new Set<String>();

        for (Ventas_Informadas__c venta : ventas) {
            if (venta == null) {
                continue;
            }
            if (venta.Id != null && esAutoventaEvaluable(venta)) {
                excluir.add(venta.Id);
            }
            indexarCompraInformada(venta, claves);
        }

        for (Ventas_Informadas__c venta : candidatas) {
            if (venta.Originante__c != null) {
                cuentas.add(venta.Originante__c);
            }
            if (venta.Producto__c != null) {
                productos.add(venta.Producto__c);
            }
            if (venta.Campana_Agricola__c != null) {
                campanas.add(venta.Campana_Agricola__c);
            }
            String cuit = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);
            if (String.isNotBlank(cuit)) {
                cuits.add(cuit);
            }
            if (String.isNotBlank(venta.CUIT_Originante__c)) {
                cuits.add(venta.CUIT_Originante__c.trim());
            }
            String variedad = VentasInformadasNcOrigenUtil.variedadNorm(venta);
            if (String.isNotBlank(variedad)) {
                variedades.add(variedad);
            }
        }

        if (!cuentas.isEmpty() && !productos.isEmpty() && !campanas.isEmpty()) {
            for (Venta__c compra : [
                SELECT Destinatario__c, Originante__c, Producto__c, Campana_Agricola__c
                FROM Venta__c
                WHERE Destinatario__c IN :cuentas
                    AND Producto__c IN :productos
                    AND Campana_Agricola__c IN :campanas
                    AND Originante__c != NULL
                    AND (
                        Destinatario__r.RecordType.DeveloperName = 'Distribuidor'
                        OR Destinatario__r.RecordType.DeveloperName = 'Comercio'
                    )
                LIMIT 10000
            ]) {
                if (compra.Originante__c == compra.Destinatario__c) {
                    continue;
                }
                claves.add(claveProducto(compra.Destinatario__c, compra.Producto__c, compra.Campana_Agricola__c));
            }
        }

        if (!cuits.isEmpty() && !variedades.isEmpty()) {
            Set<String> tiposFc = TIPOS_FC;
            String soql =
                'SELECT Id, CUIT_Originante__c, CUIT_Destinatario__c, Destinatario__c, ' +
                'Variedad__c, Categoria__c, Categoria_Portal__c, Campana_de_Ventas__c, ' +
                'Campana_Agricola__c, Producto__c, Tipo_de_Comprobante__c ' +
                'FROM Ventas_Informadas__c ' +
                'WHERE Tipo_de_Comprobante__c IN :tiposFc ' +
                'AND Variedad__c IN :variedades ' +
                'AND (CUIT_Destinatario__c IN :cuits)';
            if (!excluir.isEmpty()) {
                soql += ' AND Id NOT IN :excluir';
            }
            soql += ' LIMIT 10000';
            for (Ventas_Informadas__c compra : Database.query(soql)) {
                indexarCompraInformada(compra, claves);
            }
        }

        return claves;
    }

    private static void indexarCompraInformada(Ventas_Informadas__c compra, Set<String> claves) {
        if (compra == null || !TIPOS_FC.contains(compra.Tipo_de_Comprobante__c)) {
            return;
        }
        String buyer = CrearVentaInformadaLWCController.limpiarCuit(compra.CUIT_Destinatario__c);
        String seller = CrearVentaInformadaLWCController.limpiarCuit(compra.CUIT_Originante__c);
        if (String.isBlank(buyer) || buyer == seller) {
            return;
        }
        claves.addAll(clavesVariedad(buyer, compra));
        if (compra.Destinatario__c != null && compra.Producto__c != null && compra.Campana_Agricola__c != null) {
            claves.add(claveProducto(compra.Destinatario__c, compra.Producto__c, compra.Campana_Agricola__c));
        }
    }

    private static Boolean tieneOrigen(Ventas_Informadas__c venta, Set<String> claves) {
        String buyer = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);
        for (String clave : clavesVariedad(buyer, venta)) {
            if (claves.contains(clave)) {
                return true;
            }
        }
        if (venta.Originante__c != null && venta.Producto__c != null && venta.Campana_Agricola__c != null) {
            return claves.contains(claveProducto(venta.Originante__c, venta.Producto__c, venta.Campana_Agricola__c));
        }
        return false;
    }

    private static List<String> clavesVariedad(String cuitComprador, Ventas_Informadas__c venta) {
        List<String> claves = new List<String>();
        if (String.isBlank(cuitComprador) || venta == null) {
            return claves;
        }
        String variedad = VentasInformadasNcOrigenUtil.variedadNorm(venta);
        String categoria = VentasInformadasNcOrigenUtil.categoriaNorm(venta);
        if (String.isBlank(variedad) || String.isBlank(categoria)) {
            return claves;
        }
        String base = cuitComprador + '|' + variedad + '|' + categoria + '|';
        if (String.isNotBlank(venta.Campana_de_Ventas__c)) {
            claves.add(base + venta.Campana_de_Ventas__c.trim());
        }
        if (venta.Campana_Agricola__c != null) {
            claves.add(base + String.valueOf(venta.Campana_Agricola__c));
        }
        return claves;
    }

    private static String claveProducto(Id cuenta, Id producto, Id campana) {
        return String.valueOf(cuenta) + '|' + String.valueOf(producto) + '|' + String.valueOf(campana);
    }

    private static void marcar(Ventas_Informadas__c venta) {
        if (String.isBlank(venta.Resultado__c) || esOk(venta.Resultado__c)) {
            venta.Resultado__c = MSG_AUTOVENTA_SIN_ORIGEN;
            return;
        }
        if (!venta.Resultado__c.contains(MSG_AUTOVENTA_SIN_ORIGEN)) {
            venta.Resultado__c = venta.Resultado__c + ';' + MSG_AUTOVENTA_SIN_ORIGEN;
        }
    }

    private static void quitarMensaje(Ventas_Informadas__c venta, Boolean completarOkSiQuedaVacio) {
        if (!esAutoventaSinOrigen(venta)) {
            return;
        }
        List<String> partes = new List<String>();
        for (String parte : venta.Resultado__c.split(';')) {
            String trimmed = parte != null ? parte.trim() : '';
            if (String.isNotBlank(trimmed) && trimmed != MSG_AUTOVENTA_SIN_ORIGEN) {
                partes.add(trimmed);
            }
        }
        venta.Resultado__c = partes.isEmpty() ? '' : String.join(partes, ';');
        if (completarOkSiQuedaVacio && String.isBlank(venta.Resultado__c)) {
            venta.Resultado__c = 'OK';
        }
    }

    private static Boolean esOk(String resultado) {
        return resultado != null && resultado.trim() == 'OK';
    }

    private static Boolean omitida(Ventas_Informadas__c venta, Set<Id> omitirIds) {
        return omitirIds != null && venta.Id != null && omitirIds.contains(venta.Id);
    }

    private static Ventas_Informadas__c oldDe(Ventas_Informadas__c venta, Map<Id, Ventas_Informadas__c> oldMap) {
        if (oldMap == null || venta.Id == null) {
            return null;
        }
        return oldMap.get(venta.Id);
    }
}
