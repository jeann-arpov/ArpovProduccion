public with sharing class CuentaGranariaVarietalCreditoService {
  public class CreditoVariedad {
    @AuraEnabled
    public String variedadId;
    @AuraEnabled
    public String variedadNombre;
    @AuraEnabled
    public String fecha;
    @AuraEnabled
    public String origen;
    @AuraEnabled
    public Decimal ht;
    @AuraEnabled
    public String tipo;
    @AuraEnabled
    public Decimal toneladas;
  }

  private static final String TECNOLOGIA = 'RR1/RR2 - BT/Convencional';
  private static final Set<String> ORIGENES_CREDITO = new Set<String>{
    'Compra SF',
    'Compra HT'
  };

  // Recalcula y guarda el crédito (toneladas) por variedad desde las HT positivas.
  public static void recalcularCreditos(
    Id productorId,
    Id cultivoId,
    Id campanaId
  ) {
    Id cgId = obtenerCuentaGranariaId(productorId, cultivoId, campanaId);
    if (cgId == null) {
      return;
    }

    Map<Id, Decimal> creditoPorVariedad = calcularCreditoPorVariedad(
      productorId,
      cultivoId,
      campanaId
    );

    List<Detalle_Variedad_CG__c> aUpsert = new List<Detalle_Variedad_CG__c>();
    for (Id vId : creditoPorVariedad.keySet()) {
      aUpsert.add(
        new Detalle_Variedad_CG__c(
          Clave_Varietal__c = String.valueOf(cgId) + '|' + String.valueOf(vId),
          Cuenta_Granaria__c = cgId,
          Variedad__c = vId,
          Credito_Variedad__c = creditoPorVariedad.get(vId)
        )
      );
    }
    if (!aUpsert.isEmpty()) {
      Database.upsert(aUpsert, Detalle_Variedad_CG__c.Clave_Varietal__c, false);
    }
  }

  // Lista de créditos por variedad: fecha, origen, HT, tipo, toneladas.
  public static List<CreditoVariedad> obtenerCreditos(
    Id productorId,
    Id cultivoId,
    Id campanaId
  ) {
    List<CreditoVariedad> creditos = new List<CreditoVariedad>();
    for (Hectareas_Tecnologicas__c ht : [
      SELECT
        Variedad__c,
        Variedad__r.Name,
        Origen__c,
        Cantidad__c,
        Toneladas__c,
        Fecha_de_la_Transaccion__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c IN :ORIGENES_CREDITO
        AND Signo__c = 1
        AND Variedad__c != NULL
      ORDER BY Fecha_de_la_Transaccion__c DESC, CreatedDate DESC
    ]) {
      CreditoVariedad c = new CreditoVariedad();
      c.variedadId = ht.Variedad__c;
      c.variedadNombre = ht.Variedad__r.Name;
      c.fecha = ht.Fecha_de_la_Transaccion__c != null
        ? String.valueOf(ht.Fecha_de_la_Transaccion__c)
        : '';
      c.origen = ht.Origen__c;
      c.ht = ht.Cantidad__c;
      c.tipo = null; // TODO: pendiente de definición de Epidata ("Semilla de Propia Producción")
      c.toneladas = ht.Toneladas__c;
      creditos.add(c);
    }
    return creditos;
  }

  private static Map<Id, Decimal> calcularCreditoPorVariedad(
    Id productorId,
    Id cultivoId,
    Id campanaId
  ) {
    Map<Id, Decimal> creditoPorVariedad = new Map<Id, Decimal>();
    for (AggregateResult ar : [
      SELECT Variedad__c v, SUM(Toneladas__c) total
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c IN :ORIGENES_CREDITO
        AND Signo__c = 1
        AND Variedad__c != NULL
      GROUP BY Variedad__c
    ]) {
      Id vId = (Id) ar.get('v');
      Decimal total = (Decimal) ar.get('total');
      if (total != null) {
        creditoPorVariedad.put(vId, total);
      }
    }
    return creditoPorVariedad;
  }

  private static Id obtenerCuentaGranariaId(
    Id productorId,
    Id cultivoId,
    Id campanaId
  ) {
    List<Cuenta_Granaria__c> cgs = [
      SELECT Id
      FROM Cuenta_Granaria__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Tecnologia__c = :TECNOLOGIA
      LIMIT 1
    ];
    return cgs.isEmpty() ? null : cgs[0].Id;
  }
}
