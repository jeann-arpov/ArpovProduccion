public with sharing class PlanDeSiembraTriggerHandler extends TriggerHandler {
  public override void afterInsert() {
    marcarCuentaGranariaAdherida((List<Plan_de_Siembra__c>) Trigger.new, null);
  }

  public override void afterUpdate() {
    marcarCuentaGranariaAdherida(
      (List<Plan_de_Siembra__c>) Trigger.new,
      (Map<Id, Plan_de_Siembra__c>) Trigger.oldMap
    );
    notificarResultadoAlProductor(
      (List<Plan_de_Siembra__c>) Trigger.new,
      (Map<Id, Plan_de_Siembra__c>) Trigger.oldMap
    );
  }

  private static void marcarCuentaGranariaAdherida(
    List<Plan_de_Siembra__c> planes,
    Map<Id, Plan_de_Siembra__c> oldMap
  ) {
    List<Plan_de_Siembra__c> planesRecienAdheridos = new List<Plan_de_Siembra__c>();
    Set<Id> parametroIds = new Set<Id>();

    for (Plan_de_Siembra__c plan : planes) {
      if (
        !pasoAAdherido(plan, oldMap) ||
        plan.Productor__c == null ||
        plan.Parametro_PPH__c == null
      ) {
        continue;
      }
      planesRecienAdheridos.add(plan);
      parametroIds.add(plan.Parametro_PPH__c);
    }

    if (planesRecienAdheridos.isEmpty()) {
      return;
    }

    Map<Id, Id> campanaPorParametro = new Map<Id, Id>();
    for (Parametro_PPH__c parametro : [
      SELECT Id, Campana__c
      FROM Parametro_PPH__c
      WHERE Id IN :parametroIds AND Campana__c != NULL
    ]) {
      campanaPorParametro.put(parametro.Id, parametro.Campana__c);
    }

    Set<String> clavesProductorCampania = new Set<String>();
    for (Plan_de_Siembra__c plan : planesRecienAdheridos) {
      Id campaniaId = campanaPorParametro.get(plan.Parametro_PPH__c);
      if (campaniaId != null) {
        clavesProductorCampania.add(plan.Productor__c + '|' + campaniaId);
      }
    }

    if (clavesProductorCampania.isEmpty()) {
      return;
    }

    Set<Id> productorIds = new Set<Id>();
    Set<Id> campaniaIds = new Set<Id>();
    for (String clave : clavesProductorCampania) {
      List<String> partes = clave.split('\\|', -1);
      productorIds.add((Id) partes[0]);
      campaniaIds.add((Id) partes[1]);
    }

    List<Cuenta_Granaria__c> cuentasAActualizar = new List<Cuenta_Granaria__c>();
    for (Cuenta_Granaria__c cg : [
      SELECT Id, Productor__c, Campania__c, PPH_Adherida__c
      FROM Cuenta_Granaria__c
      WHERE Productor__c IN :productorIds AND Campania__c IN :campaniaIds
    ]) {
      String clave = cg.Productor__c + '|' + cg.Campania__c;
      if (
        clavesProductorCampania.contains(clave) && cg.PPH_Adherida__c != true
      ) {
        cuentasAActualizar.add(
          new Cuenta_Granaria__c(Id = cg.Id, PPH_Adherida__c = true)
        );
      }
    }

    if (!cuentasAActualizar.isEmpty()) {
      update cuentasAActualizar;
    }
  }

  private static Boolean pasoAAdherido(
    Plan_de_Siembra__c plan,
    Map<Id, Plan_de_Siembra__c> oldMap
  ) {
    if (plan.Estado__c != 'Adherido') {
      return false;
    }
    if (oldMap == null) {
      return true;
    }
    Plan_de_Siembra__c anterior = oldMap.get(plan.Id);
    return anterior == null || anterior.Estado__c != 'Adherido';
  }

  private static void notificarResultadoAlProductor(
    List<Plan_de_Siembra__c> planes,
    Map<Id, Plan_de_Siembra__c> oldMap
  ) {
    List<Plan_de_Siembra__c> planesAprobados = new List<Plan_de_Siembra__c>();
    List<Plan_de_Siembra__c> planesRechazados = new List<Plan_de_Siembra__c>();

    for (Plan_de_Siembra__c plan : planes) {
      if (plan.Productor__c == null) {
        continue;
      }

      String estadoAnterior = oldMap.get(plan.Id) != null
        ? oldMap.get(plan.Id).Estado__c
        : null;

      if (plan.Estado__c == 'Adherido' && estadoAnterior != 'Adherido') {
        planesAprobados.add(plan);
      } else if (
        plan.Estado__c == 'Rechazado' &&
        estadoAnterior != 'Rechazado'
      ) {
        planesRechazados.add(plan);
      }
    }

    if (planesAprobados.isEmpty() && planesRechazados.isEmpty()) {
      return;
    }

    Set<Id> productorIds = new Set<Id>();
    for (Plan_de_Siembra__c plan : planesAprobados) {
      productorIds.add(plan.Productor__c);
    }
    for (Plan_de_Siembra__c plan : planesRechazados) {
      productorIds.add(plan.Productor__c);
    }

    Map<Id, Account> productores = new Map<Id, Account>(
      [
        SELECT Id, Direccion_de_Correo_electronico_del_CUIT__c
        FROM Account
        WHERE Id IN :productorIds
      ]
    );

    OrgWideEmailAddress sender = getSenderEmail();

    List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();

    for (Plan_de_Siembra__c plan : planesAprobados) {
      Messaging.SingleEmailMessage mail = buildMail(
        productores.get(plan.Productor__c),
        Label.PPH_Notificacion_Aprobada_Asunto,
        Label.PPH_Notificacion_Aprobada_Cuerpo,
        sender
      );
      if (mail != null) {
        mails.add(mail);
      }
    }

    for (Plan_de_Siembra__c plan : planesRechazados) {
      Messaging.SingleEmailMessage mail = buildMail(
        productores.get(plan.Productor__c),
        Label.PPH_Notificacion_Rechazada_Asunto,
        Label.PPH_Notificacion_Rechazada_Cuerpo,
        sender
      );
      if (mail != null) {
        mails.add(mail);
      }
    }

    if (mails.isEmpty()) {
      return;
    }

    try {
      Messaging.sendEmail(mails);
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error notificando resultado PPH: ' + e.getMessage()
      );
    }
  }

  private static Messaging.SingleEmailMessage buildMail(
    Account productor,
    String asunto,
    String cuerpo,
    OrgWideEmailAddress sender
  ) {
    if (
      productor == null ||
      String.isBlank(productor.Direccion_de_Correo_electronico_del_CUIT__c)
    ) {
      return null;
    }

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(
      new List<String>{ productor.Direccion_de_Correo_electronico_del_CUIT__c }
    );
    mail.setSubject(asunto);
    mail.setPlainTextBody(cuerpo);
    if (sender != null) {
      mail.setOrgWideEmailAddressId(sender.Id);
    }
    return mail;
  }

  private static OrgWideEmailAddress getSenderEmail() {
    List<OrgWideEmailAddress> owds = [
      SELECT Id
      FROM OrgWideEmailAddress
      WHERE Address = 'info@sembraevolucion.com.ar'
      LIMIT 1
    ];
    return owds.isEmpty() ? null : owds[0];
  }
}
