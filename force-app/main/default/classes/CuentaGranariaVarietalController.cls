public with sharing class CuentaGranariaVarietalController {
  public class VariedadResumen {
    @AuraEnabled
    public String semilleroId;
    @AuraEnabled
    public String semilleroNombre;
    @AuraEnabled
    public String idObtentor;
    @AuraEnabled
    public String variedadId;
    @AuraEnabled
    public String variedadNombre;
    @AuraEnabled
    public Decimal credito;
    @AuraEnabled
    public Decimal debito;
    @AuraEnabled
    public Decimal saldo;
  }

  @AuraEnabled(cacheable=true)
  public static List<VariedadResumen> getVarietalResumen(
    String cultivoId,
    String campanaId,
    String tecnologia
  ) {
    Id productorId = CrearCompraController.getAccount().Id;
    if (productorId == null) {
      return new List<VariedadResumen>();
    }

    Decimal umbral = obtenerUmbral();
    Map<Id, VariedadResumen> unionPorVariedad = new Map<Id, VariedadResumen>();

    // 1. Compra HT (crédito en toneladas disponibles)
    for (Hectareas_Tecnologicas__c ht : [
      SELECT
        Variedad__c,
        Variedad__r.Name,
        Variedad__r.Obtentor_Comercializa__c,
        Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c,
        Variedad__r.Obtentor_Comercializa__r.Id_Obtentor__c,
        Toneladas__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c = 'Compra HT'
        AND Variedad__c != NULL
    ]) {
      VariedadResumen r = unionPorVariedad.containsKey(ht.Variedad__c)
        ? unionPorVariedad.get(ht.Variedad__c)
        : nuevoResumen(
            ht.Variedad__c,
            ht.Variedad__r.Name,
            ht.Variedad__r.Obtentor_Comercializa__c,
            ht.Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c,
            ht.Variedad__r.Obtentor_Comercializa__r.Id_Obtentor__c
          );
      Decimal tn = ht.Toneladas__c != null ? ht.Toneladas__c : 0;
      r.credito += tn;
      r.saldo += tn;
      unionPorVariedad.put(ht.Variedad__c, r);
    }

    // 2. Sub-cuentas (entregas) — merge
    List<Cuenta_Granaria__c> cgs = [
      SELECT Id
      FROM Cuenta_Granaria__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Tecnologia__c = :tecnologia
      LIMIT 1
    ];
    if (!cgs.isEmpty()) {
      List<Detalle_Variedad_CG__c> detalles = [
        SELECT
          Variedad__c,
          Variedad__r.Name,
          Variedad__r.Obtentor_Comercializa__c,
          Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c,
          Variedad__r.Obtentor_Comercializa__r.Id_Obtentor__c,
          Saldo_Variedad__c
        FROM Detalle_Variedad_CG__c
        WHERE
          Cuenta_Granaria__c = :cgs[0].Id
          AND Porcentaje_Varietal__c >= :umbral
      ];

      if (!detalles.isEmpty()) {
        Set<Id> variedadIds = new Set<Id>();
        for (Detalle_Variedad_CG__c d : detalles) {
          variedadIds.add(d.Variedad__c);
        }

        Map<Id, Decimal> creditoPorVariedad = new Map<Id, Decimal>();
        Map<Id, Decimal> debitoPorVariedad = new Map<Id, Decimal>();
        for (Id vId : variedadIds) {
          creditoPorVariedad.put(vId, 0);
          debitoPorVariedad.put(vId, 0);
        }
        for (AggregateResult ar : [
          SELECT Variedad__c v, SUM(Cantidad_con_Signo__c) total
          FROM Tonelada__c
          WHERE
            Cuenta_Granaria__c = :cgs[0].Id
            AND Variedad__c IN :variedadIds
            AND Fecha_Inicio__c <= TODAY
            AND Etapa__c != 'Pendiente'
            AND Origen__c != 'Balance Anual'
          GROUP BY Variedad__c
        ]) {
          Id vId = (Id) ar.get('v');
          Decimal total = (Decimal) ar.get('total');
          if (total > 0) {
            creditoPorVariedad.put(vId, total);
          } else if (total < 0) {
            debitoPorVariedad.put(vId, total);
          }
        }

        for (Detalle_Variedad_CG__c d : detalles) {
          VariedadResumen r = unionPorVariedad.containsKey(d.Variedad__c)
            ? unionPorVariedad.get(d.Variedad__c)
            : nuevoResumen(
                d.Variedad__c,
                d.Variedad__r.Name,
                d.Variedad__r.Obtentor_Comercializa__c,
                d.Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c,
                d.Variedad__r.Obtentor_Comercializa__r.Id_Obtentor__c
              );
          r.credito += creditoPorVariedad.get(d.Variedad__c);
          r.debito = debitoPorVariedad.get(d.Variedad__c);
          r.saldo += d.Saldo_Variedad__c != null ? d.Saldo_Variedad__c : 0;
          unionPorVariedad.put(d.Variedad__c, r);
        }
      }
    }

    List<VariedadResumen> resultado = new List<VariedadResumen>(
      unionPorVariedad.values()
    );
    resultado.sort(new VariedadResumenComparator());
    return resultado;
  }

  private static VariedadResumen nuevoResumen(
    String variedadId,
    String variedadNombre,
    String semilleroId,
    String semilleroNombre,
    String idObtentor
  ) {
    VariedadResumen r = new VariedadResumen();
    r.variedadId = variedadId;
    r.variedadNombre = variedadNombre;
    r.semilleroId = semilleroId;
    r.semilleroNombre = semilleroNombre;
    r.idObtentor = idObtentor;
    r.credito = 0;
    r.debito = 0;
    r.saldo = 0;
    return r;
  }

  private class VariedadResumenComparator implements Comparator<VariedadResumen> {
    public Integer compare(VariedadResumen a, VariedadResumen b) {
      String marcaA = a.semilleroNombre != null ? a.semilleroNombre : '';
      String marcaB = b.semilleroNombre != null ? b.semilleroNombre : '';
      Integer c = marcaA.compareTo(marcaB);
      if (c != 0) {
        return c;
      }
      String varA = a.variedadNombre != null ? a.variedadNombre : '';
      String varB = b.variedadNombre != null ? b.variedadNombre : '';
      return varA.compareTo(varB);
    }
  }

  private static Decimal obtenerUmbral() {
    List<Configuracion_Varietal__mdt> cfgs = Configuracion_Varietal__mdt.getAll()
      .values();
    if (cfgs.isEmpty() || cfgs[0].Umbral_Presencia__c == null) {
      return 10;
    }
    return cfgs[0].Umbral_Presencia__c;
  }
}
