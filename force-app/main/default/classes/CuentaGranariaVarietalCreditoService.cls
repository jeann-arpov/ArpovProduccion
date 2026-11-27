/**
 * Servicio de CRÉDITO por variedad (SE-345).
 *
 * Centraliza el cálculo y persistencia del crédito varietal de una Cuenta
 * Granaria, que surge de las HT cobradas (Compra HT / Compra SF). Pendiente y
 * Cancelada por NC no acreditan ni aparecen en "HTs de Crédito" (SE-392 CP-01).
 *
 * El saldo por variedad se guarda en Detalle_Variedad_CG__c
 * (Saldo_Variedad__c = crédito + débito) y el Saldo_Cuenta__c de la CG
 * es la suma de Saldo_Variedad__c de sus sub-cuentas.
 */
public without sharing class CuentaGranariaVarietalCreditoService {
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
  private static final Set<String> ETAPAS_VARIETALES = new Set<String>{
    'Cobrada',
    'Acreditada',
    'Reacreditada',
    'Recibida',
    'Cedida'
  };

  private static Boolean procesandoCreditos = false;
  private static Boolean completandoCampania = false;
  private static Boolean jobCampaniaEncolado = false;
  private static Set<Id> htsPendientesCampania = new Set<Id>();

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
    for (Hectareas_Tecnologicas__c ht : [
      SELECT Id, Variedad__c, Detalle_Variedad_CG__c
      FROM Hectareas_Tecnologicas__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c = :campanaId
        AND Origen__c IN :ORIGENES_CREDITO
        AND Signo__c = 1
        AND Etapa__c IN :ETAPAS_VARIETALES
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

    Set<Id> subCuentaIds = new Set<Id>(detallePorVariedad.values());
    List<Hectareas_Tecnologicas__c> htsADesvincular = new List<Hectareas_Tecnologicas__c>();
    for (Hectareas_Tecnologicas__c ht : [
      SELECT Id
      FROM Hectareas_Tecnologicas__c
      WHERE
        Detalle_Variedad_CG__c IN :subCuentaIds
        AND Etapa__c NOT IN :ETAPAS_VARIETALES
    ]) {
      htsADesvincular.add(
        new Hectareas_Tecnologicas__c(Id = ht.Id, Detalle_Variedad_CG__c = null)
      );
    }
    if (!htsADesvincular.isEmpty()) {
      Database.update(htsADesvincular, false);
    }
  }

  /**
   * B-01: si el alta de la HT deja Campaña vacía (compra portal Futura),
   * usa la campaña de la CG varietal que ya tiene el productor.
   */
  public static void programarCompletarCampania(Set<Id> htIds) {
    if (htIds == null || htIds.isEmpty() || completandoCampania) {
      return;
    }
    htsPendientesCampania.addAll(htIds);
    if (jobCampaniaEncolado) {
      return;
    }
    jobCampaniaEncolado = true;
    System.enqueueJob(new CompletarCampaniaQueueable(htsPendientesCampania));
  }

  public class CompletarCampaniaQueueable implements Queueable {
    private Set<Id> htIds;
    public CompletarCampaniaQueueable(Set<Id> htIds) {
      this.htIds = htIds;
    }
    public void execute(QueueableContext ctx) {
      completarCampaniaYAcreditar(htIds);
    }
  }

  public static void completarCampaniaYAcreditar(Set<Id> htIds) {
    if (htIds == null || htIds.isEmpty() || completandoCampania) {
      return;
    }
    completandoCampania = true;
    try {
      List<Hectareas_Tecnologicas__c> hts = [
        SELECT
          Id,
          Productor__c,
          Cultivo__c,
          Campania__c,
          Origen__c,
          Etapa__c,
          TN_Id__c
        FROM Hectareas_Tecnologicas__c
        WHERE Id IN :htIds
      ];
      Set<String> clavesRecalc = new Set<String>();
      Map<Id, Id> campanaPorHt = new Map<Id, Id>();
      Map<String, Id> campanaPorClave = new Map<String, Id>();
      List<Hectareas_Tecnologicas__c> htsAActualizar = new List<Hectareas_Tecnologicas__c>();
      List<Tonelada__c> tnsAActualizar = new List<Tonelada__c>();
      Set<Id> tnIds = new Set<Id>();
      for (Hectareas_Tecnologicas__c ht : hts) {
        Id campanaId = ht.Campania__c;
        if (campanaId == null) {
          String claveCampana =
            String.valueOf(ht.Productor__c) +
            '|' +
            String.valueOf(ht.Cultivo__c);
          if (!campanaPorClave.containsKey(claveCampana)) {
            campanaPorClave.put(
              claveCampana,
              campanaVarietalExistente(ht.Productor__c, ht.Cultivo__c)
            );
          }
          campanaId = campanaPorClave.get(claveCampana);
        }
        if (campanaId == null) {
          continue;
        }
        campanaPorHt.put(ht.Id, campanaId);
        if (ht.Campania__c != campanaId) {
          htsAActualizar.add(
            new Hectareas_Tecnologicas__c(
              Id = ht.Id,
              Campania__c = campanaId,
              No_asignar_campa_a__c = true
            )
          );
        }
        if (ht.TN_Id__c != null) {
          tnsAActualizar.add(
            new Tonelada__c(
              Id = ht.TN_Id__c,
              Campania__c = campanaId,
              No_asignar_campa_a__c = true
            )
          );
          tnIds.add(ht.TN_Id__c);
        }
        clavesRecalc.add(
          String.valueOf(ht.Productor__c) +
            '|' +
            String.valueOf(ht.Cultivo__c) +
            '|' +
            String.valueOf(campanaId)
        );
      }
      if (!campanaPorHt.isEmpty()) {
        for (Tonelada__c tn : [
          SELECT Id, HT_Id__c
          FROM Tonelada__c
          WHERE HT_Id__c IN :campanaPorHt.keySet()
        ]) {
          if (tnIds.contains(tn.Id)) {
            continue;
          }
          Id campanaId = campanaPorHt.get(tn.HT_Id__c);
          if (campanaId == null) {
            continue;
          }
          tnsAActualizar.add(
            new Tonelada__c(
              Id = tn.Id,
              Campania__c = campanaId,
              No_asignar_campa_a__c = true
            )
          );
          tnIds.add(tn.Id);
        }
      }
      if (!htsAActualizar.isEmpty()) {
        update htsAActualizar;
      }
      if (!tnsAActualizar.isEmpty()) {
        update tnsAActualizar;
      }
      if (!tnIds.isEmpty()) {
        acreditarToneladasCredito(
          [
            SELECT
              Id,
              Origen__c,
              Etapa__c,
              Cultivo__c,
              Productor__c,
              Campania__c
            FROM Tonelada__c
            WHERE Id IN :tnIds
          ]
        );
      }
      for (String clave : clavesRecalc) {
        List<String> partes = clave.split('\\|');
        recalcularCreditos(partes[0], partes[1], partes[2]);
      }
    } finally {
      completandoCampania = false;
    }
  }

  @TestVisible
  private static Id campanaVarietalExistente(Id productorId, Id cultivoId) {
    if (productorId == null || cultivoId == null) {
      return null;
    }
    String tecnologia = obtenerTecnologiaVarietal();
    Id fallbackTec;
    Id fallback;
    for (Cuenta_Granaria__c cg : [
      SELECT Campania__c, Campania__r.Estado__c, Tecnologia__c
      FROM Cuenta_Granaria__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Campania__c != NULL
      ORDER BY Campania__r.Fecha_Inicio_SE__c DESC NULLS LAST
    ]) {
      Boolean mismaTec =
        tecnologia != null &&
        cg.Tecnologia__c == tecnologia;
      if (fallback == null) {
        fallback = cg.Campania__c;
      }
      if (mismaTec && fallbackTec == null) {
        fallbackTec = cg.Campania__c;
      }
      if (cg.Campania__r.Estado__c == 'Activa') {
        if (mismaTec) {
          return cg.Campania__c;
        }
        if (fallback == null) {
          fallback = cg.Campania__c;
        }
      }
    }
    return fallbackTec != null ? fallbackTec : fallback;
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
        ETAPAS_VARIETALES.contains(tn.Etapa__c) &&
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
      if (tn.Etapa__c == null || !ETAPAS_VARIETALES.contains(tn.Etapa__c)) {
        continue;
      }
      if (tn.Cultivo__c == null || tn.Productor__c == null) {
        continue;
      }
      String nombreCultivo = cultivoNombrePorId.get(tn.Cultivo__c);
      if (
        nombreCultivo == null ||
        !varietales.contains(nombreCultivo.toUpperCase())
      ) {
        continue;
      }

      Id campanaId = tn.Campania__c;
      if (campanaId == null) {
        campanaId = campanaVarietalExistente(tn.Productor__c, tn.Cultivo__c);
      }
      if (campanaId == null) {
        continue;
      }

      Id cgId = obtenerCuentaGranariaId(
        tn.Productor__c,
        tn.Cultivo__c,
        campanaId
      );
      if (cgId != null) {
        Tonelada__c actualizacion = new Tonelada__c(
          Id = tn.Id,
          Cuenta_Granaria__c = cgId
        );
        if (tn.Campania__c == null) {
          actualizacion.Campania__c = campanaId;
        }
        aActualizar.add(actualizacion);
      }
    }

    if (!aActualizar.isEmpty()) {
      Database.update(aActualizar, false);
    }
  }

  /**
   * Recalcula el Saldo_Cuenta__c de una CG varietal:
   * débito del escáner varietal (Tonelada__c negativas, Origen 'Escáner varietal')
   * + crédito total de sus sub-cuentas (Detalle_Variedad_CG__c.Credito_Variedad__c).
   */
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
   * Lista de créditos vigentes: compras cobradas, sin Pendiente,
   * Cancelada por NC ni NC Aplicada (SE-392 CP-01).
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
        AND Etapa__c IN :ETAPAS_VARIETALES
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
      c.tipo = null; // TODO: pendiente de definición de Epidata ("Semilla de Propia Producción")
      c.toneladas = ht.Toneladas__c * ht.Signo__c;
      creditos.add(c);
    }
    return creditos;
  }

  /**
   * Crédito por variedad: solo HT en Cobrada (o equivalentes). No suma
   * toneladas de la CG. Cancelada por NC y Aplicada no entran (SE-392 CP-01).
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
        AND Etapa__c IN :ETAPAS_VARIETALES
    ]) {
      Decimal signo = ht.Signo__c != null
        ? ht.Signo__c
        : (ht.Etapa__c == 'Cedida' ? -1 : 1);
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
