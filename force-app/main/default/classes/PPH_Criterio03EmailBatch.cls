public with sharing class PPH_Criterio03EmailBatch implements Database.Batchable<sObject>, Schedulable {
  public static final String CRITERIO_03 = '03 - Deuda o expedientes abiertos';
  public static final String CRON_DIARIO = '0 0 1 * * ?';

  public void execute(SchedulableContext sc) {
    Database.executeBatch(new PPH_Criterio03EmailBatch(), 200);
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Productor__c,
          Productor__r.Direccion_de_Correo_electronico_del_CUIT__c
        FROM Plan_de_Siembra__c
        WHERE
          Criterio_Alerta__c INCLUDES (:CRITERIO_03)
          AND Fecha_Detectada_Alerta__c = :Date.today().addDays(-1)
          AND Mail_Criterio_03_Enviado__c = NULL
          AND Estado__c NOT IN ('Adherido', 'Rechazado', 'Cancelado')
      ]
    );
  }

  public void execute(
    Database.BatchableContext bc,
    List<Plan_de_Siembra__c> scope
  ) {
    List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
    List<Plan_de_Siembra__c> aMarcar = new List<Plan_de_Siembra__c>();

    for (Plan_de_Siembra__c plan : scope) {
      Messaging.SingleEmailMessage mail = PPH_NotificacionService.buildMail(
        plan.Productor__r.Direccion_de_Correo_electronico_del_CUIT__c,
        Label.PPH_Mail_Criterio_03_Asunto,
        Label.PPH_Mail_Criterio_03_Cuerpo
      );

      if (mail != null) {
        mails.add(mail);
        aMarcar.add(
          new Plan_de_Siembra__c(
            Id = plan.Id,
            Mail_Criterio_03_Enviado__c = Date.today()
          )
        );
      }
    }

    PPH_NotificacionService.send(mails);

    if (!aMarcar.isEmpty()) {
      update aMarcar;
    }
  }

  public void finish(Database.BatchableContext bc) {
  }
}
