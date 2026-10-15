public with sharing class EnvioCorreoMbtInicialBatch implements Database.Batchable<SObject> {
    private final String cosecha;

    public EnvioCorreoMbtInicialBatch(String cosecha) {
        this.cosecha = cosecha;
    }

    public Database.QueryLocator start(Database.BatchableContext contexto) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Movimiento_BolsaTech__c
            WHERE Cosecha__c = :cosecha
            AND Titular__c != null
            AND Tecnologia__c = :EnvioCorreoMbtInicialService.TECNOLOGIA
        ]);
    }

    public void execute(Database.BatchableContext contexto, List<Movimiento_BolsaTech__c> alcance) {
        EnvioCorreoMbtInicialService.procesar(new Map<Id, Movimiento_BolsaTech__c>(alcance).keySet());
    }

    public void finish(Database.BatchableContext contexto) {
    }
}
