/**
 * Ventas_Informadas__c: cultivo de campaña, sync Variedad/Categoría portal,
 * validación cultivo campaña vs variedad y Producto__c al cambiar campaña/variedad/categoría.
 */
public without sharing class VentasInformadasTriggerHandler extends TriggerHandler {

    private static final Map<String, String> EXTERNO_A_INTERNO = new Map<String, String>{
        'FC' => 'FC',
        'NC' => 'NC',
        'Remito' => 'FC',
        'REMITO' => 'FC',
        'Remito de Devolución' => 'NC',
        'Remito de Devolucion' => 'NC'
    };

    public override void beforeInsert() {
        List<Ventas_Informadas__c> ventas = (List<Ventas_Informadas__c>) Trigger.new;
        procesarBeforeSave(ventas, null);
    }

    public override void beforeUpdate() {
        List<Ventas_Informadas__c> ventas = (List<Ventas_Informadas__c>) Trigger.new;
        Map<Id, Ventas_Informadas__c> oldMap = (Map<Id, Ventas_Informadas__c>) Trigger.oldMap;
        procesarBeforeSave(ventas, oldMap);
    }

    @TestVisible
    private static void procesarBeforeSave(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Ventas_Informadas__c> oldMap
    ) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }

        sincronizarTipoComprobante(ventas, oldMap);
        VentasInformadasApiNormalizer.normalizarBeforeSave(ventas, oldMap);
        aplicarCultivoDesdeCampana(ventas);
        sincronizarCategoria(ventas, oldMap);
        sincronizarTextoVariedadDesdeLookup(ventas);
        validarCultivoCampanaConVariedad(ventas, oldMap);
        actualizarProducto(ventas, oldMap);
        VentasInformadasExclusionUtil.marcarPendientesValidarSiCorresponde(ventas, null);
        resolverCuentasDesdeCuit(ventas);
        aplicarRolesDesdeCuentas(ventas);
    }

    /** Post-normalización portal: cultivo campaña, producto y CUIT (backfill API / scripts). */
    public static void completarEnriquecimientoPortal(List<Ventas_Informadas__c> ventas) {
        completarEnriquecimientoPortal(ventas, false);
    }

    public static void completarEnriquecimientoPortal(
        List<Ventas_Informadas__c> ventas,
        Boolean omitirCuit
    ) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }
        aplicarCultivoDesdeCampana(ventas);
        sincronizarCategoria(ventas, null);
        sincronizarTextoVariedadDesdeLookup(ventas);
        actualizarProducto(ventas, null);
        if (omitirCuit != true) {
            resolverCuentasDesdeCuit(ventas);
            aplicarRolesDesdeCuentas(ventas);
        }
    }

    /** Completa Originante / Destinatario / roles desde CUIT cuando el import no pudo resolver lookups. */
    @TestVisible
    private static void resolverCuentasDesdeCuit(List<Ventas_Informadas__c> ventas) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }

        Set<String> cultivares = new Set<String>();
        for (Ventas_Informadas__c venta : ventas) {
            if (String.isNotBlank(venta.Variedad__c)) {
                cultivares.add(venta.Variedad__c);
            }
        }
        Map<String, Id> obtentorComercializaByVariedad =
            VentasInformadasCuitResolver.mapObtentorComercializaPorVariedad(cultivares);

        List<Ventas_Informadas__c> ventasAResolver = new List<Ventas_Informadas__c>();
        for (Ventas_Informadas__c venta : ventas) {
            Id obtComId = String.isNotBlank(venta.Variedad__c)
                ? obtentorComercializaByVariedad.get(venta.Variedad__c)
                : null;

            Boolean tieneCuitOrigen = String.isNotBlank(venta.CUIT_Originante__c);
            Boolean tieneCuitDest = String.isNotBlank(venta.CUIT_Destinatario__c);
            Boolean faltaLookup = (venta.Destinatario__c == null && tieneCuitDest)
                || (venta.Originante__c == null && tieneCuitOrigen);

            if (faltaLookup || obtComId != null) {
                ventasAResolver.add(venta);
            }
        }
        if (!ventasAResolver.isEmpty()) {
            VentasInformadasCuitResolver.aplicarOriginanteYDestinatarioBulk(
                ventasAResolver,
                obtentorComercializaByVariedad
            );
        }
    }

    /**
     * Completa Rol Originante / Destinatario cuando el lookup ya está informado
     * (p. ej. flow before-save Venta_Informada_Razon_Social_Desde_CUIT setea Destinatario__c).
     */
    @TestVisible
    private static void aplicarRolesDesdeCuentas(List<Ventas_Informadas__c> ventas) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Ventas_Informadas__c venta : ventas) {
            if (venta.Originante__c != null && String.isBlank(venta.Rol_Originante__c)) {
                accountIds.add(venta.Originante__c);
            }
            if (venta.Destinatario__c != null && String.isBlank(venta.Rol_Destinatario__c)) {
                accountIds.add(venta.Destinatario__c);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, Type, RecordType.DeveloperName, Name
            FROM Account
            WHERE Id IN :accountIds
        ]);

        for (Ventas_Informadas__c venta : ventas) {
            venta.CUIT_Originante__c = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);
            venta.CUIT_Destinatario__c = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Destinatario__c);
            if (venta.Venta_Interna__c != true) {
                venta.Venta_Interna__c = venta.CUIT_Destinatario__c == venta.CUIT_Originante__c
                    && String.isNotBlank(venta.CUIT_Originante__c);
            }

            if (venta.Originante__c != null && String.isBlank(venta.Rol_Originante__c)) {
                Account originante = accountsById.get(venta.Originante__c);
                if (originante != null) {
                    VentasInformadasCuitResolver.aplicarRolOriginante(venta, originante);
                }
            }

            if (venta.Venta_Interna__c == true) {
                VentasInformadasCuitResolver.aplicarVentaInterna(venta, accountsById);
                continue;
            }

            if (venta.Destinatario__c != null && String.isBlank(venta.Rol_Destinatario__c)) {
                Account destinatario = accountsById.get(venta.Destinatario__c);
                if (destinatario != null) {
                    VentasInformadasCuitResolver.aplicarRolDestinatario(venta, destinatario);
                }
            }
        }
    }

    @TestVisible
    private static void aplicarCultivoDesdeCampana(List<Ventas_Informadas__c> ventas) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }

        Set<Id> campanaIds = new Set<Id>();
        for (Ventas_Informadas__c venta : ventas) {
            if (venta.Campana_Agricola__c != null) {
                campanaIds.add(venta.Campana_Agricola__c);
            }
        }

        Map<Id, Campana_Agricola__c> campanaPorId = new Map<Id, Campana_Agricola__c>();
        if (!campanaIds.isEmpty()) {
            for (Campana_Agricola__c campana : [
                SELECT Id, Ano__c, Cultivo__c, Cultivo__r.Name
                FROM Campana_Agricola__c
                WHERE Id IN :campanaIds
            ]) {
                campanaPorId.put(campana.Id, campana);
            }
        }

        for (Ventas_Informadas__c venta : ventas) {
            if (venta.Campana_Agricola__c == null) {
                venta.Cultivo_campa_a__c = null;
                venta.Cultivo__c = null;
                continue;
            }

            Campana_Agricola__c campana = campanaPorId.get(venta.Campana_Agricola__c);
            if (campana == null || campana.Cultivo__c == null) {
                venta.Cultivo_campa_a__c = null;
                venta.Cultivo__c = null;
                continue;
            }

            venta.Cultivo__c = campana.Cultivo__c;
            venta.Campana_de_Ventas__c = campana.Ano__c;
            if (campana.Cultivo__r != null && String.isNotBlank(campana.Cultivo__r.Name)) {
                venta.Cultivo_campa_a__c = campana.Cultivo__r.Name;
            } else {
                venta.Cultivo_campa_a__c = null;
            }
        }
    }

    /** Categoria_Portal__c (picklist UI) y Categoria__c (texto histórico/import) alineados. */
    @TestVisible
    private static void sincronizarCategoria(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Ventas_Informadas__c> oldMap
    ) {
        for (Ventas_Informadas__c venta : ventas) {
            Ventas_Informadas__c oldV =
                oldMap != null && venta.Id != null ? oldMap.get(venta.Id) : null;

            if (String.isNotBlank(venta.Categoria_Portal__c)) {
                venta.Categoria__c = venta.Categoria_Portal__c;
            } else if (
                oldV != null &&
                String.isNotBlank(oldV.Categoria_Portal__c) &&
                String.isBlank(venta.Categoria_Portal__c)
            ) {
                venta.Categoria__c = null;
            } else if (String.isNotBlank(venta.Categoria__c)) {
                venta.Categoria_Portal__c = venta.Categoria__c;
            }

            normalizarCategoriaCanonica(venta);
        }
    }

    /** Plantilla Excel: si llega Original/Fundadora/Origina en Categoria__c, guardar como Original o Fundadora. */
    @TestVisible
    private static void normalizarCategoriaCanonica(Ventas_Informadas__c venta) {
        if (venta == null) {
            return;
        }
        String raw = String.isNotBlank(venta.Categoria_Portal__c)
            ? venta.Categoria_Portal__c
            : venta.Categoria__c;
        if (String.isBlank(raw)) {
            return;
        }
        String canon = lwcVentasImportFromExcel.normalizeCategoria(raw);
        if (String.isNotBlank(canon)) {
            venta.Categoria__c = canon;
            venta.Categoria_Portal__c = canon;
        }
    }

    /** Cultivar INASE (texto) desde el lookup de Variedad cuando falta. */
    @TestVisible
    private static void sincronizarTextoVariedadDesdeLookup(List<Ventas_Informadas__c> ventas) {
        Set<Id> variedadIds = new Set<Id>();
        for (Ventas_Informadas__c venta : ventas) {
            Id lookupId = variedadLookupId(venta);
            if (lookupId != null) {
                variedadIds.add(lookupId);
            }
        }

        if (variedadIds.isEmpty()) {
            return;
        }

        Map<Id, Variedad__c> variedadPorId = new Map<Id, Variedad__c>([
            SELECT Id, Cultivar_INASE__c, Cultivo__c
            FROM Variedad__c
            WHERE Id IN :variedadIds
        ]);

        for (Ventas_Informadas__c venta : ventas) {
            Id lookupId = variedadLookupId(venta);
            if (lookupId == null) {
                continue;
            }
            Variedad__c variedad = variedadPorId.get(lookupId);
            if (variedad != null && String.isNotBlank(variedad.Cultivar_INASE__c)) {
                venta.Variedad__c = variedad.Cultivar_INASE__c;
            }
        }
    }

    /**
     * Si hay Campaña Agrícola y Variedad, el cultivo de la campaña debe coincidir con el de la variedad.
     * Se ejecuta al insertar o al cambiar campaña / variedad.
     */
    @TestVisible
    private static void validarCultivoCampanaConVariedad(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Ventas_Informadas__c> oldMap
    ) {
        Set<Id> variedadIds = new Set<Id>();
        for (Ventas_Informadas__c venta : ventas) {
            if (!debeValidarCultivo(venta, oldMap)) {
                continue;
            }
            Id lookupId = variedadLookupId(venta);
            if (lookupId != null) {
                variedadIds.add(lookupId);
            }
        }

        Map<Id, Variedad__c> variedadPorId = variedadIds.isEmpty()
            ? new Map<Id, Variedad__c>()
            : new Map<Id, Variedad__c>([
                  SELECT Id, Cultivo__c, Cultivo__r.Name, Name
                  FROM Variedad__c
                  WHERE Id IN :variedadIds
              ]);

        Set<String> cultivaresTexto = new Set<String>();
        for (Ventas_Informadas__c venta : ventas) {
            if (!debeValidarCultivo(venta, oldMap)) {
                continue;
            }
            if (variedadLookupId(venta) == null && String.isNotBlank(venta.Variedad__c)) {
                cultivaresTexto.add(venta.Variedad__c);
            }
        }

        Map<String, Variedad__c> variedadPorCultivar = new Map<String, Variedad__c>();
        if (!cultivaresTexto.isEmpty()) {
            for (Variedad__c variedad : [
                SELECT Id, Cultivo__c, Name, Cultivar_INASE__c
                FROM Variedad__c
                WHERE Cultivar_INASE__c IN :cultivaresTexto
            ]) {
                if (!variedadPorCultivar.containsKey(variedad.Cultivar_INASE__c)) {
                    variedadPorCultivar.put(variedad.Cultivar_INASE__c, variedad);
                }
            }
        }

        for (Ventas_Informadas__c venta : ventas) {
            if (!debeValidarCultivo(venta, oldMap)) {
                continue;
            }

            if (venta.Campana_Agricola__c == null || venta.Cultivo__c == null) {
                continue;
            }

            Id variedadId = variedadLookupId(venta);
            Id cultivoVariedad = null;
            String nombreVariedad = null;

            if (variedadId != null) {
                Variedad__c variedad = variedadPorId.get(variedadId);
                if (variedad == null) {
                    continue;
                }
                cultivoVariedad = variedad.Cultivo__c;
                nombreVariedad = variedad.Name;
            } else if (String.isNotBlank(venta.Variedad__c)) {
                Variedad__c variedad = variedadPorCultivar.get(venta.Variedad__c);
                if (variedad == null) {
                    continue;
                }
                cultivoVariedad = variedad.Cultivo__c;
                nombreVariedad = variedad.Name;
            } else {
                continue;
            }

            if (cultivoVariedad != null && cultivoVariedad != venta.Cultivo__c) {
                venta.addError(
                    'La Variedad' +
                        (nombreVariedad != null ? ' "' + nombreVariedad + '"' : '') +
                        ' no corresponde al cultivo de la Campaña Agrícola seleccionada. ' +
                        'Elegí una variedad del mismo cultivo o cambiá la campaña.'
                );
            }
        }
    }

    /**
     * Recalcula Producto__c cuando cambia alguno de los 3 ejes de selección:
     * Campaña Agrícola, Variedad (lookup/texto) o Categoría (Categoria_Portal__c / Categoria__c).
     * Usa Cultivar INASE + Categoría contra Product2 Semilla Fiscalizada (misma lógica que alta LWC / reproceso).
     */
    @TestVisible
    private static void actualizarProducto(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Ventas_Informadas__c> oldMap
    ) {
        List<Ventas_Informadas__c> paraProducto = new List<Ventas_Informadas__c>();
        Set<String> cultivares = new Set<String>();
        Set<String> categorias = new Set<String>();

        for (Ventas_Informadas__c venta : ventas) {
            Ventas_Informadas__c oldV =
                oldMap != null && venta.Id != null ? oldMap.get(venta.Id) : null;
            if (!debeRecalcularProducto(venta, oldV)) {
                continue;
            }
            paraProducto.add(venta);
            if (String.isNotBlank(venta.Variedad__c)) {
                cultivares.add(venta.Variedad__c);
            }
            if (String.isNotBlank(venta.Categoria__c)) {
                categorias.add(venta.Categoria__c);
            }
        }

        if (paraProducto.isEmpty()) {
            return;
        }

        Map<String, Id> productoPorClave = new Map<String, Id>();
        if (!cultivares.isEmpty() && !categorias.isEmpty()) {
            for (Product2 producto : [
                SELECT
                    Id,
                    Cultivar_Inase__c,
                    Categoria__c,
                    Unidad_de_Medida__c,
                    Cultivo__r.Unidad_de_Medida_Por_Defecto__c
                FROM Product2
                WHERE Cultivar_Inase__c IN :cultivares
                    AND Categoria__c IN :categorias
                    AND Family = 'Semilla Fiscalizada'
                    AND IsActive = true
            ]) {
                if (
                    producto.Cultivo__r != null &&
                    producto.Cultivo__r.Unidad_de_Medida_Por_Defecto__c ==
                    producto.Unidad_de_Medida__c
                ) {
                    productoPorClave.put(
                        claveProducto(producto.Cultivar_Inase__c, producto.Categoria__c),
                        producto.Id
                    );
                }
            }
        }

        for (Ventas_Informadas__c venta : paraProducto) {
            if (String.isBlank(venta.Variedad__c) || String.isBlank(venta.Categoria__c)) {
                venta.Producto__c = null;
                continue;
            }
            venta.Producto__c = productoPorClave.get(
                claveProducto(venta.Variedad__c, venta.Categoria__c)
            );
        }
    }

    @TestVisible
    private static Id variedadLookupId(Ventas_Informadas__c venta) {
        if (venta == null) {
            return null;
        }
        return venta.Variedad_INASE__c;
    }

    @TestVisible
    private static Boolean debeValidarCultivo(
        Ventas_Informadas__c venta,
        Map<Id, Ventas_Informadas__c> oldMap
    ) {
        if (venta.Campana_Agricola__c == null) {
            return false;
        }
        if (variedadLookupId(venta) != null || String.isNotBlank(venta.Variedad__c)) {
            Ventas_Informadas__c oldV =
                oldMap != null && venta.Id != null ? oldMap.get(venta.Id) : null;
            if (oldV == null) {
                return true;
            }
            return venta.Campana_Agricola__c != oldV.Campana_Agricola__c
                || venta.Variedad_INASE__c != oldV.Variedad_INASE__c
                || venta.Variedad__c != oldV.Variedad__c;
        }
        return false;
    }

    @TestVisible
    private static Boolean debeRecalcularProducto(
        Ventas_Informadas__c venta,
        Ventas_Informadas__c oldV
    ) {
        if (oldV == null) {
            return true;
        }
        return venta.Campana_Agricola__c != oldV.Campana_Agricola__c
            || venta.Variedad_INASE__c != oldV.Variedad_INASE__c
            || venta.Variedad__c != oldV.Variedad__c
            || venta.Categoria__c != oldV.Categoria__c
            || venta.Categoria_Portal__c != oldV.Categoria_Portal__c;
    }

    @TestVisible
    private static String claveProducto(String cultivarInase, String categoria) {
        return (cultivarInase == null ? '' : cultivarInase) +
            '|' +
            (categoria == null ? '' : categoria);
    }

    /**
     * Mantiene alineados Tipo_Comprobante_Externo__c (FC/NC/Remito/Remito de Devolución)
     * y Tipo_de_Comprobante__c (FC/NC interno). Se ejecuta antes del normalizador API.
     */
    @TestVisible
    private static void sincronizarTipoComprobante(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Ventas_Informadas__c> oldMap
    ) {
        if (!VentasInformadasApiNormalizer.tieneCampoTipoComprobanteExterno()) {
            return;
        }
        for (Ventas_Informadas__c venta : ventas) {
            Ventas_Informadas__c oldV =
                oldMap != null && venta.Id != null ? oldMap.get(venta.Id) : null;

            if (oldV == null) {
                if (VentasInformadasApiNormalizer.puedeEscribirTipoComprobanteExterno()) {
                    aplicarTipoComprobanteInicial(venta);
                }
                continue;
            }

            if (!VentasInformadasApiNormalizer.puedeEscribirTipoComprobanteExterno()) {
                continue;
            }

            Boolean internoCambio =
                venta.Tipo_de_Comprobante__c != oldV.Tipo_de_Comprobante__c;
            Boolean externoCambio = VentasInformadasApiNormalizer.puedeLeerTipoComprobanteExterno(venta)
                && VentasInformadasApiNormalizer.puedeLeerTipoComprobanteExterno(oldV)
                && venta.Tipo_Comprobante_Externo__c != oldV.Tipo_Comprobante_Externo__c;

            if (internoCambio && !externoCambio) {
                venta.Tipo_Comprobante_Externo__c = resolverExternoPorCambioInterno(
                    oldV.Tipo_Comprobante_Externo__c,
                    venta.Tipo_de_Comprobante__c
                );
            } else if (externoCambio && !internoCambio) {
                aplicarInternoDesdeExterno(venta);
            }
        }
    }

    @TestVisible
    private static void aplicarTipoComprobanteInicial(Ventas_Informadas__c venta) {
        if (String.isNotBlank(venta.Tipo_Comprobante_Externo__c)) {
            aplicarInternoDesdeExterno(venta);
        } else if (venta.Tipo_de_Comprobante__c == 'NC') {
            venta.Tipo_Comprobante_Externo__c = 'NC';
        } else if (venta.Tipo_de_Comprobante__c == 'FC') {
            venta.Tipo_Comprobante_Externo__c = 'FC';
        }
    }

    @TestVisible
    private static void aplicarInternoDesdeExterno(Ventas_Informadas__c venta) {
        String ext = venta.Tipo_Comprobante_Externo__c;
        if (EXTERNO_A_INTERNO.containsKey(ext)) {
            venta.Tipo_de_Comprobante__c = EXTERNO_A_INTERNO.get(ext);
        }
    }

    @TestVisible
    private static String resolverExternoPorCambioInterno(
        String oldExterno,
        String newInterno
    ) {
        String extNorm = normalizarExterno(oldExterno);

        if (newInterno == 'NC') {
            if (extNorm == 'Remito') {
                return 'Remito de Devolución';
            }
            if (extNorm == 'Remito de Devolución') {
                return 'Remito de Devolución';
            }
            return 'NC';
        }
        if (newInterno == 'FC') {
            if (extNorm == 'Remito de Devolución') {
                return 'Remito';
            }
            if (extNorm == 'Remito') {
                return 'Remito';
            }
            return 'FC';
        }
        return oldExterno;
    }

    @TestVisible
    private static String normalizarExterno(String externo) {
        if (externo == 'REMITO') {
            return 'Remito';
        }
        return externo;
    }
}