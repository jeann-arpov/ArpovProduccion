/**
 * Servicio de EXPEDIENTES DE NEGATIVOS varietales (SE-345).
 *
 * Abre expedientes para las sub-cuentas (Detalle_Variedad_CG__c) cuyo
 * Saldo_Variedad__c cae por debajo del umbral configurable
 * (Configuracion_Varietal__mdt.Umbral_Apertura_Expediente__c, default -4) y
 * cierra (Finalizado) aquellos cuyo saldo se regularizó (>= umbral).
 */
public with sharing class CuentaGranariaVarietalExpedienteService {
  /**
   * Resultado del procesamiento: expedientes creados, cerrados y errores.
   */
  public class ResultadoExpedientes {
    public Integer expedientesCreados = 0;
    public Integer expedientesCerrados = 0;
    public Integer errores = 0;
  }

  /**
   * Ejecuta cierre y apertura de expedientes en un solo paso.
   */
  public static ResultadoExpedientes procesarAperturasYCierres() {
    ResultadoExpedientes resultado = new ResultadoExpedientes();
    resultado.expedientesCerrados = cerrarExpedientesRegularizados();
    resultado.expedientesCreados = abrirExpedientesVarietales();
    return resultado;
  }

  /**
   * Abre expedientes de negativos para sub-cuentas con Saldo_Variedad__c < umbral
   * y sin expediente activo. El nombre sigue la forma EXP-CUIT-Campaña-Variedad.
   * Devuelve la cantidad creada.
   */
  public static Integer abrirExpedientesVarietales() {
    Set<Id> subCuentasConExpedienteActivo = obtenerSubCuentasConExpedienteActivo();
    Map<String, Decimal> umbralPorCultivo = obtenerUmbralPorCultivo();

    List<Expediente_de_Negativos__c> expedientes = new List<Expediente_de_Negativos__c>();
    for (Detalle_Variedad_CG__c sc : [
      SELECT
        Id,
        Variedad__c,
        Variedad__r.Name,
        Cuenta_Granaria__c,
        Saldo_Variedad__c,
        Cuenta_Granaria__r.Productor__c,
        Cuenta_Granaria__r.Campania__c,
        Cuenta_Granaria__r.Cultivo__r.Name,
        Cuenta_Granaria__r.Productor__r.N_CUIT__c,
        Cuenta_Granaria__r.Campania__r.Ano__c
      FROM Detalle_Variedad_CG__c
      WHERE Saldo_Variedad__c < 0
    ]) {
      if (subCuentasConExpedienteActivo.contains(sc.Id)) {
        continue;
      }
      Decimal umbral = obtenerUmbralParaCultivo(
        umbralPorCultivo,
        sc.Cuenta_Granaria__r.Cultivo__r.Name
      );
      if (umbral == null || sc.Saldo_Variedad__c >= umbral) {
        continue;
      }
      expedientes.add(
        new Expediente_de_Negativos__c(
          Name = construirNombre(sc),
          Detalle_Variedad_CG__c = sc.Id,
          Cuenta_Granaria__c = sc.Cuenta_Granaria__c,
          Variedad__c = sc.Variedad__c,
          Campania__c = sc.Cuenta_Granaria__r.Campania__c,
          Cuenta__c = sc.Cuenta_Granaria__r.Productor__c,
          Tipo_expendiente__c = 'EXP',
          Estado_de_la_Etapa__c = 'No empezado',
          Etapa__c = 'Llamar',
          Fecha_Cambio_Etapa__c = Date.today(),
          Saldo_Previo_al_Expediente__c = sc.Saldo_Variedad__c,
          Saldo_Expediente__c = sc.Saldo_Variedad__c,
          Gestionar__c = true
        )
      );
    }

    Integer creados = 0;
    if (!expedientes.isEmpty()) {
      List<Database.SaveResult> saves = Database.insert(expedientes, false);
      for (Database.SaveResult sr : saves) {
        if (sr.isSuccess()) {
          creados++;
        }
      }
    }
    return creados;
  }

  /**
   * Cierra (Finalizado) los expedientes varietales cuyo saldo actual ya es >= umbral.
   * Devuelve la cantidad cerrada.
   */
  public static Integer cerrarExpedientesRegularizados() {
    Map<String, Decimal> umbralPorCultivo = obtenerUmbralPorCultivo();
    List<Expediente_de_Negativos__c> aCerrar = new List<Expediente_de_Negativos__c>();
    for (Expediente_de_Negativos__c exp : [
      SELECT
        Id,
        Detalle_Variedad_CG__c,
        Detalle_Variedad_CG__r.Saldo_Variedad__c,
        Detalle_Variedad_CG__r.Cuenta_Granaria__r.Cultivo__r.Name
      FROM Expediente_de_Negativos__c
      WHERE
        Detalle_Variedad_CG__c != NULL
        AND Estado_de_la_Etapa__c NOT IN ('Finalizado', 'Vencido')
    ]) {
      Decimal saldo = exp.Detalle_Variedad_CG__r.Saldo_Variedad__c;
      Decimal umbral = obtenerUmbralParaCultivo(
        umbralPorCultivo,
        exp.Detalle_Variedad_CG__r.Cuenta_Granaria__r.Cultivo__r.Name
      );
      if (saldo != null && umbral != null && saldo >= umbral) {
        aCerrar.add(
          new Expediente_de_Negativos__c(
            Id = exp.Id,
            Estado_de_la_Etapa__c = 'Finalizado',
            Fecha_de_finalizacion__c = Date.today(),
            Saldo_del_Expediente_al_Cierre__c = saldo
          )
        );
      }
    }

    Integer cerrados = 0;
    if (!aCerrar.isEmpty()) {
      List<Database.SaveResult> saves = Database.update(aCerrar, false);
      for (Database.SaveResult sr : saves) {
        if (sr.isSuccess()) {
          cerrados++;
        }
      }
    }
    return cerrados;
  }

  /**
   * Sub-cuentas (Detalle_Variedad_CG__c) que ya tienen un expediente varietal
   * activo (no Finalizado ni Vencido).
   */
  private static Set<Id> obtenerSubCuentasConExpedienteActivo() {
    Set<Id> ids = new Set<Id>();
    for (Expediente_de_Negativos__c exp : [
      SELECT Detalle_Variedad_CG__c
      FROM Expediente_de_Negativos__c
      WHERE
        Detalle_Variedad_CG__c != NULL
        AND Estado_de_la_Etapa__c NOT IN ('Finalizado', 'Vencido')
    ]) {
      ids.add(exp.Detalle_Variedad_CG__c);
    }
    return ids;
  }

  private static Map<String, Decimal> obtenerUmbralPorCultivo() {
    Map<String, Decimal> umbralPorCultivo = new Map<String, Decimal>();
    for (
      Configuracion_Varietal__mdt cfg : Configuracion_Varietal__mdt.getAll()
        .values()
    ) {
      if (
        cfg.Umbral_Apertura_Expediente__c == null ||
        String.isBlank(cfg.Cultivos_Varietales__c)
      ) {
        continue;
      }
      for (String nombre : cfg.Cultivos_Varietales__c.split(',')) {
        String clave = nombre.trim().toUpperCase();
        if (String.isNotBlank(clave)) {
          umbralPorCultivo.put(clave, cfg.Umbral_Apertura_Expediente__c);
        }
      }
    }
    return umbralPorCultivo;
  }

  private static Decimal obtenerUmbralParaCultivo(
    Map<String, Decimal> umbralPorCultivo,
    String cultivoNombre
  ) {
    if (
      umbralPorCultivo == null ||
      umbralPorCultivo.isEmpty() ||
      String.isBlank(cultivoNombre)
    ) {
      return null;
    }
    return umbralPorCultivo.get(cultivoNombre.trim().toUpperCase());
  }

  /**
   * Arma el nombre del expediente: EXP-<CUIT>-<Campaña>-<Variedad>.
   */
  private static String construirNombre(Detalle_Variedad_CG__c sc) {
    String cuit = sc.Cuenta_Granaria__r.Productor__r.N_CUIT__c != null
      ? sc.Cuenta_Granaria__r.Productor__r.N_CUIT__c
      : String.valueOf(sc.Cuenta_Granaria__r.Productor__c);
    String campana = sc.Cuenta_Granaria__r.Campania__r.Ano__c != null
      ? sc.Cuenta_Granaria__r.Campania__r.Ano__c
      : '';
    String variedad = sc.Variedad__r.Name != null ? sc.Variedad__r.Name : '';
    return 'EXP-' + cuit + '-' + campana + '-' + variedad;
  }
}
