public class CasoAlertaPPHQueueable implements Queueable {
  @TestVisible
  private static final String RECORD_TYPE_SE = 'Sembra_Evolucion';
  @TestVisible
  private static final String COLA_MESA_AYUDA = 'Mesa_Ayuda_SE';
  @TestVisible
  private static final String TIPO_CONSULTA = 'Consulta';
  @TestVisible
  private static final String TEMA_PPH = 'PPH';
  @TestVisible
  private static final String CAPSULA_MESA_AYUDA = 'MESA DE AYUDA';
  @TestVisible
  private static final String STATUS_ABIERTO = 'Abierto';
  @TestVisible
  private static final String ASUNTO_PPH = 'Criterio de Alerta PPH';

  private final List<Id> planIds;

  public CasoAlertaPPHQueueable(List<Id> planIds) {
    this.planIds = planIds == null ? new List<Id>() : planIds;
  }

  public void execute(QueueableContext context) {
    if (this.planIds.isEmpty()) {
      return;
    }
    sincronizarCasos(this.planIds);
  }

  @TestVisible
  private static void sincronizarCasos(List<Id> planIds) {
    Set<Id> ids = new Set<Id>();
    for (Id planId : planIds) {
      if (planId != null) {
        ids.add(planId);
      }
    }
    if (ids.isEmpty()) {
      return;
    }

    Id recordTypeId = obtenerRecordTypeId();
    Id colaId = Utils.getGroupId(COLA_MESA_AYUDA, 'Queue');

    List<Plan_de_Siembra__c> planes = [
      SELECT
        Id,
        Criterio_Alerta__c,
        Estado__c,
        Productor__c,
        Productor__r.N_CUIT__c,
        Parametro_PPH__r.Campana__c
      FROM Plan_de_Siembra__c
      WHERE Id IN :ids
    ];

    Map<Id, Case> casosExistentes = new Map<Id, Case>();
    for (Case caso : [
      SELECT Id, Plan_de_Siembra__c, IsClosed
      FROM Case
      WHERE Plan_de_Siembra__c IN :ids AND RecordTypeId = :recordTypeId
    ]) {
      casosExistentes.put(caso.Plan_de_Siembra__c, caso);
    }

    List<Case> aInsertar = new List<Case>();
    List<Case> aActualizar = new List<Case>();

    for (Plan_de_Siembra__c plan : planes) {
      Case existente = casosExistentes.get(plan.Id);
      if (existente == null) {
        aInsertar.add(construirCaso(plan, recordTypeId, colaId));
      } else if (!existente.IsClosed) {
        aplicarCriterios(existente, plan);
        aActualizar.add(existente);
      }
    }

    if (!aInsertar.isEmpty()) {
      registrarErroresDml(Database.insert(aInsertar, false));
    }
    if (!aActualizar.isEmpty()) {
      registrarErroresDml(Database.update(aActualizar, false));
    }
  }

  private static void registrarErroresDml(List<Database.SaveResult> results) {
    for (Database.SaveResult result : results) {
      if (result.isSuccess()) {
        continue;
      }
      for (Database.Error error : result.getErrors()) {
        ErrorLogService.logMessage(
          error.getMessage(),
          'ERR-ADH',
          ErrorLogService.Severity.ERROR,
          'CasoAlertaPPHQueueable',
          new Map<String, Object>{
            'statusCode' => error.getStatusCode() == null
              ? null
              : error.getStatusCode().name(),
            'fields' => error.getFields()
          }
        );
      }
    }
  }

  private static Case construirCaso(
    Plan_de_Siembra__c plan,
    Id recordTypeId,
    Id colaId
  ) {
    Case caso = new Case(
      RecordTypeId = recordTypeId,
      Plan_de_Siembra__c = plan.Id,
      AccountId = plan.Productor__c,
      Type = TIPO_CONSULTA,
      Tema__c = TEMA_PPH,
      Status = STATUS_ABIERTO,
      Capsula__c = CAPSULA_MESA_AYUDA,
      Campana__c = plan.Parametro_PPH__r.Campana__c
    );
    if (colaId != null) {
      caso.OwnerId = colaId;
    }
    aplicarCriterios(caso, plan);
    return caso;
  }

  private static void aplicarCriterios(Case caso, Plan_de_Siembra__c plan) {
    caso.Criterio_Alerta__c = plan.Criterio_Alerta__c;
    caso.Estado_Adhesion__c = plan.Estado__c;
    caso.Subject =
      ASUNTO_PPH +
      (String.isNotBlank(plan.Productor__r.N_CUIT__c)
        ? ' - ' + plan.Productor__r.N_CUIT__c
        : '');
    caso.Description = construirDescripcion(plan);
  }

  private static String construirDescripcion(Plan_de_Siembra__c plan) {
    String criterios = String.isBlank(plan.Criterio_Alerta__c)
      ? 'Sin criterios'
      : plan.Criterio_Alerta__c.replace(';', ', ');
    String cuit = String.isBlank(plan.Productor__r.N_CUIT__c)
      ? 'No informado'
      : plan.Productor__r.N_CUIT__c;
    String estado = String.isBlank(plan.Estado__c)
      ? 'No informado'
      : plan.Estado__c;

    return 'Criterios de alerta: ' +
      criterios +
      '\nCUIT: ' +
      cuit +
      '\nEstado de la adhesión: ' +
      estado;
  }

  private static Id obtenerRecordTypeId() {
    Schema.RecordTypeInfo info = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(RECORD_TYPE_SE);
    return info != null ? info.getRecordTypeId() : null;
  }
}
