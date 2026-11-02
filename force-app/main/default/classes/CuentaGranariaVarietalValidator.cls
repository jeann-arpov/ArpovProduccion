public with sharing class CuentaGranariaVarietalValidator {
  /**
   * Validación autocontenida para camiones varietales (trigo).
   * Hace todo lo del camión igual que Bolsatech (campos obligatorios, CUIT, Account),
   * PERO sin la deduplicación por Codigo_de_Muestra__c + CTG__c (no compatible con variedad),
   * y agrega la validación de las líneas varietales + MD-11.
   */
  public static void validate(List<Movimiento_BolsaTech__c> movimientos) {
    if (movimientos == null || movimientos.isEmpty()) {
      return;
    }

    Map<String, Account> accountByCuit = new Map<String, Account>();
    Map<Id, List<String>> errorsById = new Map<Id, List<String>>();

    // ===== 1. Campos obligatorios del camión + CUIT (igual que soja) =====
    for (Movimiento_BolsaTech__c movimiento : movimientos) {
      List<String> errors = new List<String>();

      if (String.isBlank(movimiento.Fecha_de_Analisis__c)) {
        errors.add('Fecha de Análisis Vacia');
      }
      if (String.isBlank(movimiento.Cultivo__c)) {
        errors.add('Cultivo Vacio');
      }
      if (String.isBlank(movimiento.Tecnologia__c)) {
        errors.add('Tecnologia Vacia');
      }
      if (String.isBlank(movimiento.CTG__c)) {
        errors.add('Código de Trazabilidad de Granos Vacio');
      }
      if (String.isBlank(movimiento.Codigo_de_Muestra__c)) {
        errors.add('Código de Muestra Vacio');
      }
      if (movimiento.Peso_Neto__c == null) {
        errors.add('Peso Neto Vacio');
      }

      if (String.isNotBlank(movimiento.CUIT_Titular__c)) {
        accountByCuit.put(movimiento.CUIT_Titular__c, null);
      } else {
        errors.add('Cuit Titular Vacio');
      }

      if (String.isBlank(movimiento.Cuit_Destinatario__c)) {
        errors.add('Cuit Destinatario Vacio');
      } else {
        accountByCuit.put(movimiento.Cuit_Destinatario__c, null);
      }

      errorsById.put(movimiento.Id, errors);
    }

    // ===== 2. Resolución de Account por CUIT (igual que soja) =====
    for (Account acc : [
      SELECT Id, N_CUIT__c
      FROM Account
      WHERE
        RecordType.DeveloperName != 'Proveedor'
        AND N_CUIT__c IN :accountByCuit.keySet()
        AND ((N_CUIT__c IN ('30569723023', '30715468294')
        AND Type = 'Obtentor')
        OR ParentId = NULL)
    ]) {
      accountByCuit.put(acc.N_CUIT__c, acc);
    }

    for (Movimiento_BolsaTech__c movimiento : movimientos) {
      List<String> errors = errorsById.get(movimiento.Id);

      Account titular = accountByCuit.get(movimiento.CUIT_Titular__c);
      Account destinatario = accountByCuit.get(movimiento.Cuit_Destinatario__c);

      if (String.isNotBlank(movimiento.CUIT_Titular__c) && titular == null) {
        errors.add('El cuit titular no se encuentra en el sistema');
      }
      if (
        String.isNotBlank(movimiento.Cuit_Destinatario__c) &&
        destinatario == null
      ) {
        errors.add('El cuit destinatario no se encuentra en el sistema');
      }

      movimiento.Titular__c = titular != null ? titular.Id : null;
      movimiento.Destinatario__c = destinatario != null
        ? destinatario.Id
        : null;
    }

    // ===== 3. Líneas varietales + MD-11 (específico varietal) =====
    Set<Id> mbtIds = new Set<Id>();
    for (Movimiento_BolsaTech__c m : movimientos) {
      mbtIds.add(m.Id);
    }

    Map<Id, List<Detalle_Variedad_MBT__c>> lineasPorMbt = new Map<Id, List<Detalle_Variedad_MBT__c>>();
    for (Detalle_Variedad_MBT__c linea : [
      SELECT Id, Movimiento_BolsaTech__c, Variedad__c, Porcentaje_Varietal__c
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
      List<String> errors = errorsById.get(m.Id);

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
