public with sharing class ScheduleProcesaVentasInformadas implements Schedulable {
    Boolean reprocesar;

    public ScheduleProcesaVentasInformadas() {
        this(false);
    }

    public ScheduleProcesaVentasInformadas(Boolean reprocesar) {
        this.reprocesar = reprocesar;
    }

    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new BatchApexProcesaVentasInformadas(reprocesar),1000);
    }
}