public with sharing class CuentaGranariaVarietalExpedienteService {
  public class ResultadoExpedientes {
    public Integer expedientesCreados = 0;
    public Integer expedientesCerrados = 0;
    public Integer errores = 0;
  }

  public static ResultadoExpedientes procesarAperturasYCierres() {
    ResultadoExpedientes resultado = new ResultadoExpedientes();
    resultado.expedientesCerrados = cerrarExpedientesRegularizados();
    resultado.expedientesCreados = abrirExpedientesVarietales();
    return resultado;
  }

  public static Integer abrirExpedientesVarietales() {
    Set<Id> subCuentasConExpedienteActivo = obtenerSubCuentasConExpedienteActivo();

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
        Cuenta_Granaria__r.Productor__r.N_CUIT__c,
        Cuenta_Granaria__r.Campania__r.Ano__c
      FROM Detalle_Variedad_CG__c
      WHERE Saldo_Variedad__c < 0
    ]) {
      if (subCuentasConExpedienteActivo.contains(sc.Id)) {
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

  public static Integer cerrarExpedientesRegularizados() {
    List<Expediente_de_Negativos__c> aCerrar = new List<Expediente_de_Negativos__c>();
    for (Expediente_de_Negativos__c exp : [
      SELECT
        Id,
        Detalle_Variedad_CG__c,
        Detalle_Variedad_CG__r.Saldo_Variedad__c
      FROM Expediente_de_Negativos__c
      WHERE
        Detalle_Variedad_CG__c != NULL
        AND Estado_de_la_Etapa__c NOT IN ('Finalizado', 'Vencido')
    ]) {
      Decimal saldo = exp.Detalle_Variedad_CG__r.Saldo_Variedad__c;
      if (saldo != null && saldo >= 0) {
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
