/**
 * Scheduler que dispara la apertura/cierre de expedientes de negativos
 * varietales (CuentaGranariaVarietalExpedienteService).
 */
public with sharing class ScheduleCuentaGranariaVarietalExpediente implements Schedulable {
  /**
   * Ejecuta procesarAperturasYCierres y registra el resultado.
   */
  public void execute(SchedulableContext sc) {
    CuentaGranariaVarietalExpedienteService.ResultadoExpedientes resultado = CuentaGranariaVarietalExpedienteService.procesarAperturasYCierres();
    System.debug(
      'ScheduleCuentaGranariaVarietalExpediente: creados=' +
        resultado.expedientesCreados +
        ', cerrados=' +
        resultado.expedientesCerrados
    );
  }
}
