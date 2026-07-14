/**
 * Sincroniza Expediente_de_Negativos__c en MBT a partir de toneladas ya procesadas.
 * Se encola post-commit para evitar que flows posteriores (p. ej. débito BolsaTech)
 * sobrescriban el expediente en el MBT en la misma transacción.
 */
public class SincronizarMbtExpedienteQueueable implements Queueable {

    private final Set<Id> toneladaIds;

    public SincronizarMbtExpedienteQueueable(Set<Id> toneladaIds) {
        this.toneladaIds = toneladaIds == null ? new Set<Id>() : new Set<Id>(toneladaIds);
    }

    public void execute(QueueableContext context) {
        if (toneladaIds.isEmpty()) {
            return;
        }
        CuentaGranariaExpedienteService.sincronizarMbtDesdeToneladas(toneladaIds);
    }
}