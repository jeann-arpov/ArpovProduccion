public with sharing class CuentaGranariaVarietalController {
  public class VariedadResumen {
    @AuraEnabled
    public String semilleroId;
    @AuraEnabled
    public String semilleroNombre;
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
    if (cgs.isEmpty()) {
      return new List<VariedadResumen>();
    }

    List<Detalle_Variedad_CG__c> detalles = [
      SELECT
        Id,
        Variedad__c,
        Variedad__r.Name,
        Variedad__r.Obtentor_Comercializa__c,
        Variedad__r.Obtentor_Comercializa__r.Name,
        Saldo_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c = :cgs[0].Id
      ORDER BY Variedad__r.Obtentor_Comercializa__r.Name, Variedad__r.Name
    ];
    if (detalles.isEmpty()) {
      return new List<VariedadResumen>();
    }

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

    List<VariedadResumen> resultado = new List<VariedadResumen>();
    for (Detalle_Variedad_CG__c d : detalles) {
      VariedadResumen r = new VariedadResumen();
      r.semilleroId = d.Variedad__r.Obtentor_Comercializa__c;
      r.semilleroNombre = d.Variedad__r.Obtentor_Comercializa__r.Name;
      r.variedadId = d.Variedad__c;
      r.variedadNombre = d.Variedad__r.Name;
      r.credito = creditoPorVariedad.get(d.Variedad__c);
      r.debito = debitoPorVariedad.get(d.Variedad__c);
      r.saldo = d.Saldo_Variedad__c != null ? d.Saldo_Variedad__c : 0;
      resultado.add(r);
    }
    return resultado;
  }
}
