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

    // 1. Crédito (Semilla Fiscalizada + Compra HT): toneladas positivas de las HT
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
        AND Origen__c IN ('Compra SF', 'Compra HT')
        AND Signo__c = 1
        AND Variedad__c != NULL
    ]) {
      agregarCredito(porVariedad, ht);
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
    Decimal umbral = obtenerUmbralExpediente();
    for (VariedadResumen r : resultado) {
      r.estado = calcularEstado(r.debito, r.saldo, umbral);
    }
    resultado.sort(new VariedadResumenComparator());
    return resultado;
  }

  @AuraEnabled(cacheable=true)
  public static List<CuentaGranariaVarietalCreditoService.CreditoVariedad> getCreditosPorVariedad(
    String cultivoId,
    String campanaId
  ) {
    Id productorId = CrearCompraController.getAccount().Id;
    if (productorId == null) {
      return new List<CuentaGranariaVarietalCreditoService.CreditoVariedad>();
    }
    return CuentaGranariaVarietalCreditoService.obtenerCreditos(
      productorId,
      cultivoId,
      campanaId
    );
  }

  private static String calcularEstado(
    Decimal debito,
    Decimal saldo,
    Decimal umbral
  ) {
    if (saldo < umbral) {
      return 'Debe regularizar';
    }
    if (debito == 0) {
      return 'Sin entregas';
    }
    return 'En regla';
  }

  private static Decimal obtenerUmbralExpediente() {
    List<Configuracion_Varietal__mdt> cfgs = Configuracion_Varietal__mdt.getAll()
      .values();
    if (cfgs.isEmpty() || cfgs[0].Umbral_Apertura_Expediente__c == null) {
      return -4;
    }
    return cfgs[0].Umbral_Apertura_Expediente__c;
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

  private static void agregarCredito(
    Map<Id, VariedadResumen> porVariedad,
    Hectareas_Tecnologicas__c ht
  ) {
    VariedadResumen r = porVariedad.containsKey(ht.Variedad__c)
      ? porVariedad.get(ht.Variedad__c)
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
    porVariedad.put(ht.Variedad__c, r);
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
