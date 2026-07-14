/* Nombre: ObtenerCampana
* Autor: Rodrigo Lopez
* Proyecto: ArPOV 
* Descripción: Invocable utilizado para obtener la campaña agrícola correcta y luego asociar a TNs, HTs, etc. 
* --------------------------------------------------------------------------
* Versión      Fecha           Autor                      Descripción
* --------------------------------------------------------------------------
* 1.0.0        01/07/2025      Rodrigo Lopez         Creación.
* 1.0.1        12/08/2025      Rodrigo Lopez         Modificación para obtener meses todos los meses
* 2.0.0        18/03/2026      Rodrigo Lopez         Refactor: búsqueda directa en Campana_Agricola__c 
*                                                     por Fecha_Inicio_SE__c / Fecha_Fin_SE__c.
*                                                     Si tipo de compra != Futura, se obtiene la campaña anterior.
*--------------------------------------------------------------------------
*/
public with sharing class ObtenerCampana {

    public class CampanaRequest {
        @InvocableVariable(label='Origen' description='Origen asociado a la campaña' required=true)
        public String origenCampana;

        @InvocableVariable(label='Nombre del Cultivo' required=true)
        public String nombreCultivo;

        @InvocableVariable(label='Fecha de Creación' description='Formato: YYYY-MM-DD' required=true)
        public String fechaCreacion;

        @InvocableVariable(label='Tipo de Compra' description='Sólo si corresponde, puede ser Futura o Disponible' required=false)
        public String tipoCompra;

        @InvocableVariable(label='ID del Cultivo' description='ID del objeto Cultivo__c' required=true)
        public Id cultivoId;
    }

    public class CampanaResponse {
        @InvocableVariable(label='ID de Campaña' description='ID de la campaña encontrada')
        public String campanaId;

        @InvocableVariable(label='Éxito' description='Indica si la operación fue exitosa')
        public Boolean esExitoso;

        @InvocableVariable(label='Mensaje de Error' description='Mensaje de error si la operación falló')
        public String mensajeError;

        @InvocableVariable(label='Año de Campaña' description='Año calculado para la campaña')
        public String anoCampana;
    }

    @InvocableMethod(label='Obtener ID de Campaña' description='Obtiene el ID de una campaña agrícola basada en criterios específicos')
    public static List<CampanaResponse> obtenerIdCampanaInvocable(List<CampanaRequest> requests) {
        List<CampanaResponse> responses = new List<CampanaResponse>();

        try {
            responses = procesarRequestsEnLote(requests);
        } catch (Exception e) {
            System.debug('Error general en obtenerIdCampanaInvocable: ' + e.getMessage());
            for (CampanaRequest request : requests) {
                CampanaResponse errorResponse = new CampanaResponse();
                errorResponse.esExitoso = false;
                errorResponse.mensajeError = 'Error en el procesamiento: ' + e.getMessage();
                responses.add(errorResponse);
            }
        }

        return responses;
    }

    private static List<CampanaResponse> procesarRequestsEnLote(List<CampanaRequest> requests) {
        List<CampanaResponse> responses = new List<CampanaResponse>();

        Map<Integer, CampanaRequest> requestsValidos = new Map<Integer, CampanaRequest>();
        Set<Id> cultivoIds = new Set<Id>();

        // Inicializar responses y recopilar requests válidos
        for (Integer i = 0; i < requests.size(); i++) {
            CampanaRequest request = requests[i];
            CampanaResponse response = new CampanaResponse();
            responses.add(response);

            if (String.isBlank(request.nombreCultivo) || String.isBlank(request.fechaCreacion) || request.cultivoId == null) {
                response.esExitoso = false;
                response.mensajeError = 'Error: parámetros requeridos faltantes';
                continue;
            }

            requestsValidos.put(i, request);
            cultivoIds.add(request.cultivoId);
        }

        if (cultivoIds.isEmpty()) {
            return responses;
        }

        // Traer todas las campañas de los cultivos involucrados, ordenadas por fecha de inicio
        List<Campana_Agricola__c> todasCampanas = [
            SELECT Id, Cultivo__c, Ano__c, Fecha_Inicio_SE__c, Fecha_Fin_SE__c
            FROM Campana_Agricola__c
            WHERE Cultivo__c IN :cultivoIds
            ORDER BY Fecha_Inicio_SE__c ASC
        ];

        // Agrupar campañas por cultivo
        Map<Id, List<Campana_Agricola__c>> campanasPorCultivo = new Map<Id, List<Campana_Agricola__c>>();
        for (Campana_Agricola__c camp : todasCampanas) {
            if (!campanasPorCultivo.containsKey(camp.Cultivo__c)) {
                campanasPorCultivo.put(camp.Cultivo__c, new List<Campana_Agricola__c>());
            }
            campanasPorCultivo.get(camp.Cultivo__c).add(camp);
        }

        // Procesar cada request válido
        for (Integer indice : requestsValidos.keySet()) {
            CampanaRequest request = requestsValidos.get(indice);
            CampanaResponse response = responses[indice];

            try {
                Date fechaInput = Date.valueOf(request.fechaCreacion);
                List<Campana_Agricola__c> campanasDelCultivo = campanasPorCultivo.get(request.cultivoId);

                if (campanasDelCultivo == null || campanasDelCultivo.isEmpty()) {
                    response.esExitoso = false;
                    response.mensajeError = 'No se encontraron campañas para el cultivo especificado';
                    continue;
                }

                Boolean esFutura = String.isNotBlank(request.tipoCompra) && request.tipoCompra.equalsIgnoreCase('Futura');
                Campana_Agricola__c campanaEncontrada = null;

                if (esFutura) {
                    // Compra Futura: buscar la campaña donde la fecha cae entre Fecha_Inicio_SE__c y Fecha_Fin_SE__c
                    campanaEncontrada = buscarCampanaPorRangoFecha(campanasDelCultivo, fechaInput);
                } else {
                    // Tipo de compra distinto de Futura: buscar la campaña ANTERIOR
                    campanaEncontrada = buscarCampanaAnterior(campanasDelCultivo, fechaInput);
                }

                if (campanaEncontrada != null) {
                    response.campanaId = campanaEncontrada.Id;
                    response.esExitoso = true;
                    response.anoCampana = campanaEncontrada.Ano__c;
                } else {
                    response.esExitoso = false;
                    response.mensajeError = 'No se encontró campaña con los criterios especificados';
                }

            } catch (Exception e) {
                response.esExitoso = false;
                response.mensajeError = 'Error procesando request: ' + e.getMessage();
            }
        }

        return responses;
    }

    /**
     * Busca la campaña cuyo rango de fechas (Fecha_Inicio_SE__c – Fecha_Fin_SE__c) contiene la fecha indicada.
     */
    private static Campana_Agricola__c buscarCampanaPorRangoFecha(List<Campana_Agricola__c> campanas, Date fecha) {
        for (Campana_Agricola__c camp : campanas) {
            if (camp.Fecha_Inicio_SE__c <= fecha && camp.Fecha_Fin_SE__c >= fecha) {
                return camp;
            }
        }
        return null;
    }

    /**
     * Busca la campaña anterior a la vigente según la fecha.
     * 1. Localiza la campaña actual (por rango de fecha).
     * 2. Devuelve la inmediatamente anterior en orden cronológico.
     * 3. Si no hay campaña actual o es la primera, devuelve la última que finalizó antes de la fecha.
     */
    private static Campana_Agricola__c buscarCampanaAnterior(List<Campana_Agricola__c> campanas, Date fecha) {
        Integer indiceCampanaActual = -1;

        // Encontrar la campaña vigente
        for (Integer i = 0; i < campanas.size(); i++) {
            Campana_Agricola__c camp = campanas[i];
            if (camp.Fecha_Inicio_SE__c <= fecha && camp.Fecha_Fin_SE__c >= fecha) {
                indiceCampanaActual = i;
                break;
            }
        }

        // Si encontramos la actual y hay una anterior, la devolvemos
        if (indiceCampanaActual > 0) {
            return campanas[indiceCampanaActual - 1];
        }

        // Fallback: la última campaña que haya finalizado antes de la fecha dada
        for (Integer i = campanas.size() - 1; i >= 0; i--) {
            if (campanas[i].Fecha_Fin_SE__c < fecha) {
                return campanas[i];
            }
        }

        return null;
    }

    // ============================================================
    // LEGACY - Código anterior basado en Mapeo_de_Campanias__mdt
    // ============================================================
    /*
    private static Map<String, Mapeo_de_Campanias__mdt> cacheMapeoCampanias = new Map<String, Mapeo_de_Campanias__mdt>();
    private static Map<String, String> cacheCampanasAgricolas = new Map<String, String>();
    private static Boolean metadataCargada = false;

    private static void precargarMetadata() {
        try {
            List<Mapeo_de_Campanias__mdt> mapeos = [ SELECT Id, Origen__c, Cultivo__c, Tipo_de_compra__c, Fecha_inicio__c, Fecha_fin__c,anoCampana__c  FROM Mapeo_de_Campanias__mdt LIMIT 10000];
            
            for (Mapeo_de_Campanias__mdt mapeo : mapeos) {
                String clave = generarClaveMapeoCampania(
                    mapeo.Origen__c, 
                    mapeo.Cultivo__c, 
                    mapeo.Tipo_de_compra__c,
                    mapeo.Fecha_inicio__c,
                    mapeo.Fecha_fin__c
                );
                cacheMapeoCampanias.put(clave, mapeo);
            }
            
            metadataCargada = true;
            System.debug('Metadata precargada: ' + cacheMapeoCampanias.size() + ' registros');
            
        } catch (Exception e) {
            System.debug('Error al precargar metadata: ' + e.getMessage());
        }
    }

    private static Map<String, String> getCampanasAgricolas(Set<Id> cultivoIds, Map<String, String> aniosCampana) {
        Map<String, String> resultado = new Map<String, String>();
        
        try {
            Set<String> anosUnicos = new Set<String>(aniosCampana.values());
            anosUnicos.remove(null);
            
            if (cultivoIds.isEmpty() || anosUnicos.isEmpty()) {
                return resultado;
            }
            
            List<Campana_Agricola__c> campanasObtenidas = [  SELECT Id, Cultivo__c, Ano__c FROM Campana_Agricola__c  WHERE Cultivo__c IN :cultivoIds AND Ano__c IN :anosUnicos ];
            
            for (Campana_Agricola__c campana : campanasObtenidas) {
                String clave = campana.Cultivo__c + '_' + campana.Ano__c;
                resultado.put(clave, campana.Id);
            }
            
        } catch (Exception e) {
            System.debug('Error obteniendo campañas agrícolas en lote: ' + e.getMessage());
        }
        
        return resultado;
    }

    private static Mapeo_de_Campanias__mdt getMapeoCampana(String origenCampanaInput, String nombreCultivoInput, String fechaCreacionTn, String tipoCompraInput) {
        try {
            Date fechaInput = Date.valueOf(fechaCreacionTn);
            
            for (String clave : cacheMapeoCampanias.keySet()) {
                Mapeo_de_Campanias__mdt mapeo = cacheMapeoCampanias.get(clave);
                
                if (mapeo.Origen__c == origenCampanaInput &&
                    mapeo.Cultivo__c == nombreCultivoInput &&
                    mapeo.Tipo_de_compra__c == tipoCompraInput &&
                    mapeo.Fecha_inicio__c <= fechaInput &&
                    mapeo.Fecha_fin__c >= fechaInput) {
                    
                    return mapeo;
                }
            }
            
            return null;
            
        } catch (Exception e) {
            System.debug('Error al buscar mapeo de campaña : ' + e.getMessage());
            return null;
        }
    }

    private static String generarClaveMapeoCampania(String origen, String cultivo, String tipoCompra, Date fechaInicio, Date fechaFin) {
        return origen + '_' + cultivo + '_' + tipoCompra + '_' + fechaInicio + '_' + fechaFin;
    }
    */
}