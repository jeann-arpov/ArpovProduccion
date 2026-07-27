/**
 * Checkbox Tipo de regalía comercial en la Venta Informada:
 *  - marcado → Tipo_de_Material__c = Regalía Comercial + Producto Family Regalía Comercial
 *    (misma Variedad / Cultivar INASE y Categoría).
 *  - desmarcado → limpia Tipo_de_Material__c y restaura Producto Semilla Fiscalizada.
 * Se aplica en before insert/update (trigger). Reprocesar/Convertir siguen pudiendo llamar
 * aplicarDesdeCheckbox por datos legacy.
 */
public without sharing class VentasInformadasTipoMaterialUtil {

    public static final String REGALIA_COMERCIAL = 'Regalía Comercial';
    public static final String SEMILLA_FISCALIZADA = 'Semilla Fiscalizada';

    /**
     * Before-save: reacciona al checkbox (y mantiene producto RC si ya está marcado
     * y se recalculó producto SF por cambio de variedad/categoría).
     */
    public static void aplicarBeforeSave(
        List<Ventas_Informadas__c> ventas,
        Map<Id, Ventas_Informadas__c> oldMap
    ) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }

        List<Ventas_Informadas__c> aMarcar = new List<Ventas_Informadas__c>();
        List<Ventas_Informadas__c> aDesmarcar = new List<Ventas_Informadas__c>();
        Set<String> variedades = new Set<String>();
        Set<String> categorias = new Set<String>();

        for (Ventas_Informadas__c vi : ventas) {
            Ventas_Informadas__c oldV =
                oldMap != null && vi.Id != null ? oldMap.get(vi.Id) : null;
            Boolean checkNuevo = vi.Tipo_de_regalia_comercial__c == true;
            Boolean checkViejo = oldV != null && oldV.Tipo_de_regalia_comercial__c == true;

            if (checkNuevo) {
                aMarcar.add(vi);
                acumularClaves(vi, variedades, categorias);
            } else if (checkViejo || vi.Tipo_de_Material__c == REGALIA_COMERCIAL) {
                aDesmarcar.add(vi);
                acumularClaves(vi, variedades, categorias);
            }
        }

        if (aMarcar.isEmpty() && aDesmarcar.isEmpty()) {
            return;
        }

        Map<String, Product2> productosRc = buscarProductosPorFamily(
            variedades,
            categorias,
            REGALIA_COMERCIAL
        );
        Map<String, Product2> productosSf = aDesmarcar.isEmpty()
            ? new Map<String, Product2>()
            : buscarProductosPorFamily(variedades, categorias, SEMILLA_FISCALIZADA);

        for (Ventas_Informadas__c vi : aMarcar) {
            vi.Tipo_de_Material__c = REGALIA_COMERCIAL;
            Product2 prod = productosRc.get(claveProducto(vi.Variedad__c, vi.Categoria__c));
            if (prod != null) {
                vi.Producto__c = prod.Id;
                if (prod.Cultivo__c != null) {
                    vi.Cultivo__c = prod.Cultivo__c;
                }
            }
        }

        for (Ventas_Informadas__c vi : aDesmarcar) {
            vi.Tipo_de_Material__c = null;
            Product2 prod = productosSf.get(claveProducto(vi.Variedad__c, vi.Categoria__c));
            vi.Producto__c = prod != null ? prod.Id : null;
            if (prod != null && prod.Cultivo__c != null) {
                vi.Cultivo__c = prod.Cultivo__c;
            }
        }
    }

    /**
     * Para los IDs indicados que tengan Tipo_de_regalia_comercial__c = true,
     * setea Tipo de Material y el Producto Regalía Comercial correspondiente (DML).
     * Útil desde Reprocesar/Convertir o datos que no pasaron por el trigger nuevo.
     */
    public static void aplicarDesdeCheckbox(Set<Id> ventaInformadaIds) {
        if (ventaInformadaIds == null || ventaInformadaIds.isEmpty()) {
            return;
        }

        List<Ventas_Informadas__c> marcadas = [
            SELECT
                Id,
                Variedad__c,
                Categoria__c,
                Producto__c,
                Cultivo__c,
                Tipo_de_Material__c,
                Tipo_de_regalia_comercial__c
            FROM Ventas_Informadas__c
            WHERE Id IN :ventaInformadaIds
                AND Tipo_de_regalia_comercial__c = true
        ];
        if (marcadas.isEmpty()) {
            return;
        }

        aplicarBeforeSave(marcadas, null);
        update marcadas;
    }

    /**
     * Productos activos Family = Regalía Comercial, misma categoría + cultivar INASE,
     * con unidad de medida igual a la por defecto del cultivo.
     */
    public static Map<String, Product2> buscarProductosRegalia(
        Set<String> variedades,
        Set<String> categorias
    ) {
        return buscarProductosPorFamily(variedades, categorias, REGALIA_COMERCIAL);
    }

    public static Map<String, Product2> buscarProductosPorFamily(
        Set<String> variedades,
        Set<String> categorias,
        String family
    ) {
        Map<String, Product2> byKey = new Map<String, Product2>();
        if (
            variedades == null
            || variedades.isEmpty()
            || categorias == null
            || categorias.isEmpty()
            || String.isBlank(family)
        ) {
            return byKey;
        }
        for (Product2 product : [
            SELECT
                Id,
                Cultivo__c,
                Categoria__c,
                Cultivar_Inase__c,
                Unidad_de_Medida__c,
                Cultivo__r.Unidad_de_Medida_Por_Defecto__c
            FROM Product2
            WHERE Categoria__c IN :categorias
                AND Cultivar_Inase__c IN :variedades
                AND Family = :family
                AND IsActive = true
        ]) {
            if (
                product.Cultivo__r != null
                && product.Cultivo__r.Unidad_de_Medida_Por_Defecto__c == product.Unidad_de_Medida__c
            ) {
                byKey.put(claveProducto(product.Cultivar_Inase__c, product.Categoria__c), product);
            }
        }
        return byKey;
    }

    public static String claveProducto(String variedad, String categoria) {
        return (categoria == null ? '' : categoria) + (variedad == null ? '' : variedad);
    }

    public static Boolean esRegaliaComercial(Ventas_Informadas__c vi) {
        return vi != null
            && (vi.Tipo_de_regalia_comercial__c == true
                || vi.Tipo_de_Material__c == REGALIA_COMERCIAL);
    }

    private static void acumularClaves(
        Ventas_Informadas__c vi,
        Set<String> variedades,
        Set<String> categorias
    ) {
        if (String.isNotBlank(vi.Variedad__c)) {
            variedades.add(vi.Variedad__c);
        }
        if (String.isNotBlank(vi.Categoria__c)) {
            categorias.add(vi.Categoria__c);
        }
    }
}
