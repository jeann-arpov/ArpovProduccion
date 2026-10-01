/**
 * Completa Localidad__c (y por fórmula la provincia) de establecimientos con coordenadas,
 * usando el mismo reverse geocode que EstablecimientosMap. Asíncrono porque el callout
 * no puede ir después del DML del guardado.
 */
public without sharing class EstablecimientoLocalidadQueueable implements Queueable, Database.AllowsCallouts {

    private static final Integer MAX_POR_JOB = 50;

    @TestVisible
    private static Boolean runInTests = false;

    private final Set<Id> establecimientoIds;

    public EstablecimientoLocalidadQueueable(Set<Id> establecimientoIds) {
        this.establecimientoIds = establecimientoIds;
    }

    public static void enqueue(List<Establecimiento__c> establecimientos) {
        if (Test.isRunningTest() && !runInTests) return;
        if (establecimientos == null || establecimientos.isEmpty()) return;

        Set<Id> ids = new Set<Id>();
        for (Establecimiento__c est : establecimientos) {
            if (est.Id != null
                && est.Localidad__c == null
                && est.Coordenadas__Latitude__s != null
                && est.Coordenadas__Longitude__s != null) {
                ids.add(est.Id);
            }
        }
        if (ids.isEmpty()) return;
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) return;

        System.enqueueJob(new EstablecimientoLocalidadQueueable(ids));
    }

    public void execute(QueueableContext context) {
        List<Establecimiento__c> pendientes = [
            SELECT Id, Coordenadas__Latitude__s, Coordenadas__Longitude__s
            FROM Establecimiento__c
            WHERE Id IN :establecimientoIds
            AND Localidad__c = null
            AND Coordenadas__Latitude__s != null
            AND Coordenadas__Longitude__s != null
            LIMIT :MAX_POR_JOB
        ];

        List<Establecimiento__c> toUpdate = new List<Establecimiento__c>();
        for (Establecimiento__c est : pendientes) {
            try {
                Id localidadId = EstablecimientosMap.resolveLocalidadId(
                    est.Coordenadas__Latitude__s,
                    est.Coordenadas__Longitude__s
                );
                if (localidadId != null) {
                    toUpdate.add(new Establecimiento__c(Id = est.Id, Localidad__c = localidadId));
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Reverse geocode falló para ' + est.Id + ': ' + e.getMessage());
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
    }
}
