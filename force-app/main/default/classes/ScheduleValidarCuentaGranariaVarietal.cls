public class ScheduleValidarCuentaGranariaVarietal implements Schedulable {
  public void execute(SchedulableContext ctx) {
    Database.executeBatch(new BatchValidarCuentaGranariaVarietal(), 200);
  }
}
