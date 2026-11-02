public with sharing class ScheduleCuentaGranariaVarietalExpediente implements Schedulable {
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
