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
    @AuraEnabled
    public String estado;
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

    Map<Id, VariedadResumen> porVariedad = new Map<Id, VariedadResumen>();

    // 1. Crédito (Compra HT): toneladas positivas ligadas a productor + cultivo + campaña
    for (Tonelada__c tn : [
      SELECT
        Variedad__c,
        Variedad__r.Name,
        Variedad__r.Obtentor_Comercializa__c,
        Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c,
        Variedad__r.Obtentor_Comercializa__r.Id_Obtentor__c,
        Cantidad_con_Signo__c
      FROM Tonelada__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c = 'Compra HT'
        AND Variedad__c != NULL
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
    ]) {
      agregarTonelada(porVariedad, tn);
    }

    // 2. Débito (entrega): toneladas ligadas a la Cuenta Granaria
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
      for (Tonelada__c tn : [
        SELECT
          Variedad__c,
          Variedad__r.Name,
          Variedad__r.Obtentor_Comercializa__c,
          Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c,
          Variedad__r.Obtentor_Comercializa__r.Id_Obtentor__c,
          Cantidad_con_Signo__c
        FROM Tonelada__c
        WHERE
          Cuenta_Granaria__c = :cgs[0].Id
          AND Variedad__c != NULL
          AND Fecha_Inicio__c <= TODAY
          AND Etapa__c != 'Pendiente'
          AND Origen__c != 'Balance Anual'
      ]) {
        agregarTonelada(porVariedad, tn);
      }
    }

    List<VariedadResumen> resultado = new List<VariedadResumen>(
      porVariedad.values()
    );
    for (VariedadResumen r : resultado) {
      r.estado = calcularEstado(r.credito, r.debito, r.saldo);
    }
    resultado.sort(new VariedadResumenComparator());
    return resultado;
  }

  private static String calcularEstado(
    Decimal credito,
    Decimal debito,
    Decimal saldo
  ) {
    if (credito > 0 && debito == 0) {
      return 'Sin entregas';
    }
    if (saldo < 0) {
      return 'Debe regularizar';
    }
    return 'En regla';
  }

  private static void agregarTonelada(
    Map<Id, VariedadResumen> porVariedad,
    Tonelada__c tn
  ) {
    VariedadResumen r = porVariedad.containsKey(tn.Variedad__c)
      ? porVariedad.get(tn.Variedad__c)
      : nuevoResumen(
          tn.Variedad__c,
          tn.Variedad__r.Name,
          tn.Variedad__r.Obtentor_Comercializa__c,
          tn.Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c,
          tn.Variedad__r.Obtentor_Comercializa__r.Id_Obtentor__c
        );
    Decimal qty = tn.Cantidad_con_Signo__c != null
      ? tn.Cantidad_con_Signo__c
      : 0;
    if (qty > 0) {
      r.credito += qty;
    } else if (qty < 0) {
      r.debito += qty;
    }
    r.saldo += qty;
    porVariedad.put(tn.Variedad__c, r);
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
}
