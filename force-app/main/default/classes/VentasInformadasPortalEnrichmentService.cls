/**
 * Backfill de Ventas Informadas cargadas por API sin enriquecimiento portal
 * (Variedad_INASE__c, Campana_Agricola__c, Cultivo__c, Producto__c, CUIT lookups).
 */
public without sharing class VentasInformadasPortalEnrichmentService {

    private static final Integer CHUNK_SIZE = 10;

    public class Result {
        public Integer total { get; set; }
        public Integer actualizados { get; set; }
        public Integer omitidos { get; set; }
        public Integer errores { get; set; }
        public List<String> avisos { get; set; }

        public Result() {
            total = 0;
            actualizados = 0;
            omitidos = 0;
            errores = 0;
            avisos = new List<String>();
        }

        public void absorb(Result otro) {
            if (otro == null) {
                return;
            }
            actualizados += otro.actualizados;
            omitidos += otro.omitidos;
            errores += otro.errores;
            if (otro.avisos != null) {
                avisos.addAll(otro.avisos);
            }
        }
    }

    public static final String VENTA_SOQL_FIELDS =
        'Id, Variedad__c, Variedad_INASE__c, Cultivo__c, Cultivo_campa_a__c, ' +
        'Campana_Agricola__c, Campana_de_Ventas__c, Categoria__c, Categoria_Portal__c, ' +
        'CUIT_Originante__c, CUIT_Destinatario__c, Originante__c, Destinatario__c, ' +
        'Rol_Originante__c, Rol_Destinatario__c, Razon_Social_Destinatario__c, Producto__c, Venta_Interna__c, ' +
        'Kilos_por_Bolsa__c, Tipo_de_Comprobante__c, Venta__c';

    @TestVisible
    public static String camposEnriquecimientoSoql() {
        String campos = VENTA_SOQL_FIELDS;
        if (VentasInformadasApiNormalizer.tieneCampoTipoComprobanteExterno()) {
            campos = campos.replace(
                'Tipo_de_Comprobante__c, Venta__c',
                'Tipo_de_Comprobante__c, Tipo_Comprobante_Externo__c, Venta__c'
            );
        }
        return campos;
    }

    public static Result enriquecerYActualizar(List<Ventas_Informadas__c> ventas) {
        Result agregado = new Result();
        if (ventas == null || ventas.isEmpty()) {
            return agregado;
        }

        agregado.total = ventas.size();
        for (Integer i = 0; i < ventas.size(); i += CHUNK_SIZE) {
            List<Ventas_Informadas__c> chunk = new List<Ventas_Informadas__c>();
            for (Integer j = i; j < Math.min(i + CHUNK_SIZE, ventas.size()); j++) {
                chunk.add(ventas[j]);
            }
            agregado.absorb(procesarChunk(chunk));
        }
        return agregado;
    }

    private static Result procesarChunk(List<Ventas_Informadas__c> ventas) {
        Result result = new Result();
        result.total = ventas.size();
        if (ventas.isEmpty()) {
            return result;
        }

        List<String> avisos = VentasInformadasApiNormalizer.enriquecerComoPortal(ventas, false);
        result.avisos.addAll(avisos);
        VentasInformadasTriggerHandler.completarEnriquecimientoPortal(ventas, true);

        List<Ventas_Informadas__c> paraActualizar = new List<Ventas_Informadas__c>();
        for (Ventas_Informadas__c venta : ventas) {
            if (venta.Variedad_INASE__c == null) {
                result.errores++;
                result.avisos.add(
                    venta.Id + ': sin Variedad_INASE__c (texto "' + venta.Variedad__c + '")'
                );
                continue;
            }
            if (venta.Venta__c != null) {
                result.omitidos++;
                result.avisos.add(venta.Id + ': con Venta__c (se actualizan lookups/campos portal)');
            }
            paraActualizar.add(venta);
        }

        Integer idx = 0;
        TriggerHandler.bypass('VentasInformadasTriggerHandler');
        try {
            for (Database.SaveResult sr : Database.update(paraActualizar, false)) {
                Ventas_Informadas__c venta = paraActualizar[idx];
                idx++;
                if (sr.isSuccess()) {
                    result.actualizados++;
                } else {
                    result.errores++;
                    for (Database.Error err : sr.getErrors()) {
                        result.avisos.add(venta.Id + ': ' + err.getMessage());
                    }
                }
            }
        } finally {
            TriggerHandler.clearBypass('VentasInformadasTriggerHandler');
        }
        return result;
    }

    public static Result enriquecerVentasApi(
        Id createdById,
        Datetime desde,
        Datetime hasta,
        Integer limite
    ) {
        Integer maxRows = limite != null && limite > 0 ? limite : 200;
        String soql =
            'SELECT ' +
            camposEnriquecimientoSoql() +
            ' FROM Ventas_Informadas__c WHERE Variedad_INASE__c = NULL' +
            ' AND Variedad__c != NULL AND CreatedById = :createdById' +
            ' AND CreatedDate >= :desde AND CreatedDate <= :hasta LIMIT :maxRows';
        List<Ventas_Informadas__c> ventas = Database.query(soql);
        return enriquecerYActualizar(ventas);
    }

    public static Result enriquecerPendientesApi(Id createdById, Integer limite) {
        Integer maxRows = limite != null && limite > 0 ? limite : 40;
        String soql =
            'SELECT ' +
            camposEnriquecimientoSoql() +
            ' FROM Ventas_Informadas__c WHERE Variedad_INASE__c = NULL' +
            ' AND Variedad__c != NULL';
        if (createdById != null) {
            soql += ' AND CreatedById = :createdById';
        }
        soql += ' LIMIT :maxRows';
        List<Ventas_Informadas__c> ventas = Database.query(soql);
        return enriquecerYActualizar(ventas);
    }
}