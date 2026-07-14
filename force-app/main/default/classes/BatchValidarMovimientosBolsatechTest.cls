@isTest
public class BatchValidarMovimientosBolsatechTest {
    public static testmethod void main() {
        BatchValidarMovimientosBolsatech batch = new BatchValidarMovimientosBolsatech();
        batch.execute(null, new List<Movimiento_BolsaTech__c>{new Movimiento_BolsaTech__c()});
        new ScheduleValidarMovimientosBolsatech().execute(null);
    }
}