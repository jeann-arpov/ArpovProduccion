/**
 * Scheduler que encola BatchValidarCuentaGranariaVarietal (validación de
 * camiones varietales).
 */
public class ScheduleValidarCuentaGranariaVarietal implements Schedulable {
  /**
   * Ejecuta el batch de validación varietal con scope 200.
   */
  public void execute(SchedulableContext ctx) {
    Database.executeBatch(new BatchValidarCuentaGranariaVarietal(), 200);
  }
}
