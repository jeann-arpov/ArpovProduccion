public class BatchValidarCuentaGranariaVarietal implements Database.Batchable<SObject>, Database.Stateful {
  List<String> errors = new List<String>();

  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT
          Codigo_de_Muestra__c,
          CUIT_Titular__c,
          Cuit_Destinatario__c,
          Cuit_Remitente_Comercial__c,
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

  public void execute(
    Database.BatchableContext bc,
    List<Movimiento_BolsaTech__c> scope
  ) {
    CuentaGranariaVarietalValidator.validate(scope);
    errors.addAll(
      BatchErrorHelper.getErrors(Database.update(scope, false), scope)
    );
  }

  public void finish(Database.BatchableContext bc) {
    BatchErrorHelper.sendEmail(
      bc.getJobId(),
      errors,
      'Arpov: Errores en BatchValidarCuentaGranariaVarietal'
    );
  }
}
