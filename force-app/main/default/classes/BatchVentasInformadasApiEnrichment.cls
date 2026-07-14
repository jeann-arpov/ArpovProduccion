/**
 * Backfill masivo de ventas informadas API sin enriquecimiento portal.
 */
public without sharing class BatchVentasInformadasApiEnrichment implements Database.Batchable<SObject>, Database.Stateful {

    private final Id createdById;
    private Integer totalActualizados = 0;
    private Integer totalErrores = 0;

    public BatchVentasInformadasApiEnrichment(Id apiUserId) {
        createdById = apiUserId;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        String soql =
            'SELECT ' +
            VentasInformadasPortalEnrichmentService.camposEnriquecimientoSoql() +
            ' FROM Ventas_Informadas__c' +
            ' WHERE Variedad_INASE__c = NULL' +
            ' AND Variedad__c != NULL';
        if (createdById != null) {
            soql += ' AND CreatedById = :createdById';
        }
        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext context, List<Ventas_Informadas__c> scope) {
        VentasInformadasPortalEnrichmentService.Result resultado =
            VentasInformadasPortalEnrichmentService.enriquecerYActualizar(scope);
        totalActualizados += resultado.actualizados;
        totalErrores += resultado.errores;
    }

    public void finish(Database.BatchableContext context) {
        System.debug(
            'BatchVentasInformadasApiEnrichment finalizado. Actualizados=' +
                totalActualizados +
                ' Errores=' +
                totalErrores
        );
    }

    @TestVisible
    public Integer getTotalActualizados() {
        return totalActualizados;
    }

    @TestVisible
    public Integer getTotalErrores() {
        return totalErrores;
    }
}