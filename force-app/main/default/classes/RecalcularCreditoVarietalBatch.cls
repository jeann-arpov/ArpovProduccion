public with sharing class RecalcularCreditoVarietalBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Integer cuentasProcesadas = 0;
  private Integer cuentasSinDatos = 0;
  private Integer cuentasConError = 0;

  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT Id, Productor__c, Cultivo__c, Campania__c
        FROM Cuenta_Granaria__c
        WHERE Tecnologia__c = 'RR1/RR2 - BT/Convencional'
      ]
    );
  }

  public void execute(
    Database.BatchableContext bc,
    List<Cuenta_Granaria__c> scope
  ) {
    for (Cuenta_Granaria__c cg : scope) {
      if (cg.Productor__c == null || cg.Cultivo__c == null) {
        cuentasSinDatos++;
        continue;
      }
      try {
        CuentaGranariaVarietalCreditoService.recalcularCreditos(
          cg.Productor__c,
          cg.Cultivo__c,
          cg.Campania__c
        );
        cuentasProcesadas++;
      } catch (Exception e) {
        cuentasConError++;
        System.debug(
          'RecalcularCreditoVarietalBatch error en CG ' +
          cg.Id +
          ': ' +
          e.getMessage()
        );
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
    System.debug(
      'RecalcularCreditoVarietalBatch finalizado: procesadas=' +
      cuentasProcesadas +
      ', sin productor/cultivo=' +
      cuentasSinDatos +
      ', errores=' +
      cuentasConError
    );
  }
}
