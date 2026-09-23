public with sharing class GestionExpedientesController {

    private static final String CASE_PREFIX = Case.SObjectType.getDescribe().getKeyPrefix();
    private static final String EXPEDIENTE_PREFIX = Expediente_de_Negativos__c.SObjectType.getDescribe().getKeyPrefix();
    /** Operador interno para gestiones de Caso: habilita todas las Respuestas en el picklist dependiente. */
    @TestVisible
    private static final String OPERADOR_CASO = 'Caso';

    /**
     * Obtiene gestiones paginadas para un expediente o caso
     */
    @AuraEnabled(cacheable=true)
    public static GestionesResult obtenerGestiones(Id parentId, Integer limitSize, Integer offset) {
        GestionesResult result = new GestionesResult();
        String parentField = resolveParentField(parentId);

        String countQuery =
            'SELECT COUNT() FROM Gestion_Expedientes__c WHERE ' + parentField + ' = :parentId';
        result.total = Database.countQuery(countQuery);

        String dataQuery =
            'SELECT Id, Name, Celular__c, Medio__c, Tipo_Gestion__c, Operador__c, ' +
            'Respuesta__c, Efectividad__c, Comentario__c, CreatedDate, CreatedById, CreatedBy.Name ' +
            'FROM Gestion_Expedientes__c ' +
            'WHERE ' + parentField + ' = :parentId ' +
            'ORDER BY CreatedDate DESC ' +
            'LIMIT :limitSize OFFSET :offset';
        result.gestiones = Database.query(dataQuery);

        return result;
    }

    /**
     * Obtiene el siguiente número de gestión para mostrar al usuario
     */
    @AuraEnabled
    public static String obtenerSiguienteNumero(Id parentId) {
        List<Gestion_Expedientes__c> ultima = [
            SELECT Name
            FROM Gestion_Expedientes__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (ultima.isEmpty()) {
            return 'GE-00001';
        }

        String ultimoName = ultima[0].Name;
        String numStr = ultimoName.replaceAll('[^0-9]', '');
        Integer siguiente = Integer.valueOf(numStr) + 1;
        return 'GE-' + String.valueOf(siguiente).leftPad(5, '0');
    }

    /**
     * Crea una nueva gestión asociada a Expediente o Caso.
     * En Caso: Operador interno "Caso" (no visible en UI) + respuesta + efectividad.
     * En Expediente: operador SE/CTV + respuesta filtrada + efectividad.
     */
    @AuraEnabled
    public static Gestion_Expedientes__c crearGestion(
        Id parentId,
        String celular,
        String medio,
        String tipoGestion,
        String operador,
        String respuesta,
        String comentario,
        String efectividad
    ) {
        String parentField = resolveParentField(parentId);
        Boolean esCaso = parentField == 'Caso__c';

        Gestion_Expedientes__c gestion = new Gestion_Expedientes__c(
            Celular__c = celular,
            Medio__c = medio,
            Tipo_Gestion__c = tipoGestion,
            Operador__c = esCaso ? OPERADOR_CASO : operador,
            Respuesta__c = respuesta,
            Comentario__c = comentario,
            Efectividad__c = efectividad
        );
        gestion.put(parentField, parentId);

        insert gestion;

        return [
            SELECT Id, Name, Celular__c, Medio__c, Tipo_Gestion__c, Operador__c,
                   Respuesta__c, Efectividad__c, Comentario__c, CreatedDate, CreatedBy.Name
            FROM Gestion_Expedientes__c
            WHERE Id = :gestion.Id
            LIMIT 1
        ];
    }

    /**
     * Elimina una gestión
     */
    @AuraEnabled
    public static void eliminarGestion(Id gestionId) {
        Gestion_Expedientes__c gestion = [
            SELECT Id FROM Gestion_Expedientes__c WHERE Id = :gestionId LIMIT 1
        ];
        delete gestion;
    }

    private static String resolveParentField(Id parentId) {
        if (parentId == null) {
            throw new AuraHandledException('No se recibió el Id del registro padre.');
        }

        String prefix = String.valueOf(parentId).substring(0, 3);
        if (prefix == CASE_PREFIX) {
            return 'Caso__c';
        }
        if (prefix == EXPEDIENTE_PREFIX) {
            return 'Expediente_de_Negativos__c';
        }

        throw new AuraHandledException('El registro padre no es un Caso ni un Expediente de Negativos.');
    }

    public class GestionesResult {
        @AuraEnabled public List<Gestion_Expedientes__c> gestiones { get; set; }
        @AuraEnabled public Integer total { get; set; }

        public GestionesResult() {
            this.gestiones = new List<Gestion_Expedientes__c>();
            this.total = 0;
        }
    }
}
