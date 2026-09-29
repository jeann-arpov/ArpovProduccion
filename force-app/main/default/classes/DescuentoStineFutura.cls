/**
 * Dto 5% (Number 16,2) para Stine Futura contado con obtentor M.S. TECHNOLOGIES.
 * No aplica si el tipo de pago es Financiado.
 * Se aplica en la línea de compra HT y en ERPvs__Descuento__c del comprobante.
 */
public without sharing class DescuentoStineFutura {

    public static final Decimal PORCENTAJE = 5.00;
    @TestVisible private static final String TIPO_COMPRA_FUTURA = 'Futura';
    @TestVisible private static final String TIPO_PAGO_CONTADO = 'Contado';
    @TestVisible private static final String CAPSULA_STINE = 'STINE';
    private static final String STINE_ID_OBTENTOR = '24';
    private static final String OBTENTOR_MS_TECHNOLOGIES = 'M.S. TECHNOLOGIES';

    public static Decimal porcentaje(Opportunity opp, OpportunityLineItem lineItem) {
        String tipoCompra = tipoCompraDeLinea(lineItem);
        String capsula = opp != null ? opp.Capsula__c : null;
        String tipoPago = tipoPagoDeLinea(lineItem);
        String idObtentor;
        String nombreObtentor;

        if (opp != null && opp.Obtentor__r != null) {
            nombreObtentor = primerNombre(
                opp.Obtentor__r.Name,
                opp.Obtentor__r.Nombre_Obtentor__c
            );
        }

        if (lineItem != null && lineItem.Product2 != null && lineItem.Product2.Variedad2__r != null
            && lineItem.Product2.Variedad2__r.Obtentor_Comercializa__r != null) {
            Account obtentor = lineItem.Product2.Variedad2__r.Obtentor_Comercializa__r;
            idObtentor = obtentor.Id_Obtentor__c;
            if (String.isBlank(nombreObtentor)) {
                nombreObtentor = primerNombre(obtentor.Name, obtentor.Nombre_Obtentor__c);
            }
        }

        return porcentaje(capsula, tipoCompra, idObtentor, nombreObtentor, tipoPago);
    }

    @TestVisible
    public static Decimal porcentaje(String capsula, String tipoCompra, String idObtentor, String nombreObtentor) {
        return porcentaje(capsula, tipoCompra, idObtentor, nombreObtentor, TIPO_PAGO_CONTADO);
    }

    @TestVisible
    public static Decimal porcentaje(
        String capsula,
        String tipoCompra,
        String idObtentor,
        String nombreObtentor,
        String tipoPago
    ) {
        if (!esContado(tipoPago) || !esTipoCompraFutura(tipoCompra) || !esCapsulaStine(capsula, idObtentor)
            || !esObtentorMsTechnologies(nombreObtentor)) {
            return null;
        }
        return PORCENTAJE.setScale(2);
    }

    public static void aplicarEnLineasCompra(List<Linea_de_Compra_HT__c> lineas) {
        if (lineas == null || lineas.isEmpty()) {
            return;
        }

        Set<Id> compraIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        Set<Id> pbeIds = new Set<Id>();
        for (Linea_de_Compra_HT__c linea : lineas) {
            if (linea.Compra_HT__c != null) {
                compraIds.add(linea.Compra_HT__c);
            }
            if (linea.Producto__c != null) {
                productIds.add(linea.Producto__c);
            }
            if (linea.Id_Producto_de_Lista_de_Precio__c != null) {
                pbeIds.add(linea.Id_Producto_de_Lista_de_Precio__c);
            }
        }

        Map<Id, Compra_HT__c> compras = compraIds.isEmpty()
            ? new Map<Id, Compra_HT__c>()
            : new Map<Id, Compra_HT__c>([
                SELECT Capsula__c,
                       Obtentor__r.Name,
                       Obtentor__r.Nombre_Obtentor__c,
                       Oportunidad__r.Capsula__c
                FROM Compra_HT__c
                WHERE Id IN :compraIds
            ]);

        Map<Id, PricebookEntry> pbes = pbeIds.isEmpty()
            ? new Map<Id, PricebookEntry>()
            : new Map<Id, PricebookEntry>([
                SELECT Product2Id,
                       Product2.Tipo_de_Compra__c,
                       Product2.Variedad2__r.Obtentor_Comercializa__r.Id_Obtentor__c,
                       Product2.Variedad2__r.Obtentor_Comercializa__r.Name,
                       Product2.Variedad2__r.Obtentor_Comercializa__r.Nombre_Obtentor__c
                FROM PricebookEntry
                WHERE Id IN :pbeIds
            ]);

        for (PricebookEntry pbe : pbes.values()) {
            if (pbe.Product2Id != null) {
                productIds.add(pbe.Product2Id);
            }
        }

        Map<Id, Product2> productos = productIds.isEmpty()
            ? new Map<Id, Product2>()
            : new Map<Id, Product2>([
                SELECT Tipo_de_Compra__c,
                       Variedad2__r.Obtentor_Comercializa__r.Id_Obtentor__c,
                       Variedad2__r.Obtentor_Comercializa__r.Name,
                       Variedad2__r.Obtentor_Comercializa__r.Nombre_Obtentor__c
                FROM Product2
                WHERE Id IN :productIds
            ]);

        for (Linea_de_Compra_HT__c linea : lineas) {
            Compra_HT__c compra = compras.get(linea.Compra_HT__c);
            Product2 producto = productoDeLinea(linea, productos, pbes);
            Account obtentorProducto = producto != null && producto.Variedad2__r != null
                ? producto.Variedad2__r.Obtentor_Comercializa__r
                : null;

            String tipoCompra = String.isNotBlank(linea.Tipo_de_Compra__c)
                ? linea.Tipo_de_Compra__c
                : (producto != null ? producto.Tipo_de_Compra__c : null);

            String capsula = primerNombre(
                linea.Capsula__c,
                compra != null ? compra.Capsula__c : null
            );
            if (String.isBlank(capsula) && compra != null && compra.Oportunidad__r != null) {
                capsula = compra.Oportunidad__r.Capsula__c;
            }

            String nombreObtentor = compra != null && compra.Obtentor__r != null
                ? primerNombre(compra.Obtentor__r.Name, compra.Obtentor__r.Nombre_Obtentor__c)
                : null;
            if (String.isBlank(nombreObtentor) && obtentorProducto != null) {
                nombreObtentor = primerNombre(obtentorProducto.Name, obtentorProducto.Nombre_Obtentor__c);
            }

            String idObtentor = obtentorProducto != null ? obtentorProducto.Id_Obtentor__c : null;
            Decimal dto = porcentaje(capsula, tipoCompra, idObtentor, nombreObtentor, linea.Tipo_de_Pago__c);
            linea.Descuento__c = dto != null ? dto : 0;
        }
    }

    private static Product2 productoDeLinea(
        Linea_de_Compra_HT__c linea,
        Map<Id, Product2> productos,
        Map<Id, PricebookEntry> pbes
    ) {
        if (linea.Producto__c != null && productos.containsKey(linea.Producto__c)) {
            return productos.get(linea.Producto__c);
        }
        PricebookEntry pbe = pbes.get(linea.Id_Producto_de_Lista_de_Precio__c);
        if (pbe == null) {
            return null;
        }
        if (pbe.Product2 != null) {
            return pbe.Product2;
        }
        return productos.get(pbe.Product2Id);
    }

    private static String tipoCompraDeLinea(OpportunityLineItem lineItem) {
        if (lineItem == null) {
            return null;
        }
        if (String.isNotBlank(lineItem.Tipo_de_Compra__c)) {
            return lineItem.Tipo_de_Compra__c;
        }
        return lineItem.Product2 != null ? lineItem.Product2.Tipo_de_Compra__c : null;
    }

    private static String tipoPagoDeLinea(OpportunityLineItem lineItem) {
        if (lineItem == null || lineItem.Linea_de_Compra_HT__r == null) {
            return null;
        }
        return lineItem.Linea_de_Compra_HT__r.Tipo_de_Pago__c;
    }

    private static Boolean esContado(String tipoPago) {
        return tipoPago == TIPO_PAGO_CONTADO;
    }

    private static Boolean esTipoCompraFutura(String tipoCompra) {
        return tipoCompra == TIPO_COMPRA_FUTURA;
    }

    private static Boolean esCapsulaStine(String capsula, String idObtentor) {
        if (capsula == CAPSULA_STINE) {
            return true;
        }
        return String.isNotBlank(idObtentor) && idObtentor.contains(STINE_ID_OBTENTOR);
    }

    private static Boolean esObtentorMsTechnologies(String nombre) {
        return String.isNotBlank(nombre) && nombre.toUpperCase().contains(OBTENTOR_MS_TECHNOLOGIES);
    }

    private static String primerNombre(String a, String b) {
        return String.isNotBlank(a) ? a : b;
    }
}
