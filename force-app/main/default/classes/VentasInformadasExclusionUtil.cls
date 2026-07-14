/**
 * Autoventas / siembras propias (mismo CUIT originante y destinatario) con categoría
 * Original o Fundadora o Pre Básica: quedan pendientes de validar y no se convierten.
 */
public with sharing class VentasInformadasExclusionUtil {

    @TestVisible
    private static final Set<String> CATEGORIAS_NO_CONVERTIBLES = new Set<String>{
        'Pre Básica',
        'Original o Fundadora'
    };

    public static final String ESTADO_PENDIENTE = 'Pendiente';

    /** @deprecated El estado de estas autoventas es {@link #ESTADO_PENDIENTE}; se conserva para registros legacy. */
    public static final String ESTADO_PENDIENTE_VALIDAR = 'Pendiente de Validar';

    public static final String MSG_PENDIENTE_VALIDAR =
        'Autoventa/siembra propia con categoría Original o Pre Básica: pendiente de validar con comercio. No se convierte a Venta.';

    /** @deprecated Usar ESTADO_PENDIENTE */
    public static final String ESTADO_EXCLUIDA = ESTADO_PENDIENTE;

    /** @deprecated Usar MSG_PENDIENTE_VALIDAR */
    public static final String MSG_EXCLUSION = MSG_PENDIENTE_VALIDAR;

    @TestVisible
    public static Boolean esAutoventaCategoriaNoConvertible(Ventas_Informadas__c venta) {
        if (venta == null || venta.Venta__c != null) {
            return false;
        }

        String cuitOrig = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);
        String cuitDest = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c);
        if (String.isBlank(cuitOrig) || String.isBlank(cuitDest) || cuitOrig != cuitDest) {
            return false;
        }

        String categoriaRaw = String.isNotBlank(venta.Categoria__c)
            ? venta.Categoria__c
            : venta.Categoria_Portal__c;
        String categoria = lwcVentasImportFromExcel.normalizeCategoria(categoriaRaw);
        return CATEGORIAS_NO_CONVERTIBLES.contains(categoria);
    }

    /** @deprecated Usar esAutoventaCategoriaNoConvertible */
    public static Boolean esAutoventaExcluible(Ventas_Informadas__c venta) {
        return esAutoventaCategoriaNoConvertible(venta);
    }

    public static Boolean esPendienteValidarAutoventa(Ventas_Informadas__c venta) {
        return venta != null && venta.Resultado__c == MSG_PENDIENTE_VALIDAR;
    }

    public static void marcarPendientesValidarSiCorresponde(List<Ventas_Informadas__c> ventas) {
        marcarPendientesValidarSiCorresponde(ventas, null);
    }

    public static void marcarPendientesValidarSiCorresponde(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Account> accountsById
    ) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }
        for (Ventas_Informadas__c venta : ventas) {
            marcarPendienteValidarSiCorresponde(venta, accountsById);
        }
    }

    public static void marcarPendienteValidarSiCorresponde(Ventas_Informadas__c venta) {
        marcarPendienteValidarSiCorresponde(venta, null);
    }

    public static void marcarPendienteValidarSiCorresponde(
        Ventas_Informadas__c venta,
        Map<Id, Account> accountsById
    ) {
        if (!esAutoventaCategoriaNoConvertible(venta)) {
            return;
        }
        if (venta.Estado__c == 'Procesado') {
            return;
        }

        venta.Venta_Interna__c = true;
        venta.Estado__c = ESTADO_PENDIENTE;
        venta.Resultado__c = MSG_PENDIENTE_VALIDAR;
        if (String.isNotBlank(venta.Categoria__c)) {
            venta.Categoria_Portal__c = venta.Categoria__c;
        } else if (String.isNotBlank(venta.Categoria_Portal__c)) {
            venta.Categoria__c = venta.Categoria_Portal__c;
        }
        VentasInformadasCuitResolver.aplicarVentaInterna(venta, accountsById);
    }

    /** @deprecated Usar marcarPendienteValidarSiCorresponde */
    public static void marcarExcluidaSiCorresponde(Ventas_Informadas__c venta) {
        marcarPendienteValidarSiCorresponde(venta);
    }

    /** @deprecated Usar marcarPendientesValidarSiCorresponde */
    public static void marcarExcluidasSiCorresponde(List<Ventas_Informadas__c> ventas) {
        marcarPendientesValidarSiCorresponde(ventas);
    }
}