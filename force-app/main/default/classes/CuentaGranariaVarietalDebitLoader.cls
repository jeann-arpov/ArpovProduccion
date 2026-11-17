/**
 * Utilidad para procesar débitos varietales de varios camiones en lote.
 * Encapsula el armado de CamionInput y delega cada uno en
 * CuentaGranariaVarietalDebitService.procesarDebito(). Al terminar dispara la
 * apertura/cierre de expedientes varietales.
 */
public with sharing class CuentaGranariaVarietalDebitLoader {
  /**
   * Datos de entrada de un camión a debitar: productor, campaña, cultivo,
   * MBT, peso neto y líneas varietales.
   */
  public class CamionInput {
    public Id productorId;
    public Id campanaId;
    public Id cultivoId;
    public Id mbtId;
    public Decimal pesoNetoKg;
    public List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas;
  }

  /**
   * Procesa una lista de camiones, devuelve la cantidad debitados con éxito
   * y al final invoca procesarAperturasYCierres de expedientes.
   */
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
