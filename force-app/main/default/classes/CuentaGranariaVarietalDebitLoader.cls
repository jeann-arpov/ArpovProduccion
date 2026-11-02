public with sharing class CuentaGranariaVarietalDebitLoader {
  public class CamionInput {
    public Id productorId;
    public Id campanaId;
    public Id cultivoId;
    public Id mbtId;
    public Decimal pesoNetoKg;
    public List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas;
  }

  public static Integer procesarCamiones(List<CamionInput> camiones) {
    Integer procesados = 0;
    for (CamionInput camion : camiones) {
      CuentaGranariaVarietalDebitService.ResultadoDebito resultado = CuentaGranariaVarietalDebitService.procesarDebito(
        camion.productorId,
        camion.campanaId,
        camion.cultivoId,
        camion.pesoNetoKg,
        camion.lineas,
        camion.mbtId
      );
      if (resultado.exitoso) {
        procesados++;
      }
    }
    CuentaGranariaVarietalExpedienteService.procesarAperturasYCierres();
    return procesados;
  }
}
