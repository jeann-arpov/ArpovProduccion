/**
 * Licencias relacionadas al expediente por CUIT: Expediente_de_Negativos__c.CUIT_cliente__c
 * frente a Licencia__c.N_CUIT__c. Solo licencias Aprobadas, Tecnologia Enlist y tipo Productor.
 */
public without sharing class ExpedienteLicenciasRelatedListController {
    @AuraEnabled(cacheable=true)
    public static RelatedListResponse getLicenciasForExpediente(Id expedienteId, Integer pageNumber, Integer pageSize) {
        RelatedListResponse res = new RelatedListResponse();
        res.licencias = new List<Map<String, String>>();
        res.pageNumber = pageNumber != null && pageNumber > 0 ? pageNumber : 1;
        res.pageSize = pageSize != null && pageSize > 0 ? pageSize : 10;
        if (res.pageSize > 100) {
            res.pageSize = 100;
        }

        if (expedienteId == null) {
            res.totalRecords = 0;
            res.totalPages = 0;
            res.diagnostico = 'expedienteId=null';
            return res;
        }

        List<Expediente_de_Negativos__c> exps = [
            SELECT Id, CUIT_cliente__c
            FROM Expediente_de_Negativos__c
            WHERE Id = :expedienteId
            LIMIT 1
        ];
        if (exps.isEmpty()) {
            res.errorMessage = 'No se encontró el expediente.';
            res.totalRecords = 0;
            res.totalPages = 0;
            res.diagnostico = 'expediente no encontrado; id=' + String.valueOf(expedienteId);
            return res;
        }

        String cuitCliente = exps[0].CUIT_cliente__c;
        res.clienteCuit = cuitCliente;
        if (String.isBlank(cuitCliente)) {
            res.totalRecords = 0;
            res.totalPages = 0;
            res.diagnostico = 'CUIT_cliente__c vacío en expediente';
            return res;
        }
        cuitCliente = cuitCliente.trim();

        String fromWhere =
            'FROM Licencia__c WHERE Estado__c = \'Aprobada\' AND N_CUIT__c = :cuitCliente' +
            ' AND Tecnologia__c = \'Enlist\' AND Tipo_de_Licencia__c = \'Productor\'';

        res.totalRecords = Database.countQuery('SELECT COUNT() ' + fromWhere);

        System.debug(
            LoggingLevel.INFO,
            'ExpLicRL expediente=' + expedienteId + ' cuitCliente=' + cuitCliente + ' total=' + res.totalRecords
        );

        res.diagnostico =
            'Aprobada; Enlist; Productor; cuit=' + cuitCliente + '; total=' + res.totalRecords;

        if (res.totalRecords == 0) {
            res.totalPages = 0;
            res.pageNumber = 1;
            return res;
        }

        res.totalPages = (Integer) Math.ceil(res.totalRecords / (Decimal) res.pageSize);
        if (res.pageNumber > res.totalPages) {
            res.pageNumber = res.totalPages;
        }

        Integer lim = res.pageSize;
        Integer off = (res.pageNumber - 1) * res.pageSize;

        String soql =
            'SELECT Id, Name ' +
            fromWhere +
            ' ORDER BY Created__c DESC NULLS LAST LIMIT :lim OFFSET :off';

        List<Licencia__c> licRows = (List<Licencia__c>) Database.query(soql);
        for (Licencia__c lic : licRows) {
            Map<String, String> row = new Map<String, String>();
            row.put('id', lic.Id);
            row.put('name', lic.Name != null ? lic.Name : '');
            res.licencias.add(row);
        }
        return res;
    }

    public class RelatedListResponse {
        @AuraEnabled
        public List<Map<String, String>> licencias { get; set; }
        @AuraEnabled
        public String clienteCuit { get; set; }
        @AuraEnabled
        public String errorMessage { get; set; }
        @AuraEnabled
        public Integer totalRecords { get; set; }
        @AuraEnabled
        public Integer totalPages { get; set; }
        @AuraEnabled
        public Integer pageNumber { get; set; }
        @AuraEnabled
        public Integer pageSize { get; set; }
        /** Texto corto para depurar en consola del navegador (no mostrar al usuario final). */
        @AuraEnabled
        public String diagnostico { get; set; }
    }
}