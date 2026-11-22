public with sharing class CuentaGranariaVarietalValidator {
  /**
   * Validación autocontenida para camiones varietales (trigo).
   * Hace todo lo del camión igual que Bolsatech (campos obligatorios, CUIT, Account),
   * PERO sin la deduplicación por Codigo_de_Muestra__c + CTG__c (no compatible con variedad),
   * y agrega la validación de las líneas varietales + MD-11.
   */
  /**
   * Valida una lista de camiones varietales en tres pasos:
   *  1. Campos obligatorios del camión + CUIT.
   *  2. Resolución de Account por CUIT (titular y destinatario).
   *  3. Resolución de Variedad__c por cultivar (catálogo Sembra Evolución) + MD-11
   *     (la suma de porcentajes no debe superar Suma_Maxima_MD11__c, default 100).
   * Deja cada camión en 'A procesar' (Resultado 'OK') o 'Con error' (mensajes).
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

    // ===== 3. Resolución de variedad por cultivar + MD-11 =====
    Set<Id> mbtIds = new Set<Id>();
    Map<Id, String> cultivoPorMbt = new Map<Id, String>();
    for (Movimiento_BolsaTech__c m : movimientos) {
      mbtIds.add(m.Id);
      cultivoPorMbt.put(
        m.Id,
        String.isNotBlank(m.Cultivo__c) ? m.Cultivo__c.trim().toUpperCase() : ''
      );
    }

    Map<Id, List<Detalle_Variedad_MBT__c>> lineasPorMbt = new Map<Id, List<Detalle_Variedad_MBT__c>>();
    Set<String> cultivares = new Set<String>();
    for (Detalle_Variedad_MBT__c linea : [
      SELECT Id, Movimiento_BolsaTech__c, Variedad__c, Cultivar__c, Porcentaje_Varietal__c
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
      if (String.isNotBlank(linea.Cultivar__c)) {
        cultivares.add(linea.Cultivar__c.trim().toUpperCase());
      }
    }

    // Resolución de Variedad__c por cultivar dentro del catálogo Sembra Evolución.
    // Clave: CULTIVO|CULTIVAR (mayúsculas), sin fallback: si no matchea, la línea queda con error.
    Map<String, Id> variedadPorClave = new Map<String, Id>();
    if (!cultivares.isEmpty()) {
      for (Variedad__c v : [
        SELECT Id, Cultivar_Inase__c, Cultivo__r.Name
        FROM Variedad__c
        WHERE Sembra_Evolucion__c = TRUE AND Cultivar_Inase__c IN :cultivares
      ]) {
        String clave =
          (v.Cultivo__r.Name != null ? v.Cultivo__r.Name.trim().toUpperCase() : '') +
          '|' +
          v.Cultivar_Inase__c.trim().toUpperCase();
        variedadPorClave.put(clave, v.Id);
      }
    }

    Configuracion_Varietal__mdt cfg = obtenerConfiguracion();
    Decimal sumaMaxima = cfg != null ? cfg.Suma_Maxima_MD11__c : null;

    List<Detalle_Variedad_MBT__c> lineasAActualizar = new List<Detalle_Variedad_MBT__c>();

    for (Movimiento_BolsaTech__c m : movimientos) {
      List<String> errors = errorsById.get(m.Id);
      String cultivoMbt = cultivoPorMbt.get(m.Id);

      List<Detalle_Variedad_MBT__c> lineas = lineasPorMbt.containsKey(m.Id)
        ? lineasPorMbt.get(m.Id)
        : new List<Detalle_Variedad_MBT__c>();

      if (lineas.isEmpty()) {
        errors.add('Sin líneas varietales');
      } else {
        Decimal suma = 0;
        for (Detalle_Variedad_MBT__c l : lineas) {
          if (String.isBlank(l.Cultivar__c)) {
            errors.add(
              'Cultivar vacío en línea varietal (muestra: ' +
              m.Codigo_de_Muestra__c +
              ')'
            );
          } else {
            String clave = cultivoMbt + '|' + l.Cultivar__c.trim().toUpperCase();
            Id variedadId = variedadPorClave.get(clave);
            if (variedadId != null) {
              l.Variedad__c = variedadId;
              lineasAActualizar.add(
                new Detalle_Variedad_MBT__c(Id = l.Id, Variedad__c = variedadId)
              );
            } else {
              errors.add(
                'Cultivar no encontrado en el catálogo: ' +
                l.Cultivar__c +
                ' (muestra: ' +
                m.Codigo_de_Muestra__c +
                ')'
              );
            }
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

        // MD-11: la suma de porcentajes no debe superar el tope configurado
        if (sumaMaxima != null && suma > sumaMaxima) {
          errors.add(
            'La suma de porcentajes supera el tope de ' + sumaMaxima + '% (MD-11)'
          );
        }
      }

      m.Estado__c = errors.isEmpty() ? 'A procesar' : 'Con error';
      m.Resultado__c = errors.isEmpty()
        ? 'OK'
        : String.join(errors, ',').abbreviate(255);
    }

    // Persiste la variedad resuelta en las líneas.
    if (!lineasAActualizar.isEmpty()) {
      Database.update(lineasAActualizar, false);
    }
  }

  /**
   * Validación puntual de un registro desde el front (@AuraEnabled).
   * Solo permite validar camiones en estado 'Creado' o 'Con error'.
   */
  @AuraEnabled
  public static void validate(Id recordId) {
    Movimiento_BolsaTech__c movimiento = [
      SELECT
        Id,
        Estado__c,
        Cultivo_Varietal__c,
        Codigo_de_Muestra__c,
        CUIT_Titular__c,
        Cuit_Destinatario__c,
        Peso_Neto__c,
        Fecha_de_Analisis__c,
        Cultivo__c,
        Tecnologia__c,
        CTG__c
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

  /**
   * Obtiene la Configuracion_Varietal__mdt (o null si no hay registros).
   */
  private static Configuracion_Varietal__mdt obtenerConfiguracion() {
    List<Configuracion_Varietal__mdt> cfgs = Configuracion_Varietal__mdt.getAll()
      .values();
    return cfgs.isEmpty() ? null : cfgs[0];
  }
}
