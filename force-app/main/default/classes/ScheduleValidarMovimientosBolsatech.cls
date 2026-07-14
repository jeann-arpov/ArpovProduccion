public class ScheduleValidarMovimientosBolsatech implements Schedulable {
    //BatchValidarMovimientosBolsatechTest
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new BatchValidarMovimientosBolsatech(), 200);
    }
}