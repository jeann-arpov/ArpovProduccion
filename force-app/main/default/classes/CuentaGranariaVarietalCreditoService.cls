/**
 * Servicio de CRÉDITO por variedad (SE-345).
 *
 * Centraliza el cálculo y persistencia del crédito varietal de una Cuenta
 * Granaria, que surge de las HT cobradas (Compra HT / Compra SF). Pendiente y
 * Cancelada por NC no acreditan ni aparecen en "HTs de Crédito" (SE-345 / SE-410).
 *
 * El saldo por variedad se guarda en Detalle_Variedad_CG__c
 * (Saldo_Variedad__c = crédito + débito) y el Saldo_Cuenta__c de la CG
 * es la suma de Saldo_Variedad__c de sus sub-cuentas.
 */
public with sharing class CuentaGranariaVarietalCreditoService {
  /**
   * DTO que representa un movimiento de crédito para la lista del front
   * (fecha, origen, HT, tipo y toneladas).
   */
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

  private static final String ORIGEN_ESCANER = 'Escáner varietal';
  private static final Set<String> ORIGENES_CREDITO = new Set<String>{
    'Compra SF',
    'Compra HT'
  };

  // SE-392 CP-01: el crédito cuenta compras en Cobrada (y equivalentes).
  // Cancelada por NC y NC Aplicada no entran, ni aunque sus toneladas sigan en la CG.
  private static final Set<String> ETAPAS_ACREDITAN = new Set<String>{
    'Cobrada',
    'Acreditada',
    'Reacreditada',
    'Recibida'
  };
  private static final Set<String> ETAPAS_RESTAN = new Set<String>{ 'Cedida' };

  private static Boolean procesandoCreditos = false;

  /**
   * Orquesta el recálculo de crédito y saldo por variedad para una
   * productor/cultivo/campaña, con protección anti-recursión
   * (flag procesandoCreditos). Delega el trabajo en recalcularCreditosInterno.
   */
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

  /**
   * Recalcula el crédito de las CGs varietales recién creadas (B-01).
   */
  public static void recalcularPorCuentas(List<Cuenta_Granaria__c> cuentas) {
    if (cuentas == null || cuentas.isEmpty()) {
      return;
    }
    Set<Id> cgIds = new Set<Id>();
    for (Cuenta_Granaria__c cg : cuentas) {
      if (cg != null && cg.Id != null) {
        cgIds.add(cg.Id);
      }
    }
    if (cgIds.isEmpty()) {
      return;
    }

    Set<String> cultivosVarietales = obtenerCultivosVarietales();
    if (cultivosVarietales.isEmpty()) {
      return;
    }

    List<Cuenta_Granaria__c> cgs = [
      SELECT Id, Productor__c, Cultivo__c, Campania__c
      FROM Cuenta_Granaria__c
      WHERE Id IN :cgIds
    ];

    Set<Id> cultivoIds = new Set<Id>();
    for (Cuenta_Granaria__c cg : cgs) {
      if (cg.Cultivo__c != null) {
        cultivoIds.add(cg.Cultivo__c);
      }
    }
    if (cultivoIds.isEmpty()) {
      return;
    }

    Set<Id> cultivosVarietalesIds = new Set<Id>();
    for (Cultivo__c c : [
      SELECT Id
      FROM Cultivo__c
      WHERE Id IN :cultivoIds AND Name IN :cultivosVarietales
    ]) {
      cultivosVarietalesIds.add(c.Id);
    }
    if (cultivosVarietalesIds.isEmpty()) {
      return;
    }

    for (Cuenta_Granaria__c cg : cgs) {
      if (
        cg.Productor__c != null &&
        cg.Cultivo__c != null &&
        cg.Campania__c != null &&
        cultivosVarietalesIds.contains(cg.Cultivo__c)
      ) {
        recalcularCreditos(cg.Productor__c, cg.Cultivo__c, cg.Campania__c);
      }
    }
  }

  /**
   * True si la CG es de un cultivo varietal (trigo hoy). Evita que el recálculo
   * clásico de toneladas pise Saldo_Cuenta__c (B-03 / B-04).
   */
  public static Boolean esCuentaVarietal(Id cgId, String cultivoNombre) {
    if (cgId == null || String.isBlank(cultivoNombre)) {
      return false;
    }
    return obtenerCultivosVarietales().contains(cultivoNombre.toUpperCase());
  }

  /**
   * Lógica real del recálculo:
   *  - Obtiene la Cuenta Granaria varietal del productor/cultivo/campaña.
   *  - Calcula crédito por variedad (HT) y débito por variedad (escáner).
   *  - Crea/actualiza/resetea las sub-cuentas Detalle_Variedad_CG__c.
   *  - Vincula las HT de crédito a su Detalle (related list).
   *  - Recalcula el Saldo_Cuenta__c de la CG.
   */
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
    sincronizarToneladasDeCredito(productorId, cultivoId, campanaId);

    recalcularSaldoCuenta(cgId);

    cerrarExpedientesRegularizados(aActualizar, aResetear);
  }

  /**
   * Cierra (de forma dirigida y síncrona) los expedientes de las sub-cuentas
   * cuyo saldo quedó regularizado tras el recálculo del crédito, para que el
   * cierre se refleje al instante y no dependa del scheduler global.
   */
  private static void cerrarExpedientesRegularizados(
    List<Detalle_Variedad_CG__c> aActualizar,
    List<Detalle_Variedad_CG__c> aResetear
  ) {
    Set<Id> subCuentaIds = new Set<Id>();
    for (Detalle_Variedad_CG__c sc : aActualizar) {
      if (sc.Id != null) {
        subCuentaIds.add(sc.Id);
      }
    }
    for (Detalle_Variedad_CG__c sc : aResetear) {
      if (sc.Id != null) {
        subCuentaIds.add(sc.Id);
      }
    }
    CuentaGranariaVarietalExpedienteService.cerrarExpedientesRegularizadosPorSubCuentas(
      subCuentaIds
    );
  }

  /**
   * Vincula las HT de crédito (Compra HT / Compra SF, Signo=1, con variedad)
   * del productor/cultivo/campaña a su Detalle_Variedad_CG__c correspondiente,
   * para poblar la related list de compras de la sub-cuenta.
   */
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
    List<Hectareas_Tecnologicas__c> htsADesvincular = new List<Hectareas_Tecnologicas__c>();
    Set<Id> idsDetalle = new Set<Id>(detallePorVariedad.values());
    for (Hectareas_Tecnologicas__c ht : [
      SELECT Id, Variedad__c, Detalle_Variedad_CG__c, Etapa__c, Origen__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        (Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c IN :ORIGENES_CREDITO
        AND Variedad__c != NULL)
        OR Detalle_Variedad_CG__c IN :idsDetalle
    ]) {
      Boolean acredita = ORIGENES_CREDITO.contains(ht.Origen__c)
        && ht.Variedad__c != null
        && (ETAPAS_ACREDITAN.contains(ht.Etapa__c) ||
          ETAPAS_RESTAN.contains(ht.Etapa__c));
      Id detalleId = detallePorVariedad.get(ht.Variedad__c);
      if (acredita && detalleId != null) {
        if (ht.Detalle_Variedad_CG__c != detalleId) {
          htsAActualizar.add(
            new Hectareas_Tecnologicas__c(
              Id = ht.Id,
              Detalle_Variedad_CG__c = detalleId
            )
          );
        }
      } else if (ht.Detalle_Variedad_CG__c != null) {
        htsADesvincular.add(
          new Hectareas_Tecnologicas__c(Id = ht.Id, Detalle_Variedad_CG__c = null)
        );
      }
    }

    if (!htsAActualizar.isEmpty()) {
      Database.update(htsAActualizar, false);
    }
    if (!htsADesvincular.isEmpty()) {
      Database.update(htsADesvincular, false);
    }
  }

  /**
   * Copia la etapa de la HT a su Tonelada y asigna la CG si acredita (B-05 / B-03).
   */
  public static void sincronizarToneladasDeCredito(
    Id productorId,
    Id cultivoId,
    Id campanaId
  ) {
    if (productorId == null || cultivoId == null || campanaId == null) {
      return;
    }
    List<Hectareas_Tecnologicas__c> hts = [
      SELECT Id, Etapa__c, TN_Id__c, Origen__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c IN :ORIGENES_CREDITO
    ];
    if (hts.isEmpty()) {
      return;
    }

    Set<Id> htIds = new Set<Id>();
    Set<Id> tnIds = new Set<Id>();
    Map<Id, String> etapaPorHt = new Map<Id, String>();
    for (Hectareas_Tecnologicas__c ht : hts) {
      htIds.add(ht.Id);
      etapaPorHt.put(ht.Id, ht.Etapa__c);
      if (ht.TN_Id__c != null) {
        tnIds.add(ht.TN_Id__c);
      }
    }

    List<Tonelada__c> toneladas = [
      SELECT
        Id,
        HT_Id__c,
        Etapa__c,
        Origen__c,
        Cultivo__c,
        Productor__c,
        Campania__c,
        Cuenta_Granaria__c
      FROM Tonelada__c
      WHERE HT_Id__c IN :htIds OR Id IN :tnIds
    ];
    if (toneladas.isEmpty()) {
      return;
    }

    List<Tonelada__c> etapasAActualizar = new List<Tonelada__c>();
    for (Tonelada__c tn : toneladas) {
      String etapaHt = etapaPorHt.get(tn.HT_Id__c);
      if (etapaHt != null && tn.Etapa__c != etapaHt) {
        etapasAActualizar.add(new Tonelada__c(Id = tn.Id, Etapa__c = etapaHt));
        tn.Etapa__c = etapaHt;
      }
    }
    if (!etapasAActualizar.isEmpty()) {
      Database.update(etapasAActualizar, false);
    }

    acreditarToneladasCredito(toneladas);
  }

  /**
   * Vincula a su Cuenta Granaria las toneladas de crédito varietal
   * (Compra HT / Compra SF) que están en una etapa de crédito varietal.
   * No modifica la etapa: solo verifica que participe del crédito.
   */
  public static void acreditarToneladasCredito(List<Tonelada__c> toneladas) {
    Set<Id> cultivoIds = new Set<Id>();
    for (Tonelada__c tn : toneladas) {
      if (
        (tn.Origen__c == 'Compra HT' ||
        tn.Origen__c == 'Compra SF') &&
        tn.Etapa__c != null &&
        ETAPAS_ACREDITAN.contains(tn.Etapa__c) &&
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
      if (tn.Etapa__c == null || !ETAPAS_ACREDITAN.contains(tn.Etapa__c)) {
        continue;
      }
      if (
        tn.Cultivo__c == null ||
        tn.Productor__c == null ||
        tn.Campania__c == null
      ) {
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
        aActualizar.add(new Tonelada__c(Id = tn.Id, Cuenta_Granaria__c = cgId));
      }
    }

    if (!aActualizar.isEmpty()) {
      Database.update(aActualizar, false);
    }
  }

  /**
   * Recalcula el Saldo_Cuenta__c de una CG varietal como la suma de
   * Saldo_Variedad__c de sus detalles (SE-410: el saldo de la cuenta es
   * igual a la suma de sus variedades).
   */
  public static void recalcularSaldoCuenta(Id cgId) {
    if (cgId == null) {
      return;
    }

    AggregateResult arSaldo = [
      SELECT SUM(Saldo_Variedad__c) total
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c = :cgId
    ];
    Decimal saldo = arSaldo.get('total') != null
      ? (Decimal) arSaldo.get('total')
      : 0;

    update new Cuenta_Granaria__c(Id = cgId, Saldo_Cuenta__c = saldo);
  }

  /**
   * Suma el débito por variedad (Tonelada__c negativas de escáner varietal)
   * de una CG, agrupando por Variedad__c.
   */
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

  /**
   * Lista de créditos vigentes para el front: compras cobradas, sin Pendiente
   * ni Cancelada por NC (SE-392 CP-10).
   */
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
        AND Etapa__c IN :ETAPAS_ACREDITAN
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
      c.ht = ht.Cantidad_con_Signo__c;
      c.tipo = null;
      Decimal signo = ht.Signo__c != null ? ht.Signo__c : 1;
      c.toneladas = ht.Toneladas__c != null ? ht.Toneladas__c * signo : 0;
      creditos.add(c);
    }
    return creditos;
  }

  /**
   * Crédito por variedad: solo HT en Cobrada (o equivalentes). No suma
   * toneladas de la CG. Cancelada por NC y Aplicada no entran (SE-392 CP-01):
   * si no queda ninguna compra cobrada, el detalle queda 0 / 0 aunque una NC
   * no haya generado tonelada. NC parcial no está definida.
   */
  private static Map<Id, Decimal> calcularCreditoPorVariedad(
    Id productorId,
    Id cultivoId,
    Id campanaId
  ) {
    Map<Id, Decimal> creditoPorVariedad = new Map<Id, Decimal>();
    for (Hectareas_Tecnologicas__c ht : [
      SELECT Variedad__c, Toneladas__c, Signo__c, Etapa__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c IN :ORIGENES_CREDITO
        AND Variedad__c != NULL
        AND (Etapa__c IN :ETAPAS_ACREDITAN OR Etapa__c IN :ETAPAS_RESTAN)
    ]) {
      Decimal signo = ht.Signo__c != null
        ? ht.Signo__c
        : (ETAPAS_RESTAN.contains(ht.Etapa__c) ? -1 : 1);
      Decimal toneladas = ht.Toneladas__c != null ? ht.Toneladas__c * signo : 0;
      Decimal previo = creditoPorVariedad.containsKey(ht.Variedad__c)
        ? creditoPorVariedad.get(ht.Variedad__c)
        : 0;
      creditoPorVariedad.put(ht.Variedad__c, previo + toneladas);
    }
    return creditoPorVariedad;
  }

  /**
   * Localiza la Cuenta Granaria varietal (tecnología configurada en
   * Configuracion_Varietal__mdt) del productor/cultivo/campaña;
   * devuelve null si no existe.
   */
  private static Id obtenerCuentaGranariaId(
    Id productorId,
    Id cultivoId,
    Id campanaId
  ) {
    String tecnologia = obtenerTecnologiaVarietal();
    if (tecnologia == null) {
      return null;
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
    return cgs.isEmpty() ? null : cgs[0].Id;
  }

  /**
   * Devuelve el conjunto de nombres de cultivos varietales (en mayúsculas)
   * leídos del Custom Metadata Type Configuracion_Varietal__mdt
   * (campo Cultivos_Varietales__c separado por comas).
   */
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

  /**
   * Devuelve la tecnología varietal configurada en Configuracion_Varietal__mdt
   * (campo Tecnologia__c). Devuelve null si no hay configuración.
   */
  public static String obtenerTecnologiaVarietal() {
    for (
      Configuracion_Varietal__mdt cfg : Configuracion_Varietal__mdt.getAll()
        .values()
    ) {
      if (String.isNotBlank(cfg.Tecnologia__c)) {
        return cfg.Tecnologia__c;
      }
    }
    return null;
  }
}
