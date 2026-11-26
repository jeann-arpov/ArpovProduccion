/**
 * Batch de VALIDACIÓN de camiones varietales (trigo, SE-345).
 *
 * Toma los Movimiento_BolsaTech__c varietales en estado 'Creado' (o 'Con error'
 * modificado en las últimas 24hs para reintentar) y delega en
 * CuentaGranariaVarietalValidator.validate(). Al terminar encadena el débito
 * lanzando ActualizarCuentaGranariaVarietalBatch, y envía email con los errores.
 */
public class BatchValidarCuentaGranariaVarietal implements Database.Batchable<SObject>, Database.Stateful {
  List<String> errors = new List<String>();

  /**
   * QueryLocator de camiones varietales a validar.
   */
  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT
          Codigo_de_Muestra__c,
          CUIT_Titular__c,
          Cuit_Destinatario__c,
          Peso_Neto__c,
          Fecha_de_Analisis__c,
          Cultivo__c,
          Tecnologia__c,
          CTG__c
        FROM Movimiento_BolsaTech__c
        WHERE
          Cultivo_Varietal__c = TRUE
          AND (Estado__c = 'Creado'
          OR (Estado__c = 'Con error'
          AND LastModifiedDate = LAST_N_DAYS:1))
      ]
    );
  }

  /**
   * Valida cada camión del scope y acumula los errores del update.
   */
  public void execute(
    Database.BatchableContext bc,
    List<Movimiento_BolsaTech__c> scope
  ) {
    CuentaGranariaVarietalValidator.validate(scope);
    errors.addAll(
      BatchErrorHelper.getErrors(Database.update(scope, false), scope)
    );
  }

  /**
   * Envía email con los errores acumulados y encadena el débito varietal
   * (ActualizarCuentaGranariaVarietalBatch) para los camiones que quedaron 'A procesar'.
   */
  public void finish(Database.BatchableContext bc) {
    BatchErrorHelper.sendEmail(
      bc.getJobId(),
      errors,
      'Arpov: Errores en BatchValidarCuentaGranariaVarietal'
    );

    // Encadenado: al terminar la validación, dispara el débito varietal.
    Database.executeBatch(new ActualizarCuentaGranariaVarietalBatch(), 200);
  }
}
