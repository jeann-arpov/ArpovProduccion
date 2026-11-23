/**
 * Recrea la Tonelada__c de una HT restaurada desde la papelera (undelete).
 *
 * El flow "HT_Crear_Tonelada_Asociada" crea la Tonelada al CREAR la HT, pero
 * los record-triggered flows no tienen evento "undelete". Por eso, al restaurar
 * una HT, este Apex replica la lógica del flow para regenerar la Tonelada
 * (y su vínculo TN_Id__c), de modo que el Saldo_Cuenta__c vuelva a coincidir
 * con la suma de sus variedades (SE-410 / SE-392 CP-07).
 *
 * IMPORTANTE: mantiene la lógica espejada del flow
 * "HT_Crear_Tonelada_Asociada". Si el flow cambia, actualizar este Apex.
 */
public with sharing class HtToneladaRecreador {
  /**
   * Recrea la Tonelada de las HT indicadas (asumiendo que vienen de un
   * after undelete). Respeta el filtro del flow: Origen__c != 'PPH'.
   */
  public static void recrearToneladas(List<Hectareas_Tecnologicas__c> hts) {
    if (hts == null || hts.isEmpty()) {
      return;
    }

    Set<Id> htIds = new Set<Id>();
    for (Hectareas_Tecnologicas__c ht : hts) {
      if (ht.Origen__c != 'PPH') {
        htIds.add(ht.Id);
      }
    }
    if (htIds.isEmpty()) {
      return;
    }

    List<Hectareas_Tecnologicas__c> htsCompletas = [
      SELECT
        Id,
        Origen__c,
        Toneladas__c,
        Etapa__c,
        Signo__c,
        Tipo_de_Movimiento__c,
        N_CUIT__c,
        Biotecnologia__c,
        Fecha_Fin__c,
        Campania__c,
        Canal_de_Venta__c,
        Cultivo__c,
        Licencia__c,
        Parametro_Ensayos__c,
        Productor__c,
        Variedad__c,
        Linea_de_Compra_HT__r.Tipo_de_Compra__c,
        Cultivo__r.Fecha_Vencimiento_de_Tonelada__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id IN :htIds
    ];

    // Busca un expediente abierto por productor (mismo filtro que el flow).
    Map<Id, Id> expedientePorProductor = new Map<Id, Id>();
    Set<Id> productorIds = new Set<Id>();
    for (Hectareas_Tecnologicas__c ht : htsCompletas) {
      if (ht.Productor__c != null) {
        productorIds.add(ht.Productor__c);
      }
    }
    if (!productorIds.isEmpty()) {
      for (Expediente_de_Negativos__c exp : [
        SELECT Id, Cuenta__c
        FROM Expediente_de_Negativos__c
        WHERE
          Cuenta__c IN :productorIds
          AND Estado_de_la_Etapa__c != 'Finalizado'
        ORDER BY CreatedDate DESC
      ]) {
        if (!expedientePorProductor.containsKey(exp.Cuenta__c)) {
          expedientePorProductor.put(exp.Cuenta__c, exp.Id);
        }
      }
    }

    List<Tonelada__c> toneladas = new List<Tonelada__c>();
    List<Hectareas_Tecnologicas__c> htsAActualizar = new List<Hectareas_Tecnologicas__c>();

    for (Hectareas_Tecnologicas__c ht : htsCompletas) {
      Date forFechaFin = calcularFechaFin(ht);
      Id expedienteId = ht.Productor__c != null
        ? expedientePorProductor.get(ht.Productor__c)
        : null;

      toneladas.add(
        new Tonelada__c(
          Biotecnologia__c = ht.Biotecnologia__c,
          Campania__c = ht.Campania__c,
          Canal_de_Venta__c = ht.Canal_de_Venta__c,
          Cantidad__c = ht.Toneladas__c,
          Cultivo__c = ht.Cultivo__c,
          Etapa__c = ht.Etapa__c,
          Expediente_de_Negativos__c = expedienteId,
          Fecha_Fin_Original__c = forFechaFin,
          Fecha_Fin__c = forFechaFin,
          Fecha_Inicio__c = ht.Fecha_Fin__c,
          HT_Id__c = ht.Id,
          Licencia__c = ht.Licencia__c,
          N_CUIT__c = ht.N_CUIT__c,
          Origen__c = ht.Origen__c,
          Parametro_Ensayos__c = ht.Parametro_Ensayos__c,
          Productor__c = ht.Productor__c,
          Signo__c = ht.Signo__c,
          Tipo_de_Movimiento__c = ht.Tipo_de_Movimiento__c,
          Variedad__c = ht.Variedad__c
        )
      );
    }

    List<Database.SaveResult> saves = new List<Database.SaveResult>();
    if (!toneladas.isEmpty()) {
      saves = Database.insert(toneladas, false);
      for (Integer i = 0; i < saves.size(); i++) {
        if (saves[i].isSuccess()) {
          htsAActualizar.add(
            new Hectareas_Tecnologicas__c(
              Id = htsCompletas[i].Id,
              TN_Id__c = saves[i].getId()
            )
          );
        }
      }
    }

    if (!htsAActualizar.isEmpty()) {
      Database.update(htsAActualizar, false);
    }
  }

  /**
   * Replica la fórmula "forFechaFin" del flow HT_Crear_Tonelada_Asociada.
   */
  private static Date calcularFechaFin(Hectareas_Tecnologicas__c ht) {
    String forTipoCompra = ht.Origen__c == 'Compra HT' &&
      ht.Linea_de_Compra_HT__r.Tipo_de_Compra__c != null
      ? ht.Linea_de_Compra_HT__r.Tipo_de_Compra__c
      : '';
    Date forFechaVtoTN = ht.Cultivo__r.Fecha_Vencimiento_de_Tonelada__c;
    Date hoy = Date.today();

    if (ht.Origen__c == 'Compra HT' && forTipoCompra == 'Disponible') {
      if (
        forFechaVtoTN != null &&
        Date.newInstance(hoy.year(), 1, 1) <= hoy &&
        hoy < forFechaVtoTN
      ) {
        return Date.newInstance(
          hoy.year() + 2,
          forFechaVtoTN.month(),
          forFechaVtoTN.day()
        );
      } else if (forFechaVtoTN != null) {
        return Date.newInstance(
          hoy.year() + 3,
          forFechaVtoTN.month(),
          forFechaVtoTN.day()
        );
      }
      return hoy;
    } else if (
      (ht.Origen__c == 'Compra HT' && forTipoCompra == 'Futura') ||
      ht.Origen__c == 'Compra SF'
    ) {
      if (ht.Fecha_Fin__c != null) {
        return Date.newInstance(
          ht.Fecha_Fin__c.year() + 3,
          ht.Fecha_Fin__c.month(),
          ht.Fecha_Fin__c.day()
        );
      }
      return hoy;
    } else if (
      ht.Origen__c == 'Semilla Original' ||
      ht.Origen__c == 'Semilla Pre Básica'
    ) {
      if (ht.Fecha_Fin__c != null) {
        return Date.newInstance(
          ht.Fecha_Fin__c.year() + 1,
          ht.Fecha_Fin__c.month(),
          ht.Fecha_Fin__c.day()
        );
      }
      return hoy;
    }
    return hoy;
  }
}
