public with sharing class ActualizarCuentaGranariaVarietalBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
  private Integer camionesProcesados = 0;
  private Integer errores = 0;

  public Database.QueryLocator start(Database.BatchableContext bc) {
    if (Test.isRunningTest()) {
      return Database.getQueryLocator(
        [
          SELECT Id, Peso_Neto__c, Titular__c, Cultivo__c, Cosecha__c
          FROM Movimiento_BolsaTech__c
        ]
      );
    }
    return Database.getQueryLocator(
      [
        SELECT Id, Peso_Neto__c, Titular__c, Cultivo__c, Cosecha__c
        FROM Movimiento_BolsaTech__c
        WHERE
          Cultivo_Varietal__c = TRUE
          AND Estado__c = 'Procesado'
          AND No_Debitar__c = FALSE
      ]
    );
  }

  public void execute(
    Database.BatchableContext bc,
    List<Movimiento_BolsaTech__c> movimientos
  ) {
    if (movimientos.isEmpty()) {
      return;
    }

    Set<Id> mbtIds = new Set<Id>();
    for (Movimiento_BolsaTech__c m : movimientos) {
      mbtIds.add(m.Id);
    }

    // Idempotencia: camiones que ya tienen débito varietal aplicado
    Set<Id> yaDebitados = new Set<Id>();
    for (Tonelada__c t : [
      SELECT Mov_BolsaTech__c
      FROM Tonelada__c
      WHERE Mov_BolsaTech__c IN :mbtIds AND Origen__c = 'Escáner varietal'
    ]) {
      yaDebitados.add(t.Mov_BolsaTech__c);
    }

    // Líneas del escáner vinculadas a estos camiones
    Map<Id, List<Detalle_Variedad_CG__c>> lineasPorMbt = new Map<Id, List<Detalle_Variedad_CG__c>>();
    for (Detalle_Variedad_CG__c det : [
      SELECT Id, Movimiento_BolsaTech__c, Variedad__c, Porcentaje_Varietal__c
      FROM Detalle_Variedad_CG__c
      WHERE Movimiento_BolsaTech__c IN :mbtIds
    ]) {
      if (!lineasPorMbt.containsKey(det.Movimiento_BolsaTech__c)) {
        lineasPorMbt.put(
          det.Movimiento_BolsaTech__c,
          new List<Detalle_Variedad_CG__c>()
        );
      }
      lineasPorMbt.get(det.Movimiento_BolsaTech__c).add(det);
    }

    // Resolver cultivo (texto) -> Id
    Set<String> cultivoNombres = new Set<String>();
    for (Movimiento_BolsaTech__c m : movimientos) {
      if (String.isNotBlank(m.Cultivo__c)) {
        cultivoNombres.add(m.Cultivo__c);
      }
    }
    Map<String, Id> cultivoPorNombre = new Map<String, Id>();
    for (Cultivo__c c : [
      SELECT Id, Name
      FROM Cultivo__c
      WHERE Name IN :cultivoNombres
    ]) {
      cultivoPorNombre.put(c.Name, c.Id);
    }

    for (Movimiento_BolsaTech__c m : movimientos) {
      if (yaDebitados.contains(m.Id)) {
        continue;
      }
      Id cultivoId = cultivoPorNombre.get(m.Cultivo__c);
      Id productorId = m.Titular__c;
      if (cultivoId == null || productorId == null) {
        continue;
      }
      Id campanaId = resolverCampana(cultivoId, m.Cosecha__c);

      List<Detalle_Variedad_CG__c> lineas = lineasPorMbt.containsKey(m.Id)
        ? lineasPorMbt.get(m.Id)
        : new List<Detalle_Variedad_CG__c>();
      if (lineas.isEmpty()) {
        continue;
      }

      List<CuentaGranariaVarietalDebitService.LineaVarietal> lineasVarietal = new List<CuentaGranariaVarietalDebitService.LineaVarietal>();
      for (Detalle_Variedad_CG__c l : lineas) {
        lineasVarietal.add(
          new CuentaGranariaVarietalDebitService.LineaVarietal(
            l.Variedad__c,
            l.Porcentaje_Varietal__c
          )
        );
      }

      CuentaGranariaVarietalDebitService.ResultadoDebito r = CuentaGranariaVarietalDebitService.procesarDebito(
        productorId,
        campanaId,
        cultivoId,
        m.Peso_Neto__c,
        lineasVarietal,
        m.Id
      );
      if (r.exitoso) {
        camionesProcesados++;
      } else {
        errores++;
      }
    }

    // Abrir/cerrar expedientes de las variedades afectadas
    CuentaGranariaVarietalExpedienteService.procesarAperturasYCierres();
  }

  public void finish(Database.BatchableContext bc) {
    System.debug(
      'ActualizarCuentaGranariaVarietalBatch: procesados=' +
        camionesProcesados +
        ', errores=' +
        errores
    );
  }

  public void execute(SchedulableContext sc) {
    Database.executeBatch(new ActualizarCuentaGranariaVarietalBatch(), 200);
  }

  private static Id resolverCampana(Id cultivoId, String anio) {
    if (String.isBlank(anio)) {
      return null;
    }
    List<Campana_Agricola__c> camps = [
      SELECT Id
      FROM Campana_Agricola__c
      WHERE Cultivo__c = :cultivoId AND Ano__c = :anio
      ORDER BY Ano__c DESC
      LIMIT 1
    ];
    return camps.isEmpty() ? null : camps[0].Id;
  }
}
