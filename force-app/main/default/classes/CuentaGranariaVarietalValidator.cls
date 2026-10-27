public with sharing class CuentaGranariaVarietalValidator {
  /**
   * Valida las líneas varietales (Detalle_Variedad_MBT__c) de camiones varietales.
   * Es el equivalente a Bolsatech.validate() pero "por variedad":
   *  - cada línea debe tener Variedad y Porcentaje válido (0..100)
   *  - la suma de porcentajes del camión debe ser 100 (MD-11)
   * Marca el MBT con Estado='A procesar' (ok) o 'Con error' y detalla en Resultado__c.
   */
  public static void validate(List<Movimiento_BolsaTech__c> movimientos) {
    if (movimientos == null || movimientos.isEmpty()) {
      return;
    }

    Set<Id> mbtIds = new Set<Id>();
    for (Movimiento_BolsaTech__c m : movimientos) {
      mbtIds.add(m.Id);
    }

    Map<Id, List<Detalle_Variedad_MBT__c>> lineasPorMbt = new Map<Id, List<Detalle_Variedad_MBT__c>>();
    for (Detalle_Variedad_MBT__c linea : [
      SELECT
        Id,
        Movimiento_BolsaTech__c,
        Variedad__c,
        Porcentaje_Varietal__c,
        Kilos_Variedad__c
      FROM Detalle_Variedad_MBT__c
      WHERE Movimiento_BolsaTech__c IN :mbtIds
    ]) {
      if (!lineasPorMbt.containsKey(linea.Movimiento_BolsaTech__c)) {
        lineasPorMbt.put(
          linea.Movimiento_BolsaTech__c,
          new List<Detalle_Variedad_MBT__c>()
        );
      }
      lineasPorMbt.get(linea.Movimiento_BolsaTech__c).add(linea);
    }

    Configuracion_Varietal__mdt cfg = obtenerConfiguracion();
    Decimal tolerancia = (cfg != null &&
      cfg.Tolerancia_Suma_MD11__c != null)
      ? cfg.Tolerancia_Suma_MD11__c
      : 0;

    for (Movimiento_BolsaTech__c m : movimientos) {
      List<String> errors = new List<String>();

      List<Detalle_Variedad_MBT__c> lineas = lineasPorMbt.containsKey(m.Id)
        ? lineasPorMbt.get(m.Id)
        : new List<Detalle_Variedad_MBT__c>();

      if (lineas.isEmpty()) {
        errors.add('Sin líneas varietales');
      } else {
        Decimal suma = 0;
        for (Detalle_Variedad_MBT__c l : lineas) {
          if (l.Variedad__c == null) {
            errors.add('Variedad vacía en línea varietal');
          }
          if (l.Porcentaje_Varietal__c == null) {
            errors.add('Porcentaje varietal vacío');
          } else {
            if (
              l.Porcentaje_Varietal__c < 0 ||
              l.Porcentaje_Varietal__c > 100
            ) {
              errors.add('Porcentaje varietal fuera de rango');
            }
            suma += l.Porcentaje_Varietal__c;
          }
        }

        // MD-11: la suma de porcentajes del camión debe ser 100
        if (Math.abs(suma - 100) > tolerancia) {
          errors.add('La suma de porcentajes no es 100 (MD-11)');
        }
      }

      m.Estado__c = errors.isEmpty() ? 'A procesar' : 'Con error';
      m.Resultado__c = errors.isEmpty()
        ? 'OK'
        : String.join(errors, ',').abbreviate(255);
    }
  }

  @AuraEnabled
  public static void validate(Id recordId) {
    Movimiento_BolsaTech__c movimiento = [
      SELECT Id, Estado__c, Cultivo_Varietal__c
      FROM Movimiento_BolsaTech__c
      WHERE Id = :recordId
    ];

    if (
      movimiento.Estado__c != 'Creado' &&
      movimiento.Estado__c != 'Con error'
    ) {
      throw new AuraHandledException(
        'El movimiento no se puede validar en el estado actual.'
      );
    }

    validate(new List<Movimiento_BolsaTech__c>{ movimiento });
    update movimiento;
  }

  private static Configuracion_Varietal__mdt obtenerConfiguracion() {
    List<Configuracion_Varietal__mdt> cfgs = Configuracion_Varietal__mdt.getAll()
      .values();
    return cfgs.isEmpty() ? null : cfgs[0];
  }
}
