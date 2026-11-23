public with sharing class CuentaGranariaTriggerHandler extends TriggerHandler {
  @TestVisible
  private static Boolean HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = true;

  public override void afterInsert() {
    gestionarExpedientesNegativos((List<Cuenta_Granaria__c>) Trigger.new, null);
    recalcularCreditosVarietales((List<Cuenta_Granaria__c>) Trigger.new);
  }

  public override void afterUpdate() {
    gestionarExpedientesNegativos(
      (List<Cuenta_Granaria__c>) Trigger.new,
      (Map<Id, Cuenta_Granaria__c>) Trigger.oldMap
    );
  }

  /**
   * Recalcula el crédito/saldo varietal de las Cuentas Granarias varietales
   * recién creadas. Cubre el caso en que la HT (crédito) se creó antes que la
   * CG: al crearse la CG, se acredita el crédito pendiente (B-01).
   */
  private static void recalcularCreditosVarietales(
    List<Cuenta_Granaria__c> cuentas
  ) {
    Set<Id> cgIds = new Set<Id>();
    for (Cuenta_Granaria__c cg : cuentas) {
      if (cg.Id != null) {
        cgIds.add(cg.Id);
      }
    }
    if (cgIds.isEmpty()) {
      return;
    }

    Set<String> cultivosVarietales = CuentaGranariaVarietalCreditoService.obtenerCultivosVarietales();
    if (cultivosVarietales.isEmpty()) {
      return;
    }

    // Re-consulta la CG completa (con Productor/Cultivo/Campaña) para no
    // depender de los lookups de Trigger.new en afterInsert.
    List<Cuenta_Granaria__c> cgs = [
      SELECT Id, Productor__c, Cultivo__c, Campania__c
      FROM Cuenta_Granaria__c
      WHERE Id IN :cgIds
    ];

    Set<Id> cultivoIds = new Set<Id>();
    for (Cuenta_Granaria__c cg : cgs) {
      if (cg.Cultivo__c != null) {
        cultivoIds.add(cg.Cultivo__c);
      }
    }
    if (cultivoIds.isEmpty()) {
      return;
    }

    Set<Id> cultivosVarietalesIds = new Set<Id>();
    for (Cultivo__c c : [
      SELECT Id
      FROM Cultivo__c
      WHERE Id IN :cultivoIds AND Name IN :cultivosVarietales
    ]) {
      cultivosVarietalesIds.add(c.Id);
    }
    if (cultivosVarietalesIds.isEmpty()) {
      return;
    }

    for (Cuenta_Granaria__c cg : cgs) {
      if (
        cg.Productor__c != null &&
        cg.Cultivo__c != null &&
        cg.Campania__c != null &&
        cultivosVarietalesIds.contains(cg.Cultivo__c)
      ) {
        CuentaGranariaVarietalCreditoService.recalcularCreditos(
          cg.Productor__c,
          cg.Cultivo__c,
          cg.Campania__c
        );
      }
    }
  }

  private static void gestionarExpedientesNegativos(
    List<Cuenta_Granaria__c> nuevasCuentas,
    Map<Id, Cuenta_Granaria__c> oldMap
  ) {
    if (nuevasCuentas == null || nuevasCuentas.isEmpty()) {
      return;
    }

    Set<Id> cuentaIdsObjetivo = new Set<Id>();
    Map<Id, Cuenta_Granaria__c> cuentaPorId = new Map<Id, Cuenta_Granaria__c>();

    for (Cuenta_Granaria__c cg : nuevasCuentas) {
      if (cg == null || cg.Id == null || cg.Saldo_Cuenta__c == null) {
        continue;
      }

      if (cg.Es_Carga_Manual__c != true || cg.Saldo_Cuenta__c >= -3) {
        continue;
      }

      Boolean debeProcesar = (oldMap == null);
      if (!debeProcesar && oldMap.containsKey(cg.Id)) {
        Cuenta_Granaria__c oldCg = oldMap.get(cg.Id);
        debeProcesar =
          oldCg == null ||
          oldCg.Saldo_Cuenta__c != cg.Saldo_Cuenta__c ||
          oldCg.Es_Carga_Manual__c != cg.Es_Carga_Manual__c;
      }

      if (debeProcesar) {
        cuentaIdsObjetivo.add(cg.Id);
        cuentaPorId.put(cg.Id, cg);
      }
    }

    if (cuentaIdsObjetivo.isEmpty()) {
      return;
    }

    // Excluir Obtentor y sucursales (ParentId / Cuenta principal != null):
    // no se les crean expedientes
    Set<Id> productoresObjetivo = new Set<Id>();
    for (Cuenta_Granaria__c cg : cuentaPorId.values()) {
      if (cg.Productor__c != null) {
        productoresObjetivo.add(cg.Productor__c);
      }
    }
    Set<Id> productoresExcluidos = new Set<Id>();
    if (!productoresObjetivo.isEmpty()) {
      for (Account cuenta : [
        SELECT Id
        FROM Account
        WHERE
          Id IN :productoresObjetivo
          AND (RecordType.Name = 'Obtentor'
          OR ParentId != NULL)
      ]) {
        productoresExcluidos.add(cuenta.Id);
      }
    }
    if (!productoresExcluidos.isEmpty()) {
      for (Id cuentaId : new Set<Id>(cuentaIdsObjetivo)) {
        Cuenta_Granaria__c cg = cuentaPorId.get(cuentaId);
        if (cg != null && productoresExcluidos.contains(cg.Productor__c)) {
          cuentaIdsObjetivo.remove(cuentaId);
          cuentaPorId.remove(cuentaId);
        }
      }
      if (cuentaIdsObjetivo.isEmpty()) {
        return;
      }
    }

    Map<Id, Expediente_de_Negativos__c> expedienteActivoPorCg = new Map<Id, Expediente_de_Negativos__c>();
    for (Expediente_de_Negativos__c exp : [
      SELECT Id, Cuenta_Granaria__c, Estado_de_la_Etapa__c, CreatedDate
      FROM Expediente_de_Negativos__c
      WHERE
        Cuenta_Granaria__c IN :cuentaIdsObjetivo
        AND Cuenta_Granaria__c != NULL
        AND Estado_de_la_Etapa__c != 'Finalizado'
      ORDER BY CreatedDate DESC
    ]) {
      if (!expedienteActivoPorCg.containsKey(exp.Cuenta_Granaria__c)) {
        expedienteActivoPorCg.put(exp.Cuenta_Granaria__c, exp);
      }
    }

    Sembra_Evolucion__c config = Sembra_Evolucion__c.getInstance();
    Id obtentorId = (config != null &&
      config.Corteva_30_Id__c != null)
      ? Id.valueOf(config.Corteva_30_Id__c)
      : null;

    List<Expediente_de_Negativos__c> expedientesACrear = new List<Expediente_de_Negativos__c>();
    List<Expediente_de_Negativos__c> expedientesAActualizar = new List<Expediente_de_Negativos__c>();
    Map<Id, Id> expedientePorCg = new Map<Id, Id>();

    for (Id cuentaId : cuentaIdsObjetivo) {
      Cuenta_Granaria__c cg = cuentaPorId.get(cuentaId);
      if (cg == null) {
        continue;
      }

      Decimal saldoNegativo = cg.Saldo_Cuenta__c;
      Expediente_de_Negativos__c expedienteActivo = expedienteActivoPorCg.get(
        cuentaId
      );

      if (expedienteActivo != null) {
        expedientesAActualizar.add(
          new Expediente_de_Negativos__c(
            Id = expedienteActivo.Id,
            Saldo_Expediente__c = saldoNegativo
          )
        );
        expedientePorCg.put(cuentaId, expedienteActivo.Id);
        continue;
      }

      if (!HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS) {
        continue;
      }

      Expediente_de_Negativos__c nuevoExpediente = new Expediente_de_Negativos__c();
      nuevoExpediente.Campania__c = cg.Campania__c;
      nuevoExpediente.Cuenta__c = cg.Productor__c;
      nuevoExpediente.Cuenta_Granaria__c = cg.Id;
      nuevoExpediente.Saldo_Previo_al_Expediente__c = saldoNegativo;
      nuevoExpediente.Saldo_Expediente__c = saldoNegativo;
      nuevoExpediente.Tipo_expendiente__c = 'EXP';
      nuevoExpediente.Estado_de_la_Etapa__c = 'No empezado';
      nuevoExpediente.Etapa__c = 'Llamar';
      nuevoExpediente.Fecha_Cambio_Etapa__c = Date.today();
      nuevoExpediente.Gestionar__c = true;
      if (obtentorId != null) {
        nuevoExpediente.Obtentor__c = obtentorId;
      }
      expedientesACrear.add(nuevoExpediente);
    }

    if (!expedientesAActualizar.isEmpty()) {
      Database.update(expedientesAActualizar, false);
    }
    if (!expedientesACrear.isEmpty()) {
      List<Database.SaveResult> insertResults = Database.insert(
        expedientesACrear,
        false
      );
      for (Integer i = 0; i < insertResults.size(); i++) {
        if (insertResults[i].isSuccess()) {
          Id cgId = expedientesACrear[i].Cuenta_Granaria__c;
          if (cgId != null) {
            expedientePorCg.put(cgId, insertResults[i].getId());
          }
        }
      }
    }
    if (!expedientePorCg.isEmpty()) {
      //CuentaGranariaExpedienteService.vincularToneladasYMovimientosPorCg(expedientePorCg);
    }
  }
}
