/**
 * Batch de backfill del crédito/saldo varietal en forma BULKIFICADA (SE-345).
 *
 * A diferencia de RecalcularCreditoVarietalBatch (que llama al servicio por cada
 * CG), éste procesa el scope con pocas queries: calcula crédito por variedad
 * (desde Toneladas de crédito), débito por variedad (desde Tonelada__c de
 * escáner y cesión), crea/actualiza/resetea Detalle_Variedad_CG__c, recalcula
 * Saldo_Cuenta__c y vincula las HT de crédito a su Detalle. Recomendado para
 * volúmenes altos de datos.
 */
public with sharing class RecalcularCreditoVarietalBulkBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String ORIGEN_ESCANER = 'Escáner varietal';
  private static final String ORIGEN_CESION = 'Cesión HT';
  private static final Set<String> ORIGENES_CREDITO = new Set<String>{
    'Compra SF',
    'Compra HT'
  };
  private static final Set<String> ETAPAS_VARIETALES = new Set<String>{
    'Cobrada',
    'Cancelada por NC',
    'Acreditada',
    'Reacreditada',
    'Recibida',
    'Cedida'
  };

  private Integer cuentasProcesadas = 0;
  private Integer errores = 0;

  /**
   * QueryLocator de cuentas varietales con productor y cultivo.
   */
  public Database.QueryLocator start(Database.BatchableContext bc) {
    String tecnologia = CuentaGranariaVarietalCreditoService.obtenerTecnologiaVarietal();
    return Database.getQueryLocator(
      [
        SELECT Id, Productor__c, Cultivo__c, Campania__c
        FROM Cuenta_Granaria__c
        WHERE
          Tecnologia__c = :tecnologia
          AND Productor__c != NULL
          AND Cultivo__c != NULL
      ]
    );
  }

  /**
   * Recalcula crédito/saldo de todas las cuentas del scope en bloque:
   * crédito por variedad, débito por variedad, persistencia de Detalle_Variedad_CG__c,
   * Saldo_Cuenta__c de cada CG y vínculo de HT de crédito a su Detalle.
   */
  public void execute(
    Database.BatchableContext bc,
    List<Cuenta_Granaria__c> scope
  ) {
    Set<Id> cgIds = new Set<Id>();
    Map<String, Id> cgIdPorClave = new Map<String, Id>();
    Set<Id> productorIds = new Set<Id>();
    Set<Id> cultivoIds = new Set<Id>();
    for (Cuenta_Granaria__c cg : scope) {
      cgIds.add(cg.Id);
      cgIdPorClave.put(
        claveCg(cg.Productor__c, cg.Cultivo__c, cg.Campania__c),
        cg.Id
      );
      productorIds.add(cg.Productor__c);
      cultivoIds.add(cg.Cultivo__c);
    }

    // Crédito por variedad (desde Toneladas de crédito).
    Map<String, Decimal> creditoPorClave = new Map<String, Decimal>();
    for (Tonelada__c tn : [
      SELECT
        Productor__c,
        Cultivo__c,
        Campania__c,
        Variedad__c,
        HT_Id__r.HT_Original__r.Variedad__c,
        Cantidad_con_Signo__c,
        Etapa__c
      FROM Tonelada__c
      WHERE
        Productor__c IN :productorIds
        AND Cultivo__c IN :cultivoIds
        AND Origen__c IN :ORIGENES_CREDITO
        AND (Etapa__c IN :ETAPAS_VARIETALES
        OR (Etapa__c = 'Aplicada'
        AND HT_Id__r.HT_Original__r.Etapa__c = 'Cancelada por NC'))
        AND Variedad__c != NULL
    ]) {
      Id cgId = cgIdPorClave.get(
        claveCg(tn.Productor__c, tn.Cultivo__c, tn.Campania__c)
      );
      if (cgId == null) {
        continue;
      }
      Id variedadId = tn.Etapa__c == 'Aplicada' &&
        tn.HT_Id__r.HT_Original__c != null
        ? tn.HT_Id__r.HT_Original__r.Variedad__c
        : tn.Variedad__c;
      if (variedadId == null) {
        continue;
      }
      Decimal toneladas = tn.Cantidad_con_Signo__c != null
        ? tn.Cantidad_con_Signo__c
        : 0;
      String clave = claveVariedad(cgId, variedadId);
      creditoPorClave.put(
        clave,
        (creditoPorClave.get(clave) != null ? creditoPorClave.get(clave) : 0) +
        toneladas
      );
    }

    // Débito por variedad (desde Toneladas de escáner varietal y cesión).
    Map<String, Decimal> debitoPorClave = new Map<String, Decimal>();
    for (Tonelada__c tn : [
      SELECT Cuenta_Granaria__c, Variedad__c, Cantidad_con_Signo__c
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c IN :cgIds
        AND Variedad__c != NULL
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND (Origen__c = :ORIGEN_ESCANER
        OR Origen__c = :ORIGEN_CESION)
        AND Signo__c = -1
    ]) {
      String clave = claveVariedad(tn.Cuenta_Granaria__c, tn.Variedad__c);
      Decimal total = tn.Cantidad_con_Signo__c != null
        ? tn.Cantidad_con_Signo__c
        : 0;
      debitoPorClave.put(
        clave,
        (debitoPorClave.get(clave) != null ? debitoPorClave.get(clave) : 0) +
        total
      );
    }

    // Detalles existentes.
    Map<String, Detalle_Variedad_CG__c> detallePorClave = new Map<String, Detalle_Variedad_CG__c>();
    for (Detalle_Variedad_CG__c sc : [
      SELECT Id, Cuenta_Granaria__c, Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c IN :cgIds
    ]) {
      detallePorClave.put(
        claveVariedad(sc.Cuenta_Granaria__c, sc.Variedad__c),
        sc
      );
    }

    Set<String> clavesVariedades = new Set<String>();
    clavesVariedades.addAll(creditoPorClave.keySet());
    clavesVariedades.addAll(debitoPorClave.keySet());

    List<Detalle_Variedad_CG__c> aActualizar = new List<Detalle_Variedad_CG__c>();
    List<Detalle_Variedad_CG__c> aCrear = new List<Detalle_Variedad_CG__c>();
    for (String clave : clavesVariedades) {
      List<String> partes = clave.split('\\|');
      Id cgId = partes[0];
      Id variedadId = partes[1];
      Decimal credito = creditoPorClave.get(clave) != null
        ? creditoPorClave.get(clave)
        : 0;
      Decimal debito = debitoPorClave.get(clave) != null
        ? debitoPorClave.get(clave)
        : 0;
      Decimal saldo = credito + debito;

      if (detallePorClave.containsKey(clave)) {
        aActualizar.add(
          new Detalle_Variedad_CG__c(
            Id = detallePorClave.get(clave).Id,
            Credito_Variedad__c = credito,
            Saldo_Variedad__c = saldo
          )
        );
      } else {
        aCrear.add(
          new Detalle_Variedad_CG__c(
            Clave_Varietal__c = clave,
            Cuenta_Granaria__c = cgId,
            Variedad__c = variedadId,
            Credito_Variedad__c = credito,
            Saldo_Variedad__c = saldo
          )
        );
      }
    }
    if (!aActualizar.isEmpty()) {
      Database.update(aActualizar, false);
    }
    if (!aCrear.isEmpty()) {
      Database.insert(aCrear, false);
    }

    // Resetear detalles que ya no tienen crédito ni débito.
    List<Detalle_Variedad_CG__c> aResetear = new List<Detalle_Variedad_CG__c>();
    for (String clave : detallePorClave.keySet()) {
      if (!clavesVariedades.contains(clave)) {
        aResetear.add(
          new Detalle_Variedad_CG__c(
            Id = detallePorClave.get(clave).Id,
            Credito_Variedad__c = 0,
            Saldo_Variedad__c = 0
          )
        );
      }
    }
    if (!aResetear.isEmpty()) {
      Database.update(aResetear, false);
    }

    // Saldo de cada CG = crédito total + débito total.
    Map<Id, Decimal> creditoPorCg = new Map<Id, Decimal>();
    Map<Id, Decimal> debitoPorCg = new Map<Id, Decimal>();
    for (String clave : creditoPorClave.keySet()) {
      Id cgId = clave.split('\\|')[0];
      creditoPorCg.put(
        cgId,
        (creditoPorCg.get(cgId) != null ? creditoPorCg.get(cgId) : 0) +
        creditoPorClave.get(clave)
      );
    }
    for (String clave : debitoPorClave.keySet()) {
      Id cgId = clave.split('\\|')[0];
      debitoPorCg.put(
        cgId,
        (debitoPorCg.get(cgId) != null ? debitoPorCg.get(cgId) : 0) +
        debitoPorClave.get(clave)
      );
    }
    List<Cuenta_Granaria__c> cgsAActualizar = new List<Cuenta_Granaria__c>();
    for (Id cgId : cgIds) {
      Decimal credito = creditoPorCg.get(cgId) != null
        ? creditoPorCg.get(cgId)
        : 0;
      Decimal debito = debitoPorCg.get(cgId) != null
        ? debitoPorCg.get(cgId)
        : 0;
      cgsAActualizar.add(
        new Cuenta_Granaria__c(Id = cgId, Saldo_Cuenta__c = debito + credito)
      );
    }
    if (!cgsAActualizar.isEmpty()) {
      Database.update(cgsAActualizar, false);
    }

    // Vincular HT de crédito a su Detalle (para la related list).
    Map<String, Id> detalleIdPorClave = new Map<String, Id>();
    for (Detalle_Variedad_CG__c sc : [
      SELECT Id, Cuenta_Granaria__c, Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c IN :cgIds
    ]) {
      detalleIdPorClave.put(
        claveVariedad(sc.Cuenta_Granaria__c, sc.Variedad__c),
        sc.Id
      );
    }
    List<Hectareas_Tecnologicas__c> htsAActualizar = new List<Hectareas_Tecnologicas__c>();
    for (Hectareas_Tecnologicas__c ht : [
      SELECT
        Id,
        Productor__c,
        Cultivo__c,
        Campania__c,
        Variedad__c,
        Detalle_Variedad_CG__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c IN :productorIds
        AND Cultivo__c IN :cultivoIds
        AND Origen__c IN :ORIGENES_CREDITO
        AND Signo__c = 1
        AND Variedad__c != NULL
    ]) {
      Id cgId = cgIdPorClave.get(
        claveCg(ht.Productor__c, ht.Cultivo__c, ht.Campania__c)
      );
      if (cgId == null) {
        continue;
      }
      Id detalleId = detalleIdPorClave.get(claveVariedad(cgId, ht.Variedad__c));
      if (detalleId != null && ht.Detalle_Variedad_CG__c != detalleId) {
        htsAActualizar.add(
          new Hectareas_Tecnologicas__c(
            Id = ht.Id,
            Detalle_Variedad_CG__c = detalleId
          )
        );
      }
    }
    if (!htsAActualizar.isEmpty()) {
      Database.update(htsAActualizar, false);
    }

    cuentasProcesadas += scope.size();
  }

  /**
   * Log de cierre del batch.
   */
  public void finish(Database.BatchableContext bc) {
    System.debug(
      'RecalcularCreditoVarietalBulkBatch finalizado: cuentas=' +
      cuentasProcesadas
    );
  }

  /**
   * Clave compuesta de una Cuenta Granaria: productor|cultivo|campaña.
   */
  private static String claveCg(Id productor, Id cultivo, Id campania) {
    return String.valueOf(productor) +
      '|' +
      String.valueOf(cultivo) +
      '|' +
      String.valueOf(campania);
  }

  /**
   * Clave compuesta de una sub-cuenta por variedad: cgId|variedadId.
   */
  private static String claveVariedad(Id cgId, Id variedadId) {
    return String.valueOf(cgId) + '|' + String.valueOf(variedadId);
  }
}
