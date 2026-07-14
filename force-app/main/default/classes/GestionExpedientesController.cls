public with sharing class GestionExpedientesController {

    /**
     * Obtiene gestiones paginadas para un expediente
     * @param expedienteId - Id del expediente padre
     * @param limitSize - Cantidad de registros a traer
     * @param offset - Desde qué registro empezar
     * @return Wrapper con gestiones y total
     */
    @AuraEnabled(cacheable=true)
    public static GestionesResult obtenerGestiones(Id expedienteId, Integer limitSize, Integer offset) {
        GestionesResult result = new GestionesResult();
        
        result.total = [
            SELECT COUNT() 
            FROM Gestion_Expedientes__c 
            WHERE Expediente_de_Negativos__c = :expedienteId
        ];
        
        result.gestiones = [
            SELECT Id, Name, Celular__c, Medio__c, Tipo_Gestion__c, Operador__c,
                   Respuesta__c, Comentario__c, CreatedDate, CreatedById,
                   CreatedBy.Name
            FROM Gestion_Expedientes__c
            WHERE Expediente_de_Negativos__c = :expedienteId
            ORDER BY CreatedDate DESC
            LIMIT :limitSize
            OFFSET :offset
        ];
        
        return result;
    }

    /**
     * Obtiene el siguiente número de gestión para mostrar al usuario
     * @param expedienteId - Id del expediente padre
     * @return String con el siguiente número
     */
    @AuraEnabled
    public static String obtenerSiguienteNumero(Id expedienteId) {
        List<Gestion_Expedientes__c> ultima = [
            SELECT Name 
            FROM Gestion_Expedientes__c 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        if (ultima.isEmpty()) {
            return 'GE-00001';
        }
        
        // Extraer número del auto-number y sumar 1
        String ultimoName = ultima[0].Name;
        String numStr = ultimoName.replaceAll('[^0-9]', '');
        Integer siguiente = Integer.valueOf(numStr) + 1;
        return 'GE-' + String.valueOf(siguiente).leftPad(5, '0');
    }

    /**
     * Crea una nueva gestión
     * @param expedienteId - Id del expediente padre
     * @param celular - Teléfono
     * @param medio - Medio de contacto
     * @param tipoGestion - Saliente/Entrante
     * @param respuesta - Resultado del contacto
     * @param comentario - Comentarios adicionales
     * @return La gestión creada
     */
    @AuraEnabled
    public static Gestion_Expedientes__c crearGestion(
        Id expedienteId, 
        String celular, 
        String medio, 
        String tipoGestion, 
        String operador,
        String respuesta, 
        String comentario
    ) {
        Gestion_Expedientes__c gestion = new Gestion_Expedientes__c(
            Expediente_de_Negativos__c = expedienteId,
            Celular__c = celular,
            Medio__c = medio,
            Tipo_Gestion__c = tipoGestion,
            Operador__c = operador,
            Respuesta__c = respuesta,
            Comentario__c = comentario
        );
        
        insert gestion;
        
        // Re-query para traer Name (auto-number) y CreatedDate
        return [
            SELECT Id, Name, Celular__c, Medio__c, Tipo_Gestion__c, Operador__c,
                   Respuesta__c, Comentario__c, CreatedDate, CreatedBy.Name
            FROM Gestion_Expedientes__c
            WHERE Id = :gestion.Id
            LIMIT 1
        ];
    }

    /**
     * Elimina una gestión
     * @param gestionId - Id de la gestión a eliminar
     */
    @AuraEnabled
    public static void eliminarGestion(Id gestionId) {
        Gestion_Expedientes__c gestion = [
            SELECT Id FROM Gestion_Expedientes__c WHERE Id = :gestionId LIMIT 1
        ];
        delete gestion;
    }

    /**
     * Wrapper class para retornar gestiones con total
     */
    public class GestionesResult {
        @AuraEnabled public List<Gestion_Expedientes__c> gestiones { get; set; }
        @AuraEnabled public Integer total { get; set; }
        
        public GestionesResult() {
            this.gestiones = new List<Gestion_Expedientes__c>();
            this.total = 0;
        }
    }
}