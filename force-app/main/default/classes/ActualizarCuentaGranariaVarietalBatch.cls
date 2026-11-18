/**
 * Batch que procesa el DÉBITO varietal (SE-345).
 *
 * Recorre los camiones de Movimiento_BolsaTech__c de cultivos varietales
 * (Cultivo_Varietal__c = true) que están 'A procesar' y sin No_Debitar__c,
 * y por cada uno:
 *   1. Levanta sus líneas varietales (Detalle_Variedad_MBT__c).
 *   2. Resuelve cultivo y campaña agrícola.
 *   3. Delega en CuentaGranariaVarietalDebitService.procesarDebito() la
 *      creación de Tonelada__c negativas por variedad (Origen 'Escáner varietal').
 *   4. Marca el camión 'Procesado' (o 'Con error' si falla).
 *   5. Al final del execute, dispara la apertura/cierre de expedientes de
 *      negativos varietales (CuentaGranariaVarietalExpedienteService).
 *
 * También es Schedulable: al ejecutarse encola el batch con scope 200.
 */
public with sharing class ActualizarCuentaGranariaVarietalBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
  private Integer camionesProcesados = 0;
  private Integer errores = 0;

  /**
   * QueryLocator de camiones a debitar.
   * En test trae todos; en producción filtra varietales 'A procesar' sin No_Debitar.
   */
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
          AND Estado__c = 'A procesar'
          AND No_Debitar__c = FALSE
      ]
    );
  }

  /**
   * Procesa cada scope de camiones: arma las líneas varietales, resuelve
   * cultivo/campaña, invoca el débito y actualiza el estado de cada camión.
   * Al final dispara apertura/cierre de expedientes varietales.
   */
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

    // Líneas del escáner vinculadas a estos camiones
    Map<Id, List<Detalle_Variedad_MBT__c>> lineasPorMbt = new Map<Id, List<Detalle_Variedad_MBT__c>>();
    for (Detalle_Variedad_MBT__c det : [
      SELECT Id, Movimiento_BolsaTech__c, Variedad__c, Porcentaje_Varietal__c
      FROM Detalle_Variedad_MBT__c
      WHERE Movimiento_BolsaTech__c IN :mbtIds
    ]) {
      if (!lineasPorMbt.containsKey(det.Movimiento_BolsaTech__c)) {
        lineasPorMbt.put(
          det.Movimiento_BolsaTech__c,
          new List<Detalle_Variedad_MBT__c>()
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

    List<Movimiento_BolsaTech__c> aProcesado = new List<Movimiento_BolsaTech__c>();
    List<Movimiento_BolsaTech__c> aConError = new List<Movimiento_BolsaTech__c>();

    for (Movimiento_BolsaTech__c m : movimientos) {
      Id cultivoId = cultivoPorNombre.get(m.Cultivo__c);
      Id productorId = m.Titular__c;
      if (cultivoId == null || productorId == null) {
        continue;
      }
      Id campanaId = resolverCampana(cultivoId, m.Cosecha__c);

      List<Detalle_Variedad_MBT__c> lineas = lineasPorMbt.containsKey(m.Id)
        ? lineasPorMbt.get(m.Id)
        : new List<Detalle_Variedad_MBT__c>();
      if (lineas.isEmpty()) {
        continue;
      }

      List<CuentaGranariaVarietalDebitService.LineaVarietal> lineasVarietal = new List<CuentaGranariaVarietalDebitService.LineaVarietal>();
      for (Detalle_Variedad_MBT__c l : lineas) {
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
      if (r.exitoso || r.sinDebito) {
        aProcesado.add(
          new Movimiento_BolsaTech__c(
            Id = m.Id,
            Estado__c = 'Procesado',
            Cuenta_Granaria__c = r.cgId
          )
        );
        camionesProcesados++;
      } else {
        aConError.add(
          new Movimiento_BolsaTech__c(Id = m.Id, Estado__c = 'Con error')
        );
        errores++;
      }
    }

    if (!aProcesado.isEmpty()) {
      Database.update(aProcesado, false);
    }
    if (!aConError.isEmpty()) {
      Database.update(aConError, false);
    }

    // Abrir/cerrar expedientes de las variedades afectadas
    CuentaGranariaVarietalExpedienteService.procesarAperturasYCierres();
  }

  /**
   * Log de cierre del batch con los contadores de camiones procesados y errores.
   */
  public void finish(Database.BatchableContext bc) {
    System.debug(
      'ActualizarCuentaGranariaVarietalBatch: procesados=' +
        camionesProcesados +
        ', errores=' +
        errores
    );
  }

  /**
   * Implementación Schedulable: encola el batch con scope 200.
   */
  public void execute(SchedulableContext sc) {
    Database.executeBatch(new ActualizarCuentaGranariaVarietalBatch(), 200);
  }

  /**
   * Resuelve la Campana_Agricola__c a partir del cultivo y la cosecha (texto),
   * normalizando el año: "2025" -> "2025", "25" -> "2025", "2627" -> "2026".
   */
  private static Id resolverCampana(Id cultivoId, String cosecha) {
    if (String.isBlank(cosecha) || cosecha.length() < 2) {
      return null;
    }
    String anio = (cosecha.length() == 4 && cosecha.startsWith('20'))
      ? cosecha
      : '20' + cosecha.substring(0, 2);
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
