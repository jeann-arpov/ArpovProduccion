public with sharing class EnvioCorreoMbtInicialQueueable implements Queueable {
    private final Set<Id> movimientoIds;

    public EnvioCorreoMbtInicialQueueable(Set<Id> movimientoIds) {
        this.movimientoIds = movimientoIds == null ? new Set<Id>() : movimientoIds.clone();
    }

    public void execute(QueueableContext contexto) {
        EnvioCorreoMbtInicialService.procesar(movimientoIds);
    }
}
