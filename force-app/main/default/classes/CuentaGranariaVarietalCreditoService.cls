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

  public static final String TECNOLOGIA = 'RR1/RR2 - BT/Convencional';
  private static final String ORIGEN_ESCANER = 'Escáner varietal';
  private static final Set<String> ORIGENES_CREDITO = new Set<String>{
    'Compra SF',
    'Compra HT'
  };

  // Etapas que participan del crédito varietal.
  // Acreditan (Signo=1): Cobrada, Cancelada por NC, Acreditada, Reacreditada, Recibida.
  // Restan (Signo=-1): Cedida (cesión). Aplicada resta solo si es NC de una original (ver filtro).
  private static final Set<String> ETAPAS_VARIETALES = new Set<String>{
    'Cobrada',
    'Cancelada por NC',
    'Acreditada',
    'Reacreditada',
    'Recibida',
    'Cedida'
  };

  private static Boolean procesandoCreditos = false;

  // Recalcula y guarda el crédito y el saldo por variedad (crédito de HT + débito de CG).
  public static void recalcularCreditos(
    Id productorId,
    Id cultivoId,
    Id campanaId
  ) {
    if (procesandoCreditos) {
      return;
    }
    procesandoCreditos = true;
    try {
      recalcularCreditosInterno(productorId, cultivoId, campanaId);
    } finally {
      procesandoCreditos = false;
    }
  }

  private static void recalcularCreditosInterno(
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
    Map<Id, Decimal> debitoPorVariedad = calcularDebitoPorVariedad(cgId);

    Set<Id> variedades = new Set<Id>();
    variedades.addAll(creditoPorVariedad.keySet());
    variedades.addAll(debitoPorVariedad.keySet());

    Map<Id, Detalle_Variedad_CG__c> subCuentaPorVariedad = new Map<Id, Detalle_Variedad_CG__c>();
    for (Detalle_Variedad_CG__c sc : [
      SELECT Id, Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c = :cgId
    ]) {
      subCuentaPorVariedad.put(sc.Variedad__c, sc);
    }

    List<Detalle_Variedad_CG__c> aActualizar = new List<Detalle_Variedad_CG__c>();
    List<Detalle_Variedad_CG__c> aCrear = new List<Detalle_Variedad_CG__c>();

    for (Id vId : variedades) {
      Decimal credito = creditoPorVariedad.containsKey(vId)
        ? creditoPorVariedad.get(vId)
        : 0;
      Decimal debito = debitoPorVariedad.containsKey(vId)
        ? debitoPorVariedad.get(vId)
        : 0;
      Decimal saldo = credito + debito;

      if (subCuentaPorVariedad.containsKey(vId)) {
        aActualizar.add(
          new Detalle_Variedad_CG__c(
            Id = subCuentaPorVariedad.get(vId).Id,
            Credito_Variedad__c = credito,
            Saldo_Variedad__c = saldo
          )
        );
      } else {
        aCrear.add(
          new Detalle_Variedad_CG__c(
            Clave_Varietal__c = String.valueOf(cgId) +
              '|' +
              String.valueOf(vId),
            Cuenta_Granaria__c = cgId,
            Variedad__c = vId,
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

    List<Detalle_Variedad_CG__c> aResetear = new List<Detalle_Variedad_CG__c>();
    for (Id vId : subCuentaPorVariedad.keySet()) {
      if (!variedades.contains(vId)) {
        aResetear.add(
          new Detalle_Variedad_CG__c(
            Id = subCuentaPorVariedad.get(vId).Id,
            Credito_Variedad__c = 0,
            Saldo_Variedad__c = 0
          )
        );
      }
    }
    if (!aResetear.isEmpty()) {
      Database.update(aResetear, false);
    }

    vincularHtsAlDetalle(cgId, productorId, cultivoId, campanaId);

    recalcularSaldoCuenta(cgId);
  }

  private static void vincularHtsAlDetalle(
    Id cgId,
    Id productorId,
    Id cultivoId,
    Id campanaId
  ) {
    Map<Id, Id> detallePorVariedad = new Map<Id, Id>();
    for (Detalle_Variedad_CG__c sc : [
      SELECT Id, Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c = :cgId
    ]) {
      detallePorVariedad.put(sc.Variedad__c, sc.Id);
    }

    List<Hectareas_Tecnologicas__c> htsAActualizar = new List<Hectareas_Tecnologicas__c>();
    for (Hectareas_Tecnologicas__c ht : [
      SELECT Id, Variedad__c, Detalle_Variedad_CG__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c IN :ORIGENES_CREDITO
        AND Signo__c = 1
        AND Variedad__c != NULL
    ]) {
      Id detalleId = detallePorVariedad.get(ht.Variedad__c);
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
  }

  /**
   * Vincula a su Cuenta Granaria las toneladas de crédito varietal
   * (Compra HT / Compra SF) que ya están en etapa Cobrada.
   * No modifica la etapa: solo verifica que esté Cobrada para acreditar.
   */
  public static void acreditarToneladasCredito(List<Tonelada__c> toneladas) {
    Set<Id> cultivoIds = new Set<Id>();
    for (Tonelada__c tn : toneladas) {
      if (
        (tn.Origen__c == 'Compra HT' || tn.Origen__c == 'Compra SF') &&
        tn.Etapa__c == 'Cobrada' &&
        tn.Cultivo__c != null
      ) {
        cultivoIds.add(tn.Cultivo__c);
      }
    }
    if (cultivoIds.isEmpty()) {
      return;
    }

    Set<String> varietales = obtenerCultivosVarietales();
    Map<Id, String> cultivoNombrePorId = new Map<Id, String>();
    for (Cultivo__c c : [
      SELECT Id, Name
      FROM Cultivo__c
      WHERE Id IN :cultivoIds
    ]) {
      cultivoNombrePorId.put(c.Id, c.Name);
    }

    List<Tonelada__c> aActualizar = new List<Tonelada__c>();
    for (Tonelada__c tn : toneladas) {
      if (tn.Origen__c != 'Compra HT' && tn.Origen__c != 'Compra SF') {
        continue;
      }
      if (tn.Etapa__c != 'Cobrada') {
        continue;
      }
      if (tn.Cultivo__c == null || tn.Productor__c == null || tn.Campania__c == null) {
        continue;
      }
      String nombreCultivo = cultivoNombrePorId.get(tn.Cultivo__c);
      if (
        nombreCultivo == null ||
        !varietales.contains(nombreCultivo.toUpperCase())
      ) {
        continue;
      }

      Id cgId = obtenerCuentaGranariaId(
        tn.Productor__c,
        tn.Cultivo__c,
        tn.Campania__c
      );
      if (cgId != null) {
        aActualizar.add(
          new Tonelada__c(
            Id = tn.Id,
            Cuenta_Granaria__c = cgId
          )
        );
      }
    }

    if (!aActualizar.isEmpty()) {
      Database.update(aActualizar, false);
    }
  }

  public static void recalcularSaldoCuenta(Id cgId) {
    if (cgId == null) {
      return;
    }

    AggregateResult arDebito = [
      SELECT SUM(Cantidad_con_Signo__c) total
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cgId
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c = :ORIGEN_ESCANER
        AND Signo__c = -1
    ];
    Decimal debito = arDebito.get('total') != null
      ? (Decimal) arDebito.get('total')
      : 0;

    AggregateResult arCredito = [
      SELECT SUM(Credito_Variedad__c) total
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c = :cgId
    ];
    Decimal credito = arCredito.get('total') != null
      ? (Decimal) arCredito.get('total')
      : 0;

    update new Cuenta_Granaria__c(
      Id = cgId,
      Saldo_Cuenta__c = debito + credito
    );
  }

  private static Map<Id, Decimal> calcularDebitoPorVariedad(Id cgId) {
    Map<Id, Decimal> debitoPorVariedad = new Map<Id, Decimal>();
    for (AggregateResult ar : [
      SELECT Variedad__c v, SUM(Cantidad_con_Signo__c) total
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cgId
        AND Variedad__c != NULL
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c = :ORIGEN_ESCANER
        AND Signo__c = -1
      GROUP BY Variedad__c
    ]) {
      Id vId = (Id) ar.get('v');
      Decimal total = (Decimal) ar.get('total');
      if (total != null) {
        debitoPorVariedad.put(vId, total);
      }
    }
    return debitoPorVariedad;
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
        HT_Original__r.Variedad__c,
        HT_Original__r.Variedad__r.Name,
        Origen__c,
        Cantidad__c,
        Cantidad_con_Signo__c,
        Toneladas__c,
        Signo__c,
        Etapa__c,
        Fecha_de_la_Transaccion__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c IN :ORIGENES_CREDITO
        AND (
          Etapa__c IN :ETAPAS_VARIETALES
          OR (Etapa__c = 'Aplicada' AND HT_Original__r.Etapa__c = 'Cancelada por NC')
        )
        AND Variedad__c != NULL
      ORDER BY Fecha_de_la_Transaccion__c DESC, CreatedDate DESC
    ]) {
      Boolean esDevolucion = ht.Etapa__c == 'Aplicada' && ht.HT_Original__c != null;
      CreditoVariedad c = new CreditoVariedad();
      c.variedadId = esDevolucion ? ht.HT_Original__r.Variedad__c : ht.Variedad__c;
      c.variedadNombre = esDevolucion
        ? ht.HT_Original__r.Variedad__r.Name
        : ht.Variedad__r.Name;
      c.fecha = ht.Fecha_de_la_Transaccion__c != null
        ? String.valueOf(ht.Fecha_de_la_Transaccion__c)
        : '';
      c.origen = ht.Origen__c;
      c.ht = ht.Cantidad_con_Signo__c;
      c.tipo = null; // TODO: pendiente de definición de Epidata ("Semilla de Propia Producción")
      c.toneladas = ht.Toneladas__c * ht.Signo__c;
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
    for (Hectareas_Tecnologicas__c ht : [
      SELECT Variedad__c, HT_Original__r.Variedad__c, Toneladas__c, Signo__c, Etapa__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c IN :ORIGENES_CREDITO
        AND (
          Etapa__c IN :ETAPAS_VARIETALES
          OR (Etapa__c = 'Aplicada' AND HT_Original__r.Etapa__c = 'Cancelada por NC')
        )
        AND Variedad__c != NULL
    ]) {
      Id variedadId = ht.Etapa__c == 'Aplicada' && ht.HT_Original__c != null
        ? ht.HT_Original__r.Variedad__c
        : ht.Variedad__c;
      if (variedadId == null) {
        continue;
      }
      Decimal toneladas = ht.Toneladas__c != null && ht.Signo__c != null
        ? ht.Toneladas__c * ht.Signo__c
        : 0;
      Decimal previo = creditoPorVariedad.containsKey(variedadId)
        ? creditoPorVariedad.get(variedadId)
        : 0;
      creditoPorVariedad.put(variedadId, previo + toneladas);
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

  public static Set<String> obtenerCultivosVarietales() {
    Set<String> cultivos = new Set<String>();
    for (
      Configuracion_Varietal__mdt cfg : Configuracion_Varietal__mdt.getAll()
      .values()
    ) {
      if (String.isNotBlank(cfg.Cultivos_Varietales__c)) {
        for (String nombre : cfg.Cultivos_Varietales__c.split(',')) {
          if (String.isNotBlank(nombre)) {
            cultivos.add(nombre.trim().toUpperCase());
          }
        }
      }
    }
    return cultivos;
  }
}
