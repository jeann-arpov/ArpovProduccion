/**
 * Servicio de DÉBITO varietal (SE-345).
 *
 * A partir del peso neto de un camión (escáner varietal) y sus líneas de
 * variedad con porcentaje, crea las Tonelada__c negativas correspondientes
 * (Origen 'Escáner varietal', Signo -1, Etapa 'Cobrada') sobre la Cuenta
 * Granaria varietal del productor/cultivo/campaña.
 *
 * Reglas:
 *  - Configuración por Configuracion_Varietal__mdt: umbral de presencia,
 *    tecnología de la CG y biotecnología (sin valores hardcodeados).
 *  - Idempotente por camión: no vuelve a debitar variedades ya debitadas
 *    para el mismo Mov_BolsaTech__c.
 *  - Al final recalcula Saldo_Variedad__c de las sub-cuentas y Saldo_Cuenta__c.
 */
public with sharing class CuentaGranariaVarietalDebitService {
  private static final String ORIGEN_ESCANER = 'Escáner varietal';

  /**
   * Representa una línea del escáner: variedad y porcentaje varietal.
   */
  public class LineaVarietal {
    public Id variedadId;
    public Decimal porcentaje;
    public LineaVarietal(Id variedadId, Decimal porcentaje) {
      this.variedadId = variedadId;
      this.porcentaje = porcentaje;
    }
  }

  /**
   * Resultado del débito: exitoso, sinDebito (ninguna variedad supera umbral),
   * CG afectada, cantidad de débitos creados, total en toneladas y mensaje.
   */
  public class ResultadoDebito {
    public Boolean exitoso = false;
    public Boolean sinDebito = false;
    public Id cgId;
    public Integer debitosCreados = 0;
    public Decimal debitoTotalTn = 0;
    public String mensaje;
  }

  /**
   * Sobrecarga sin Mov_BolsaTech__c (delega en la versión completa con mbtId=null).
   */
  public static ResultadoDebito procesarDebito(
    Id productorId,
    Id campanaId,
    Id cultivoId,
    Decimal pesoNetoKg,
    List<LineaVarietal> lineas
  ) {
    return procesarDebito(
      productorId,
      campanaId,
      cultivoId,
      pesoNetoKg,
      lineas,
      null
    );
  }

  /**
   * Núcleo del débito: resuelve CG varietal, aplica umbral de presencia,
   * descarta variedades ya debitadas para el camión, crea Tonelada__c negativas
   * por variedad y recalcula Saldo_Variedad__c + Saldo_Cuenta__c.
   */
  public static ResultadoDebito procesarDebito(
    Id productorId,
    Id campanaId,
    Id cultivoId,
    Decimal pesoNetoKg,
    List<LineaVarietal> lineas,
    Id mbtId
  ) {
    ResultadoDebito resultado = new ResultadoDebito();

    if (
      productorId == null ||
      cultivoId == null ||
      lineas == null ||
      lineas.isEmpty()
    ) {
      resultado.mensaje = 'Parámetros insuficientes para el débito varietal.';
      return resultado;
    }

    Configuracion_Varietal__mdt cfg = obtenerConfiguracion();
    Decimal umbral = cfg != null ? cfg.Umbral_Presencia__c : null;
    String tecnologia = cfg != null ? cfg.Tecnologia__c : null;
    String biotecnologia = cfg != null ? cfg.Biotecnologia__c : null;

    if (umbral == null) {
      resultado.mensaje = 'Umbral de presencia no configurado (Configuracion_Varietal__mdt).';
      return resultado;
    }

    Cuenta_Granaria__c cg = obtenerCuentaGranaria(
      productorId,
      campanaId,
      cultivoId,
      tecnologia
    );
    if (cg == null) {
      resultado.mensaje = 'No se encontró Cuenta Granaria para el productor/campaña/cultivo.';
      return resultado;
    }
    resultado.cgId = cg.Id;

    Map<Id, String> biotecnologiaPorVariedad = obtenerBiotecnologiaPorVariedad(
      lineas,
      biotecnologia
    );

    Set<Id> variedadesYaDebitadas = new Set<Id>();
    if (mbtId != null) {
      for (Tonelada__c t : [
        SELECT Variedad__c
        FROM Tonelada__c
        WHERE Mov_BolsaTech__c = :mbtId AND Origen__c = :ORIGEN_ESCANER
      ]) {
        variedadesYaDebitadas.add(t.Variedad__c);
      }
    }

    Decimal pesoKg = pesoNetoKg != null ? pesoNetoKg : 0;
    Map<Id, Id> subCuentaPorVariedad = sincronizarSubCuentas(cg.Id, lineas);

    List<Tonelada__c> debitos = new List<Tonelada__c>();
    Set<Id> variedadesDebitadas = new Set<Id>();

    for (LineaVarietal linea : lineas) {
      if (
        linea.variedadId == null ||
        linea.porcentaje == null ||
        linea.porcentaje < umbral
      ) {
        continue;
      }
      if (variedadesYaDebitadas.contains(linea.variedadId)) {
        continue;
      }
      Decimal debitoTn = pesoKg / 1000 * (linea.porcentaje / 100);
      if (debitoTn <= 0) {
        continue;
      }
      debitos.add(
        new Tonelada__c(
          Productor__c = productorId,
          Campania__c = campanaId,
          Cultivo__c = cultivoId,
          Biotecnologia__c = biotecnologiaPorVariedad.containsKey(
              linea.variedadId
            )
            ? biotecnologiaPorVariedad.get(linea.variedadId)
            : biotecnologia,
          Variedad__c = linea.variedadId,
          Detalle_Variedad_CG__c = subCuentaPorVariedad.get(linea.variedadId),
          Cantidad__c = debitoTn,
          Signo__c = -1,
          Origen__c = ORIGEN_ESCANER,
          Etapa__c = 'Cobrada',
          Fecha_Inicio__c = Date.today(),
          No_asignar_campa_a__c = true,
          Cuenta_Granaria__c = cg.Id,
          Mov_BolsaTech__c = mbtId
        )
      );
      variedadesDebitadas.add(linea.variedadId);
      resultado.debitoTotalTn += debitoTn;
    }

    if (debitos.isEmpty()) {
      resultado.sinDebito = true;
      resultado.mensaje =
        'Ninguna variedad supera el umbral de ' +
        umbral +
        '%.';
      return resultado;
    }

    List<Database.SaveResult> saves = Database.insert(debitos, false);
    for (Database.SaveResult sr : saves) {
      if (sr.isSuccess()) {
        resultado.debitosCreados++;
      } else {
        for (Database.Error err : sr.getErrors()) {
          resultado.mensaje =
            (String.isBlank(resultado.mensaje)
              ? ''
              : resultado.mensaje + '; ') + err.getMessage();
        }
      }
    }

    recalcularSaldoVariedad(cg.Id, variedadesDebitadas);
    CuentaGranariaVarietalCreditoService.recalcularSaldoCuenta(cg.Id);
    resultado.exitoso = resultado.debitosCreados > 0;
    return resultado;
  }

  /**
   * Obtiene la Configuracion_Varietal__mdt (o null si no hay registros).
   */
  private static Configuracion_Varietal__mdt obtenerConfiguracion() {
    List<Configuracion_Varietal__mdt> cfgs = Configuracion_Varietal__mdt.getAll()
      .values();
    return cfgs.isEmpty() ? null : cfgs[0];
  }

  /**
   * Localiza la Cuenta Granaria varietal (según la tecnología configurada en
   * Configuracion_Varietal__mdt) para el productor/cultivo, priorizando la de la
   * campaña y, si no, la sin campaña.
   */
  private static Cuenta_Granaria__c obtenerCuentaGranaria(
    Id productorId,
    Id campanaId,
    Id cultivoId,
    String tecnologia
  ) {
    List<Cuenta_Granaria__c> cgs = [
      SELECT Id
      FROM Cuenta_Granaria__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Tecnologia__c = :tecnologia
        AND (Campania__c = :campanaId
        OR Campania__c = NULL)
      ORDER BY Campania__c DESC NULLS LAST
      LIMIT 1
    ];
    return cgs.isEmpty() ? null : cgs[0];
  }

  /**
   * Devuelve la biotecnología de cada variedad de las líneas, usando la
   * biotecnología configurada en Configuracion_Varietal__mdt como respaldo.
   */
  private static Map<Id, String> obtenerBiotecnologiaPorVariedad(
    List<LineaVarietal> lineas,
    String biotecnologiaDefault
  ) {
    Set<Id> ids = new Set<Id>();
    for (LineaVarietal linea : lineas) {
      if (linea.variedadId != null) {
        ids.add(linea.variedadId);
      }
    }
    Map<Id, String> resultado = new Map<Id, String>();
    if (ids.isEmpty()) {
      return resultado;
    }
    for (Variedad__c v : [
      SELECT Id, Biotecnologia__c
      FROM Variedad__c
      WHERE Id IN :ids
    ]) {
      resultado.put(
        v.Id,
        v.Biotecnologia__c != null ? v.Biotecnologia__c : biotecnologiaDefault
      );
    }
    return resultado;
  }

  /**
   * Asegura que exista una sub-cuenta Detalle_Variedad_CG__c por variedad
   * (upsert por Clave_Varietal__c) y devuelve el mapa variedad -> Id de sub-cuenta.
   */
  private static Map<Id, Id> sincronizarSubCuentas(
    Id cgId,
    List<LineaVarietal> lineas
  ) {
    List<Detalle_Variedad_CG__c> subCuentas = new List<Detalle_Variedad_CG__c>();
    for (LineaVarietal linea : lineas) {
      if (linea.variedadId == null) {
        continue;
      }
      subCuentas.add(
        new Detalle_Variedad_CG__c(
          Cuenta_Granaria__c = cgId,
          Variedad__c = linea.variedadId,
          Clave_Varietal__c = String.valueOf(cgId) +
            '|' +
            String.valueOf(linea.variedadId)
        )
      );
    }
    if (!subCuentas.isEmpty()) {
      Database.upsert(
        subCuentas,
        Detalle_Variedad_CG__c.Clave_Varietal__c,
        false
      );
    }

    Map<Id, Id> subCuentaPorVariedad = new Map<Id, Id>();
    for (Detalle_Variedad_CG__c sc : [
      SELECT Id, Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c = :cgId
    ]) {
      subCuentaPorVariedad.put(sc.Variedad__c, sc.Id);
    }
    return subCuentaPorVariedad;
  }

  /**
   * Recalcula el Saldo_Variedad__c de las sub-cuentas debitadas:
   * débito (Tonelada__c negativas de escáner) + crédito previo (Credito_Variedad__c).
   */
  private static void recalcularSaldoVariedad(
    Id cgId,
    Set<Id> variedadesDebitadas
  ) {
    if (variedadesDebitadas.isEmpty()) {
      return;
    }
    Map<Id, Id> subCuentaPorVariedad = new Map<Id, Id>();
    Map<Id, Decimal> creditoPorSubCuenta = new Map<Id, Decimal>();
    for (Detalle_Variedad_CG__c sc : [
      SELECT Id, Variedad__c, Credito_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c = :cgId AND Variedad__c IN :variedadesDebitadas
    ]) {
      subCuentaPorVariedad.put(sc.Variedad__c, sc.Id);
      creditoPorSubCuenta.put(
        sc.Id,
        sc.Credito_Variedad__c != null ? sc.Credito_Variedad__c : 0
      );
    }
    if (subCuentaPorVariedad.isEmpty()) {
      return;
    }

    Map<Id, Decimal> saldoPorSubCuenta = new Map<Id, Decimal>();
    for (Id scId : subCuentaPorVariedad.values()) {
      saldoPorSubCuenta.put(scId, 0);
    }

    for (AggregateResult ar : [
      SELECT Variedad__c variedad, SUM(Cantidad_con_Signo__c) total
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cgId
        AND Variedad__c IN :variedadesDebitadas
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c = :ORIGEN_ESCANER
        AND Signo__c = -1
      GROUP BY Variedad__c
    ]) {
      Id variedadId = (Id) ar.get('variedad');
      Decimal total = (Decimal) ar.get('total');
      if (subCuentaPorVariedad.containsKey(variedadId)) {
        saldoPorSubCuenta.put(
          subCuentaPorVariedad.get(variedadId),
          total != null ? total : 0
        );
      }
    }

    List<Detalle_Variedad_CG__c> actualizar = new List<Detalle_Variedad_CG__c>();
    for (Id scId : saldoPorSubCuenta.keySet()) {
      Decimal saldo =
        saldoPorSubCuenta.get(scId) +
        (creditoPorSubCuenta.containsKey(scId)
          ? creditoPorSubCuenta.get(scId)
          : 0);
      actualizar.add(
        new Detalle_Variedad_CG__c(Id = scId, Saldo_Variedad__c = saldo)
      );
    }
    if (!actualizar.isEmpty()) {
      Database.update(actualizar, false);
    }
  }
}
