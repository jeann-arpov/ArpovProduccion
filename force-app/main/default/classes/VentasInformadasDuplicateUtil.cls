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
        marcarDuplicadoCruzadoNeogen(ventas, existingKeys);
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

    /**
     * SE-332. La misma venta NEOGEN de soja no se acredita dos veces si la informan
     * A.C.A y GDM (Id Obtentor 85): mismo destinatario, variedad, cantidad, campaña y categoría.
     */
    public static void marcarDuplicadoCruzadoNeogen(List<Ventas_Informadas__c> ventas) {
        marcarDuplicadoCruzadoNeogen(ventas, null);
    }

    private static void marcarDuplicadoCruzadoNeogen(
        List<Ventas_Informadas__c> ventas,
        Set<String> existingKeys
    ) {
        if (ventas == null || ventas.isEmpty()) {
            return;
        }
        Set<String> variedades = new Set<String>();
        for (Ventas_Informadas__c venta : ventas) {
            if (venta != null && String.isNotBlank(venta.Variedad__c)) {
                variedades.add(venta.Variedad__c);
            }
        }
        if (variedades.isEmpty()) {
            return;
        }

        Map<String, String> cuitGdmPorVariedad = new Map<String, String>();
        for (Variedad__c variedad : [
            SELECT Cultivar_INASE__c, Cultivo__r.Name, Obtentor_Comercializa__r.N_CUIT__c
            FROM Variedad__c
            WHERE Cultivar_INASE__c IN :variedades
                AND Obtentor_Comercializa__r.Id_Obtentor__c = :VentaNeogenAca.ID_OBTENTOR_NEOGEN
        ]) {
            if (variedad.Cultivo__r != null
                && String.isNotBlank(variedad.Cultivo__r.Name)
                && !variedad.Cultivo__r.Name.equalsIgnoreCase(VentaNeogenAca.CULTIVO_SOJA)) {
                continue;
            }
            String cuitGdm = CrearVentaInformadaLWCController.limpiarCuit(
                variedad.Obtentor_Comercializa__r.N_CUIT__c
            );
            if (String.isNotBlank(variedad.Cultivar_INASE__c) && String.isNotBlank(cuitGdm)) {
                cuitGdmPorVariedad.put(variedad.Cultivar_INASE__c, cuitGdm);
            }
        }
        if (cuitGdmPorVariedad.isEmpty()) {
            return;
        }

        Set<String> cuitsBuscar = new Set<String>{ VentaNeogenAca.CUIT_ACA };
        cuitsBuscar.addAll(cuitGdmPorVariedad.values());
        Set<String> cuitsDestino = new Set<String>();
        Set<Decimal> cantidades = new Set<Decimal>();
        Set<String> campanas = new Set<String>();
        Set<String> categorias = new Set<String>();
        for (Ventas_Informadas__c venta : ventas) {
            if (!cuitGdmPorVariedad.containsKey(venta.Variedad__c)) {
                continue;
            }
            if (String.isNotBlank(venta.CUIT_Destinatario__c)) {
                cuitsDestino.add(venta.CUIT_Destinatario__c);
            }
            if (venta.Cantidad_de_Bolsas__c != null) {
                cantidades.add(venta.Cantidad_de_Bolsas__c);
            }
            if (String.isNotBlank(venta.Campana_de_Ventas__c)) {
                campanas.add(venta.Campana_de_Ventas__c);
            }
            if (String.isNotBlank(venta.Categoria__c)) {
                categorias.add(venta.Categoria__c);
            }
        }
        if (cuitsDestino.isEmpty() || cantidades.isEmpty() || campanas.isEmpty() || categorias.isEmpty()) {
            return;
        }

        Set<String> ocupadas = new Set<String>();
        if (existingKeys != null) {
            ocupadas.addAll(existingKeys);
        }
        for (Ventas_Informadas__c venta : [
            SELECT CUIT_Originante__c, CUIT_Destinatario__c, Variedad__c,
                Cantidad_de_Bolsas__c, Campana_de_Ventas__c, Categoria__c
            FROM Ventas_Informadas__c
            WHERE CUIT_Originante__c IN :cuitsBuscar
                AND CUIT_Destinatario__c IN :cuitsDestino
                AND Variedad__c IN :cuitGdmPorVariedad.keySet()
                AND Cantidad_de_Bolsas__c IN :cantidades
                AND Campana_de_Ventas__c IN :campanas
                AND Categoria__c IN :categorias
        ]) {
            String clave = claveCruzada(venta);
            if (clave != null) {
                ocupadas.add(clave);
            }
        }

        for (Ventas_Informadas__c venta : ventas) {
            if (venta.Resultado__c == MSG_DUPLICADO || !cuitGdmPorVariedad.containsKey(venta.Variedad__c)) {
                continue;
            }
            String cuit = CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c);
            String cuitGdm = cuitGdmPorVariedad.get(venta.Variedad__c);
            String contraparte = cuit == VentaNeogenAca.CUIT_ACA
                ? cuitGdm
                : (cuit == cuitGdm ? VentaNeogenAca.CUIT_ACA : null);
            if (contraparte == null) {
                continue;
            }
            String propia = claveCruzada(venta);
            String ajena = claveCruzada(venta, contraparte);
            if (propia != null && ocupadas.contains(ajena)) {
                venta.Resultado__c = MSG_DUPLICADO;
                venta.Estado__c = 'Preprocesado';
            } else if (propia != null) {
                ocupadas.add(propia);
            }
        }
    }

    private static String claveCruzada(Ventas_Informadas__c venta) {
        return claveCruzada(
            venta,
            CrearVentaInformadaLWCController.limpiarCuit(venta.CUIT_Originante__c)
        );
    }

    private static String claveCruzada(Ventas_Informadas__c venta, String cuitOriginante) {
        if (venta == null
            || String.isBlank(cuitOriginante)
            || String.isBlank(venta.CUIT_Destinatario__c)
            || String.isBlank(venta.Variedad__c)
            || venta.Cantidad_de_Bolsas__c == null
            || String.isBlank(venta.Campana_de_Ventas__c)
            || String.isBlank(venta.Categoria__c)) {
            return null;
        }
        return cuitOriginante + '-'
            + venta.CUIT_Destinatario__c + '-'
            + venta.Variedad__c + '-'
            + venta.Cantidad_de_Bolsas__c.longValue() + '-'
            + venta.Campana_de_Ventas__c + '-'
            + venta.Categoria__c;
    }
}