/**
 * Detección de ventas informadas duplicadas (misma clave de negocio que import Excel).
 * Clave: originante + destinatario + variedad + kilos + campaña + categoría.
 * No usa N° de comprobante ni Cultivo__c.
 */
public without sharing class VentasInformadasDuplicateUtil {

    public static final String MSG_DUPLICADO =
        'Ya existe una venta con mismo cuit/variedad/cantidad/campaña';

    @TestVisible
    public static String key(Ventas_Informadas__c venta) {
        if (venta == null
            || String.isBlank(venta.CUIT_Originante__c)
            || String.isBlank(venta.CUIT_Destinatario__c)
            || String.isBlank(venta.Variedad__c)
            || venta.Cantidad_de_Bolsas__c == null
            || String.isBlank(venta.Campana_de_Ventas__c)
            || String.isBlank(venta.Categoria__c)) {
            return null;
        }
        return venta.CUIT_Originante__c + '-'
            + venta.CUIT_Destinatario__c + '-'
            + venta.Variedad__c + '-'
            + venta.Cantidad_de_Bolsas__c.longValue() + '-'
            + venta.Campana_de_Ventas__c + '-'
            + venta.Categoria__c;
    }

    /**
     * Marca Resultado__c y Estado__c en ventas duplicadas (BD o mismo lote).
     * Ejecutar después de normalizar CUIT, campaña, categoría y variedad.
     */
    public static void marcarDuplicados(List<Ventas_Informadas__c> ventas) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }

        Set<String> cuitsOriginante = new Set<String>();
        Set<String> cuitsDestinatarios = new Set<String>();
        Set<String> variedades = new Set<String>();
        Set<Decimal> cantidades = new Set<Decimal>();
        Set<String> campaigns = new Set<String>();
        Set<String> categorias = new Set<String>();

        for (Ventas_Informadas__c venta : ventas) {
            if (key(venta) == null) {
                continue;
            }
            cuitsOriginante.add(venta.CUIT_Originante__c);
            cuitsDestinatarios.add(venta.CUIT_Destinatario__c);
            variedades.add(venta.Variedad__c);
            cantidades.add(venta.Cantidad_de_Bolsas__c);
            campaigns.add(venta.Campana_de_Ventas__c);
            categorias.add(venta.Categoria__c);
        }

        if (cuitsOriginante.isEmpty()) {
            return;
        }

        Set<String> existingKeys = new Set<String>();
        for (Ventas_Informadas__c venta : [
            SELECT CUIT_Originante__c, CUIT_Destinatario__c, Variedad__c,
                Cantidad_de_Bolsas__c, Campana_de_Ventas__c, Categoria__c
            FROM Ventas_Informadas__c
            WHERE CUIT_Originante__c IN :cuitsOriginante
                AND CUIT_Destinatario__c IN :cuitsDestinatarios
                AND Variedad__c IN :variedades
                AND Cantidad_de_Bolsas__c IN :cantidades
                AND Campana_de_Ventas__c IN :campaigns
                AND Categoria__c IN :categorias
        ]) {
            String ventaKey = key(venta);
            if (ventaKey != null) {
                existingKeys.add(ventaKey);
            }
        }

        Set<String> processedKeys = new Set<String>();
        for (Ventas_Informadas__c venta : ventas) {
            String ventaKey = key(venta);
            if (ventaKey == null) {
                continue;
            }
            if (existingKeys.contains(ventaKey) || processedKeys.contains(ventaKey)) {
                venta.Resultado__c = MSG_DUPLICADO;
                venta.Estado__c = 'Preprocesado';
            } else {
                processedKeys.add(ventaKey);
            }
        }
    }
}