public with sharing class CuentaGranariaVarietalDebitService {
  private static final String TECNOLOGIA_TRIGO = 'RR1/RR2 - BT/Convencional';
  private static final String BIOTECNOLOGIA_TRIGO = 'Convencional';
  private static final String ORIGEN_ESCANER = 'Escáner varietal';
  private static final Decimal UMBRAL_DEFAULT = 80;

  public class LineaVarietal {
    public Id variedadId;
    public Decimal porcentaje;
    public LineaVarietal(Id variedadId, Decimal porcentaje) {
      this.variedadId = variedadId;
      this.porcentaje = porcentaje;
    }
  }

  public class ResultadoDebito {
    public Boolean exitoso = false;
    public Boolean sinDebito = false;
    public Id cgId;
    public Integer debitosCreados = 0;
    public Decimal debitoTotalTn = 0;
    public String mensaje;
  }

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
    Decimal umbral = (cfg != null &&
      cfg.Umbral_Presencia__c != null)
      ? cfg.Umbral_Presencia__c
      : UMBRAL_DEFAULT;

    Cuenta_Granaria__c cg = obtenerCuentaGranaria(
      productorId,
      campanaId,
      cultivoId
    );
    if (cg == null) {
      resultado.mensaje = 'No se encontró Cuenta Granaria para el productor/campaña/cultivo.';
      return resultado;
    }
    resultado.cgId = cg.Id;

    Map<Id, String> biotecnologiaPorVariedad = obtenerBiotecnologiaPorVariedad(
      lineas
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
    Map<Id, Id> subCuentaPorVariedad = sincronizarSubCuentas(
      cg.Id,
      lineas,
      pesoKg
    );

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
            : BIOTECNOLOGIA_TRIGO,
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
    recalcularSaldoCuenta(cg.Id);
    resultado.exitoso = resultado.debitosCreados > 0;
    return resultado;
  }

  private static Configuracion_Varietal__mdt obtenerConfiguracion() {
    List<Configuracion_Varietal__mdt> cfgs = Configuracion_Varietal__mdt.getAll()
      .values();
    return cfgs.isEmpty() ? null : cfgs[0];
  }

  private static Cuenta_Granaria__c obtenerCuentaGranaria(
    Id productorId,
    Id campanaId,
    Id cultivoId
  ) {
    List<Cuenta_Granaria__c> cgs = [
      SELECT Id
      FROM Cuenta_Granaria__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Tecnologia__c = :TECNOLOGIA_TRIGO
        AND (Campania__c = :campanaId
        OR Campania__c = NULL)
      ORDER BY Campania__c DESC NULLS LAST
      LIMIT 1
    ];
    return cgs.isEmpty() ? null : cgs[0];
  }

  private static Map<Id, String> obtenerBiotecnologiaPorVariedad(
    List<LineaVarietal> lineas
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
        v.Biotecnologia__c != null ? v.Biotecnologia__c : BIOTECNOLOGIA_TRIGO
      );
    }
    return resultado;
  }

  private static Map<Id, Id> sincronizarSubCuentas(
    Id cgId,
    List<LineaVarietal> lineas,
    Decimal pesoKg
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
            String.valueOf(linea.variedadId),
          Porcentaje_Varietal__c = linea.porcentaje,
          Kilos_Variedad__c = pesoKg *
            (linea.porcentaje != null ? linea.porcentaje : 0) /
            100
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

  private static void recalcularSaldoVariedad(
    Id cgId,
    Set<Id> variedadesDebitadas
  ) {
    if (variedadesDebitadas.isEmpty()) {
      return;
    }
    Map<Id, Id> subCuentaPorVariedad = new Map<Id, Id>();
    for (Detalle_Variedad_CG__c sc : [
      SELECT Id, Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c = :cgId AND Variedad__c IN :variedadesDebitadas
    ]) {
      subCuentaPorVariedad.put(sc.Variedad__c, sc.Id);
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
        AND Origen__c != 'Balance Anual'
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
      actualizar.add(
        new Detalle_Variedad_CG__c(
          Id = scId,
          Saldo_Variedad__c = saldoPorSubCuenta.get(scId)
        )
      );
    }
    if (!actualizar.isEmpty()) {
      Database.update(actualizar, false);
    }
  }

  private static void recalcularSaldoCuenta(Id cgId) {
    AggregateResult ar = [
      SELECT SUM(Cantidad_con_Signo__c) total
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cgId
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c != 'Balance Anual'
    ];
    Decimal total = ar.get('total') != null ? (Decimal) ar.get('total') : 0;
    update new Cuenta_Granaria__c(Id = cgId, Saldo_Cuenta__c = total);
  }
}
