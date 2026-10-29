public with sharing class CuentaGranariaToneladasController {
  public class ToneladaWrapper {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String nombre;
    @AuraEnabled
    public String origen;
    @AuraEnabled
    public Decimal cantidad;
    @AuraEnabled
    public Boolean esPositivo;
    @AuraEnabled
    public String fechaInicio;
    @AuraEnabled
    public String fechaCreacion;
    @AuraEnabled
    public String etapa;
    @AuraEnabled
    public String variedad;
    @AuraEnabled
    public String detalleVariedadCGId;
  }

  public class ConsumoResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public Decimal cantidadConsumida;
    @AuraEnabled
    public String message;
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getToneladas(Id cuentaGranariaId) {
    List<ToneladaWrapper> toneladas = new List<ToneladaWrapper>();
    Decimal total = 0;
    Decimal totalPositivo = 0;
    Decimal totalNegativo = 0;

    Cuenta_Granaria__c cuenta = [
      SELECT
        Id,
        Name,
        Productor__c,
        Productor__r.Name,
        Campania__c,
        Campania__r.Name,
        Cultivo__c,
        Cultivo__r.Name,
        Tecnologia__c,
        Saldo_Cuenta__c,
        Es_Carga_Manual__c
      FROM Cuenta_Granaria__c
      WHERE Id = :cuentaGranariaId
      LIMIT 1
    ];

    for (Tonelada__c tn : [
      SELECT
        Id,
        Name,
        Origen__c,
        Cantidad_con_Signo__c,
        Fecha_Inicio__c,
        Etapa__c,
        CreatedDate
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cuentaGranariaId
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c != 'Balance Anual'
      ORDER BY CreatedDate DESC
    ]) {
      ToneladaWrapper wrapper = new ToneladaWrapper();
      wrapper.id = tn.Id;
      wrapper.nombre = tn.Name != null ? tn.Name : 'Sin nombre';
      wrapper.origen = tn.Origen__c;
      wrapper.cantidad = tn.Cantidad_con_Signo__c != null
        ? tn.Cantidad_con_Signo__c
        : 0;
      wrapper.esPositivo = wrapper.cantidad >= 0;
      wrapper.fechaInicio = tn.Fecha_Inicio__c != null
        ? String.valueOf(tn.Fecha_Inicio__c)
        : '';
      wrapper.fechaCreacion = tn.CreatedDate != null
        ? tn.CreatedDate.format('dd/MM/yyyy')
        : '';
      wrapper.etapa = tn.Etapa__c;

      toneladas.add(wrapper);
      total += wrapper.cantidad;

      if (wrapper.esPositivo) {
        totalPositivo += wrapper.cantidad;
      } else {
        totalNegativo += wrapper.cantidad;
      }
    }

    Decimal saldoCompraHT = 0;
    Id compraHTId = null;
    List<Map<String, Object>> cuentasRelacionadas = new List<Map<String, Object>>();

    if (cuenta.Campania__c != null) {
      List<Cuenta_Granaria__c> cuentasHT = [
        SELECT Id, Saldo_Cuenta__c
        FROM Cuenta_Granaria__c
        WHERE
          Productor__c = :cuenta.Productor__c
          AND Cultivo__c = :cuenta.Cultivo__c
          AND Tecnologia__c = :cuenta.Tecnologia__c
          AND Campania__c = NULL
        LIMIT 1
      ];
      if (!cuentasHT.isEmpty()) {
        saldoCompraHT = cuentasHT[0].Saldo_Cuenta__c != null
          ? cuentasHT[0].Saldo_Cuenta__c
          : 0;
        compraHTId = cuentasHT[0].Id;
      }
    } else {
      Integer anio = Date.today().year();
      Set<String> anosPermitidos = new Set<String>();
      for (Integer i = 0; i < 5; i++) {
        anosPermitidos.add(String.valueOf(anio - i));
      }
      for (Cuenta_Granaria__c cg : [
        SELECT
          Id,
          Campania__r.Name,
          Campania__r.Ano__c,
          Tecnologia__c,
          Saldo_Cuenta__c
        FROM Cuenta_Granaria__c
        WHERE
          Productor__c = :cuenta.Productor__c
          AND Cultivo__c = :cuenta.Cultivo__c
          AND Campania__c != NULL
          AND Campania__r.Ano__c IN :anosPermitidos
        ORDER BY Campania__r.Ano__c DESC, Tecnologia__c ASC
      ]) {
        cuentasRelacionadas.add(
          new Map<String, Object>{
            'id' => cg.Id,
            'campania' => cg.Campania__r.Name,
            'saldo' => cg.Saldo_Cuenta__c != null ? cg.Saldo_Cuenta__c : 0
          }
        );
      }
    }

    Boolean puedeGenerarConsumo = evaluarPuedeGenerarConsumo(
      cuenta,
      saldoCompraHT
    );

    return new Map<String, Object>{
      'toneladas' => toneladas,
      'total' => total,
      'totalPositivo' => totalPositivo,
      'totalNegativo' => totalNegativo,
      'cuenta' => new Map<String, Object>{
        'nombre' => cuenta.Name,
        'productor' => cuenta.Productor__r.Name,
        'campania' => cuenta.Campania__c != null
          ? cuenta.Campania__r.Name
          : null,
        'cultivo' => cuenta.Cultivo__r.Name,
        'tecnologia' => cuenta.Tecnologia__c,
        'saldo' => cuenta.Saldo_Cuenta__c,
        'esCompraHT' => cuenta.Campania__c == null,
        'esCargaManual' => cuenta.Es_Carga_Manual__c == true,
        'puedeGenerarConsumo' => puedeGenerarConsumo,
        'saldoCompraHT' => saldoCompraHT,
        'compraHTId' => compraHTId,
        'cuentasRelacionadas' => cuentasRelacionadas
      }
    };
  }

  @AuraEnabled
  public static ConsumoResult generarConsumoHT(Id cuentaGranariaId) {
    ConsumoResult result = new ConsumoResult();
    result.success = false;
    result.cantidadConsumida = 0;

    Cuenta_Granaria__c cgRegular = [
      SELECT
        Id,
        Productor__c,
        Campania__c,
        Cultivo__c,
        Tecnologia__c,
        Saldo_Cuenta__c,
        Es_Carga_Manual__c
      FROM Cuenta_Granaria__c
      WHERE Id = :cuentaGranariaId
      LIMIT 1
    ];

    List<Cuenta_Granaria__c> cuentasHT = [
      SELECT Id, Saldo_Cuenta__c
      FROM Cuenta_Granaria__c
      WHERE
        Productor__c = :cgRegular.Productor__c
        AND Cultivo__c = :cgRegular.Cultivo__c
        AND Tecnologia__c = :cgRegular.Tecnologia__c
        AND Campania__c = NULL
      LIMIT 1
    ];

    Decimal saldoHT = cuentasHT.isEmpty() ||
      cuentasHT[0].Saldo_Cuenta__c == null
      ? 0
      : cuentasHT[0].Saldo_Cuenta__c;

    if (!evaluarPuedeGenerarConsumo(cgRegular, saldoHT)) {
      throw new AuraHandledException(
        'No se puede generar consumo: la cuenta debe ser carga manual, tener saldo negativo y HT disponible positivo.'
      );
    }

    Id htCuentaId = cuentasHT[0].Id;
    String biotecnologia = obtenerBiotecnologiaRepresentativa(
      cgRegular.Tecnologia__c
    );
    Decimal deficit = Math.abs(cgRegular.Saldo_Cuenta__c);

    List<Tonelada__c> lotesHT = consultarLotesCompraHT(
      cgRegular.Productor__c,
      cgRegular.Cultivo__c,
      cgRegular.Tecnologia__c,
      htCuentaId
    );
    Map<Id, Decimal> remainingPorLote = calcularRemainingPorLote(lotesHT);

    Decimal htDisponibleLotes = 0;
    for (Decimal rem : remainingPorLote.values()) {
      htDisponibleLotes += rem;
    }
    Decimal consumoTotal = Math.min(
      deficit,
      Math.min(saldoHT, htDisponibleLotes)
    );

    if (consumoTotal <= 0) {
      throw new AuraHandledException(Label.DUP_Sin_Toneladas_HT);
    }

    List<Tonelada__c> nuevasConsumiciones = new List<Tonelada__c>();
    Decimal pendiente = consumoTotal;

    for (Tonelada__c lote : lotesHT) {
      if (pendiente <= 0) {
        break;
      }
      if (!remainingPorLote.containsKey(lote.Id)) {
        continue;
      }
      Decimal disponible = remainingPorLote.get(lote.Id);
      if (disponible <= 0) {
        continue;
      }

      Decimal consumo = Math.min(pendiente, disponible);

      Tonelada__c consumoPositivo = new Tonelada__c();
      consumoPositivo.Productor__c = cgRegular.Productor__c;
      consumoPositivo.Campania__c = cgRegular.Campania__c;
      consumoPositivo.Cultivo__c = cgRegular.Cultivo__c;
      consumoPositivo.Biotecnologia__c = biotecnologia;
      consumoPositivo.Cantidad__c = consumo;
      consumoPositivo.Signo__c = 1;
      consumoPositivo.No_asignar_campa_a__c = true;
      consumoPositivo.Fecha_Inicio__c = Date.today();
      consumoPositivo.Fecha_Fin__c = lote.Fecha_Fin__c;
      consumoPositivo.Origen__c = 'Consumo';
      consumoPositivo.Etapa__c = 'Cobrada';
      consumoPositivo.Tonelada_Compra_HT__c = lote.Id;
      consumoPositivo.N_CUIT__c = lote.N_CUIT__c;
      consumoPositivo.Cuenta_Granaria__c = cgRegular.Id;
      nuevasConsumiciones.add(consumoPositivo);

      Tonelada__c consumoNegativo = new Tonelada__c();
      consumoNegativo.Productor__c = cgRegular.Productor__c;
      consumoNegativo.Cultivo__c = cgRegular.Cultivo__c;
      consumoNegativo.Biotecnologia__c = biotecnologia;
      consumoNegativo.Cantidad__c = consumo;
      consumoNegativo.Signo__c = -1;
      consumoNegativo.No_asignar_campa_a__c = true;
      consumoNegativo.Fecha_Inicio__c = Date.today();
      consumoNegativo.Fecha_Fin__c = lote.Fecha_Fin__c;
      consumoNegativo.Origen__c = 'Consumo';
      consumoNegativo.Etapa__c = 'Cobrada';
      consumoNegativo.Tonelada_Compra_HT__c = lote.Id;
      consumoNegativo.N_CUIT__c = lote.N_CUIT__c;
      consumoNegativo.Cuenta_Granaria__c = htCuentaId;
      nuevasConsumiciones.add(consumoNegativo);

      pendiente -= consumo;
    }

    if (nuevasConsumiciones.isEmpty()) {
      throw new AuraHandledException(Label.DUP_Error_Crear_Toneladas);
    }

    insert nuevasConsumiciones;

    Decimal cantidadConsumida = consumoTotal - pendiente;
    cgRegular.Saldo_Cuenta__c = cgRegular.Saldo_Cuenta__c + cantidadConsumida;
    Cuenta_Granaria__c cgHT = new Cuenta_Granaria__c(
      Id = htCuentaId,
      Saldo_Cuenta__c = calcularSaldoDesdeToneladas(htCuentaId)
    );
    update new List<Cuenta_Granaria__c>{ cgRegular, cgHT };

    result.success = true;
    result.cantidadConsumida = cantidadConsumida;
    result.message =
      'Consumo generado: ' +
      result.cantidadConsumida.setScale(2) +
      ' tn';
    return result;
  }

  private static Boolean evaluarPuedeGenerarConsumo(
    Cuenta_Granaria__c cuenta,
    Decimal saldoCompraHT
  ) {
    return cuenta.Es_Carga_Manual__c == true &&
      cuenta.Campania__c != null &&
      cuenta.Saldo_Cuenta__c != null &&
      cuenta.Saldo_Cuenta__c < 0 &&
      saldoCompraHT != null &&
      saldoCompraHT > 0;
  }

  private static String obtenerBiotecnologiaRepresentativa(
    String tecnologiaAgrupada
  ) {
    if (tecnologiaAgrupada == 'Enlist E3/Conkesta E3') {
      return 'Enlist E3';
    }
    if (tecnologiaAgrupada == 'RR1/RR2 - BT/Convencional') {
      return 'RR1';
    }
    return tecnologiaAgrupada;
  }

  private static String mapearTecnologia(
    String biotecnologia,
    String cultivoNombre
  ) {
    if (biotecnologia == 'Enlist E3' || biotecnologia == 'Conkesta E3') {
      return 'Enlist E3/Conkesta E3';
    }
    if (biotecnologia == 'RR1' || biotecnologia == 'RR2 - BT') {
      return 'RR1/RR2 - BT/Convencional';
    }
    if (biotecnologia == 'Convencional') {
      return 'RR1/RR2 - BT/Convencional';
    }
    return biotecnologia;
  }

  private static Set<String> obtenerBiotecnologiasDelGrupo(
    String tecnologiaAgrupada
  ) {
    if (tecnologiaAgrupada == 'Enlist E3/Conkesta E3') {
      return new Set<String>{ 'Enlist E3', 'Conkesta E3' };
    }
    if (tecnologiaAgrupada == 'RR1/RR2 - BT/Convencional') {
      return new Set<String>{ 'RR1', 'RR2 - BT', 'Convencional' };
    }
    return new Set<String>{ tecnologiaAgrupada };
  }

  private static List<Tonelada__c> consultarLotesCompraHT(
    Id productorId,
    Id cultivoId,
    String tecnologiaAgrupada,
    Id htCuentaId
  ) {
    Set<String> biotechs = obtenerBiotecnologiasDelGrupo(tecnologiaAgrupada);
    List<Tonelada__c> lotesCampania = [
      SELECT Id, Cantidad_con_Signo__c, Fecha_Fin__c, Variedad__c, N_CUIT__c
      FROM Tonelada__c
      WHERE
        Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Biotecnologia__c IN :biotechs
        AND Origen__c = 'Compra HT'
        AND HT_Id__r.Linea_de_Compra_HT__r.Tipo_de_Compra__c = 'Disponible'
        AND Etapa__c != 'Pendiente'
        AND Fecha_Inicio__c <= TODAY
        AND Campania__c != NULL
        AND Campania__r.Estado__c IN ('Completa', 'Activa')
      ORDER BY Fecha_Fin__c ASC
      LIMIT 10000
    ];
    return mergeLotesCompraHTOrdenados(
      lotesCampania,
      consultarLotesCompraHTEnCuenta(
        htCuentaId,
        productorId,
        cultivoId,
        biotechs
      )
    );
  }

  /**
   * Toneladas Compra HT ya asignadas a la CG sin campaña (p. ej. cargadas manualmente
   * o con campaña antigua/inactiva). El saldo HT las incluye pero la query por campaña no.
   */
  private static List<Tonelada__c> consultarLotesCompraHTEnCuenta(
    Id htCuentaId,
    Id productorId,
    Id cultivoId,
    Set<String> biotechs
  ) {
    if (htCuentaId == null) {
      return new List<Tonelada__c>();
    }
    return [
      SELECT Id, Cantidad_con_Signo__c, Fecha_Fin__c, Variedad__c, N_CUIT__c
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :htCuentaId
        AND Productor__c = :productorId
        AND Cultivo__c = :cultivoId
        AND Biotecnologia__c IN :biotechs
        AND Origen__c = 'Compra HT'
        AND Etapa__c != 'Pendiente'
        AND Fecha_Inicio__c <= TODAY
        AND Cantidad_con_Signo__c > 0
      ORDER BY Fecha_Fin__c ASC NULLS LAST, CreatedDate ASC
      LIMIT 10000
    ];
  }

  private static List<Tonelada__c> mergeLotesCompraHTOrdenados(
    List<Tonelada__c> lotesCampania,
    List<Tonelada__c> lotesEnCuenta
  ) {
    Map<Id, Tonelada__c> porId = new Map<Id, Tonelada__c>();
    for (Tonelada__c lote : lotesCampania) {
      porId.put(lote.Id, lote);
    }
    for (Tonelada__c lote : lotesEnCuenta) {
      porId.put(lote.Id, lote);
    }
    List<Tonelada__c> merged = new List<Tonelada__c>(porId.values());
    merged.sort(new LoteHTFechaFinComparator());
    return merged;
  }

  private class LoteHTFechaFinComparator implements System.Comparator<Tonelada__c> {
    public Integer compare(Tonelada__c a, Tonelada__c b) {
      if (a.Fecha_Fin__c == b.Fecha_Fin__c) {
        return 0;
      }
      if (a.Fecha_Fin__c == null) {
        return 1;
      }
      if (b.Fecha_Fin__c == null) {
        return -1;
      }
      return a.Fecha_Fin__c < b.Fecha_Fin__c ? -1 : 1;
    }
  }

  private static Map<Id, Decimal> calcularRemainingPorLote(
    List<Tonelada__c> todosLotesHT
  ) {
    Map<Id, Decimal> remainingPerLote = new Map<Id, Decimal>();
    List<Tonelada__c> lotesPositivos = new List<Tonelada__c>();

    for (Tonelada__c lote : todosLotesHT) {
      if (
        lote.Cantidad_con_Signo__c != null &&
        lote.Cantidad_con_Signo__c > 0
      ) {
        lotesPositivos.add(lote);
        remainingPerLote.put(lote.Id, lote.Cantidad_con_Signo__c);
      }
    }

    for (Tonelada__c lote : todosLotesHT) {
      if (
        lote.Cantidad_con_Signo__c != null &&
        lote.Cantidad_con_Signo__c < 0
      ) {
        Decimal negativo = Math.abs(lote.Cantidad_con_Signo__c);
        for (Tonelada__c posLote : lotesPositivos) {
          if (negativo <= 0) {
            break;
          }
          Decimal remaining = remainingPerLote.get(posLote.Id);
          if (remaining <= 0) {
            continue;
          }
          Decimal descuento = Math.min(negativo, remaining);
          remainingPerLote.put(posLote.Id, remaining - descuento);
          negativo -= descuento;
        }
      }
    }

    Set<Id> loteIds = remainingPerLote.keySet();
    if (!loteIds.isEmpty()) {
      for (AggregateResult ar : [
        SELECT Tonelada_Compra_HT__c loteId, SUM(Cantidad__c) totalConsumido
        FROM Tonelada__c
        WHERE
          Tonelada_Compra_HT__c IN :loteIds
          AND Origen__c = 'Consumo'
          AND Signo__c = 1
        GROUP BY Tonelada_Compra_HT__c
      ]) {
        Id loteId = (Id) ar.get('loteId');
        Decimal totalConsumido = (Decimal) ar.get('totalConsumido');
        if (remainingPerLote.containsKey(loteId)) {
          remainingPerLote.put(
            loteId,
            Math.max(remainingPerLote.get(loteId) - totalConsumido, 0)
          );
        }
      }
    }

    return remainingPerLote;
  }

  private static Decimal calcularSaldoDesdeToneladas(Id cuentaGranariaId) {
    AggregateResult ar = [
      SELECT SUM(Cantidad_con_Signo__c) total
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cuentaGranariaId
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c != 'Balance Anual'
    ];
    return ar.get('total') != null ? (Decimal) ar.get('total') : 0;
  }

  private static final Integer DETALLE_PAGE = 40;
  private static final Integer CSV_MAX = 10000;

  private static final List<String> ORDEN_ORIGEN = new List<String>{
    'Compra SF',
    'Compra HT',
    'Cesión HT',
    'Semilla Original',
    'BolsaTech',
    'Regalía Enlist',
    'Semilla Pre Básica',
    'Ensayo',
    'PPH',
    'Aplicada',
    'Consumo',
    'Transferencia'
  };

  private static final Map<String, String> ETIQUETA_ORIGEN = new Map<String, String>{
    'Compra SF' => 'Compra Semilla Fiscalizada',
    'Compra HT' => 'Compra Hectáreas Tecnológicas',
    'Cesión HT' => 'Cesión',
    'Semilla Original' => 'Semilla Original',
    'BolsaTech' => 'Entregas',
    'Regalía Enlist' => 'Regalía pagada'
  };

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getResumen(Id cuentaGranariaId) {
    Cuenta_Granaria__c cuenta = consultarCuenta(cuentaGranariaId);
    Map<String, OrigenAcum> porOrigen = new Map<String, OrigenAcum>();
    Decimal credito = 0;
    Decimal debito = 0;

    for (AggregateResult ar : [
      SELECT
        Origen__c origen,
        COUNT(Id) movimientos,
        SUM(Cantidad_con_Signo__c) toneladas
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cuentaGranariaId
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c != 'Balance Anual'
      GROUP BY Origen__c
    ]) {
      String origen = (String) ar.get('origen');
      if (String.isBlank(origen)) {
        origen = 'Sin origen';
      }
      OrigenAcum acum = new OrigenAcum(origen);
      acum.toneladas = ar.get('toneladas') == null
        ? 0
        : (Decimal) ar.get('toneladas');
      acum.movimientos = (Integer) ar.get('movimientos');
      porOrigen.put(origen, acum);
    }

    for (AggregateResult ar : [
      SELECT SUM(Cantidad__c) cantidad
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cuentaGranariaId
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c != 'Balance Anual'
        AND Signo__c > 0
    ]) {
      credito = ar.get('cantidad') == null ? 0 : (Decimal) ar.get('cantidad');
    }
    for (AggregateResult ar : [
      SELECT SUM(Cantidad__c) cantidad
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cuentaGranariaId
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c != 'Balance Anual'
        AND Signo__c < 0
    ]) {
      debito = ar.get('cantidad') == null
        ? 0
        : (Decimal) ar.get('cantidad') * -1;
    }

    List<OrigenAcum> ordenados = new List<OrigenAcum>();
    for (String clave : ORDEN_ORIGEN) {
      if (porOrigen.containsKey(clave)) {
        ordenados.add(porOrigen.remove(clave));
      }
    }
    List<String> restantes = new List<String>(porOrigen.keySet());
    restantes.sort();
    for (String clave : restantes) {
      ordenados.add(porOrigen.get(clave));
    }

    List<Map<String, Object>> origenes = new List<Map<String, Object>>();
    Integer movimientos = 0;
    for (OrigenAcum acum : ordenados) {
      origenes.add(acum.toMap());
      movimientos += acum.movimientos;
    }

    return new Map<String, Object>{
      'origenes' => origenes,
      'credito' => credito,
      'debito' => debito,
      'saldo' => credito + debito,
      'movimientos' => movimientos,
      'cuenta' => armarCuenta(cuenta)
    };
  }

  @AuraEnabled
  public static Map<String, Object> getDetalle(
    Id cuentaGranariaId,
    String origen,
    String buscar,
    String cursorFecha,
    String cursorId
  ) {
    Datetime cursorDt = parseCursor(cursorFecha);
    Id cursorRecordId = String.isBlank(cursorId) ? null : (Id) cursorId;
    String buscarLike = likeTerm(buscar);

    List<String> filtros = filtrosBase();
    if (String.isNotBlank(origen)) {
      filtros.add('Origen__c = :origen');
    }
    if (buscarLike != null) {
      filtros.add('Name LIKE :buscarLike');
    }
    if (cursorDt != null && cursorRecordId != null) {
      filtros.add(
        '(CreatedDate < :cursorDt OR (CreatedDate = :cursorDt AND Id < :cursorRecordId))'
      );
    }

    String soql =
      'SELECT Id, Name, Origen__c, Cantidad_con_Signo__c, Fecha_Inicio__c, Etapa__c, CreatedDate' +
      ', Detalle_Variedad_CG__c, Detalle_Variedad_CG__r.Variedad__r.Name' +
      ' FROM Tonelada__c WHERE ' +
      String.join(filtros, ' AND ') +
      ' ORDER BY CreatedDate DESC, Id DESC LIMIT ' +
      String.valueOf(DETALLE_PAGE + 1);

    List<Tonelada__c> filas = Database.query(soql);
    Boolean hayMas = filas.size() > DETALLE_PAGE;
    if (hayMas) {
      filas.remove(filas.size() - 1);
    }

    List<ToneladaWrapper> wrappers = new List<ToneladaWrapper>();
    Boolean hayVariedad = false;
    for (Tonelada__c tn : filas) {
      ToneladaWrapper w = toWrapper(tn);
      wrappers.add(w);
      if (w.detalleVariedadCGId != null) {
        hayVariedad = true;
      }
    }

    String nextFecha;
    String nextId;
    if (!filas.isEmpty()) {
      Tonelada__c ultima = filas[filas.size() - 1];
      nextFecha = ultima.CreatedDate.formatGmt(
        'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''
      );
      nextId = ultima.Id;
    }

    return new Map<String, Object>{
      'filas' => wrappers,
      'hayMas' => hayMas,
      'mostrarVariedad' => hayVariedad,
      'cursorFecha' => nextFecha,
      'cursorId' => nextId
    };
  }

  @AuraEnabled
  public static String exportarCsv(Id cuentaGranariaId, String origen) {
    if (String.isBlank(origen)) {
      throw new AuraHandledException('Elegí un origen para descargar el CSV.');
    }

    Integer total = [
      SELECT COUNT()
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cuentaGranariaId
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c = :origen
    ];
    if (total > CSV_MAX) {
      throw new AuraHandledException(
        'Ese origen tiene ' +
          total +
          ' movimientos. El CSV admite hasta ' +
          CSV_MAX +
          '. Usá Ver detalle para recorrerlo.'
      );
    }

    List<Tonelada__c> filas = [
      SELECT Name, Origen__c, Etapa__c, CreatedDate, Cantidad_con_Signo__c
      FROM Tonelada__c
      WHERE
        Cuenta_Granaria__c = :cuentaGranariaId
        AND Fecha_Inicio__c <= TODAY
        AND Etapa__c != 'Pendiente'
        AND Origen__c = :origen
      ORDER BY CreatedDate DESC, Id DESC
      LIMIT :CSV_MAX
    ];

    String sep = ';';
    List<String> lineas = new List<String>();
    lineas.add(
      'Nombre' +
        sep +
        'Origen' +
        sep +
        'Etapa' +
        sep +
        'Fecha creacion' +
        sep +
        'Cantidad'
    );
    for (Tonelada__c tn : filas) {
      Decimal cantidad = tn.Cantidad_con_Signo__c == null
        ? 0
        : tn.Cantidad_con_Signo__c;
      lineas.add(
        csvCampo(tn.Name) +
          sep +
          csvCampo(etiquetaOrigen(tn.Origen__c)) +
          sep +
          csvCampo(tn.Etapa__c) +
          sep +
          csvCampo(
            tn.CreatedDate == null ? '' : tn.CreatedDate.format('dd/MM/yyyy')
          ) +
          sep +
          String.valueOf(cantidad)
      );
    }
    return '\uFEFF' + String.join(lineas, '\n');
  }

  private static Cuenta_Granaria__c consultarCuenta(Id cuentaGranariaId) {
    return [
      SELECT
        Id,
        Name,
        Productor__c,
        Productor__r.Name,
        Campania__c,
        Campania__r.Name,
        Cultivo__c,
        Cultivo__r.Name,
        Tecnologia__c,
        Saldo_Cuenta__c,
        Es_Carga_Manual__c,
        Variedad__c,
        Variedad__r.Name,
        N_CUIT__c
      FROM Cuenta_Granaria__c
      WHERE Id = :cuentaGranariaId
      LIMIT 1
    ];
  }

  private static Map<String, Object> armarCuenta(Cuenta_Granaria__c cuenta) {
    Decimal saldoCompraHT = 0;
    Id compraHTId = null;
    List<Map<String, Object>> cuentasRelacionadas = new List<Map<String, Object>>();

    if (cuenta.Campania__c != null) {
      List<Cuenta_Granaria__c> cuentasHT = [
        SELECT Id, Saldo_Cuenta__c
        FROM Cuenta_Granaria__c
        WHERE
          Productor__c = :cuenta.Productor__c
          AND Cultivo__c = :cuenta.Cultivo__c
          AND Tecnologia__c = :cuenta.Tecnologia__c
          AND Campania__c = NULL
        LIMIT 1
      ];
      if (!cuentasHT.isEmpty()) {
        saldoCompraHT = cuentasHT[0].Saldo_Cuenta__c != null
          ? cuentasHT[0].Saldo_Cuenta__c
          : 0;
        compraHTId = cuentasHT[0].Id;
      }
    } else {
      Integer anio = Date.today().year();
      Set<String> anosPermitidos = new Set<String>();
      for (Integer i = 0; i < 5; i++) {
        anosPermitidos.add(String.valueOf(anio - i));
      }
      for (Cuenta_Granaria__c cg : [
        SELECT
          Id,
          Campania__r.Name,
          Campania__r.Ano__c,
          Tecnologia__c,
          Saldo_Cuenta__c
        FROM Cuenta_Granaria__c
        WHERE
          Productor__c = :cuenta.Productor__c
          AND Cultivo__c = :cuenta.Cultivo__c
          AND Campania__c != NULL
          AND Campania__r.Ano__c IN :anosPermitidos
        ORDER BY Campania__r.Ano__c DESC, Tecnologia__c ASC
      ]) {
        cuentasRelacionadas.add(
          new Map<String, Object>{
            'id' => cg.Id,
            'campania' => cg.Campania__r.Name,
            'saldo' => cg.Saldo_Cuenta__c != null ? cg.Saldo_Cuenta__c : 0
          }
        );
      }
    }

    return new Map<String, Object>{
      'nombre' => cuenta.Name,
      'productor' => cuenta.Productor__r.Name,
      'cuit' => cuenta.N_CUIT__c,
      'campania' => cuenta.Campania__c != null ? cuenta.Campania__r.Name : null,
      'cultivo' => cuenta.Cultivo__r.Name,
      'variedad' => cuenta.Variedad__r == null ? null : cuenta.Variedad__r.Name,
      'tecnologia' => cuenta.Tecnologia__c,
      'saldo' => cuenta.Saldo_Cuenta__c,
      'esCompraHT' => cuenta.Campania__c == null,
      'esCargaManual' => cuenta.Es_Carga_Manual__c == true,
      'puedeGenerarConsumo' => evaluarPuedeGenerarConsumo(
        cuenta,
        saldoCompraHT
      ),
      'saldoCompraHT' => saldoCompraHT,
      'compraHTId' => compraHTId,
      'cuentasRelacionadas' => cuentasRelacionadas
    };
  }

  private static ToneladaWrapper toWrapper(Tonelada__c tn) {
    ToneladaWrapper wrapper = new ToneladaWrapper();
    wrapper.id = tn.Id;
    wrapper.nombre = tn.Name != null ? tn.Name : 'Sin nombre';
    wrapper.origen = etiquetaOrigen(tn.Origen__c);
    wrapper.cantidad = tn.Cantidad_con_Signo__c != null
      ? tn.Cantidad_con_Signo__c
      : 0;
    wrapper.esPositivo = wrapper.cantidad >= 0;
    wrapper.fechaInicio = tn.Fecha_Inicio__c != null
      ? String.valueOf(tn.Fecha_Inicio__c)
      : '';
    wrapper.fechaCreacion = tn.CreatedDate != null
      ? tn.CreatedDate.format('dd/MM/yyyy')
      : '';
    wrapper.etapa = tn.Etapa__c;
    wrapper.variedad = tn.Detalle_Variedad_CG__r.Variedad__r.Name;
    wrapper.detalleVariedadCGId = tn.Detalle_Variedad_CG__c;
    return wrapper;
  }

  private static String etiquetaOrigen(String origen) {
    if (String.isBlank(origen)) {
      return 'Sin origen';
    }
    return ETIQUETA_ORIGEN.containsKey(origen)
      ? ETIQUETA_ORIGEN.get(origen)
      : origen;
  }

  private static List<String> filtrosBase() {
    return new List<String>{
      'Cuenta_Granaria__c = :cuentaGranariaId',
      'Fecha_Inicio__c <= TODAY',
      'Etapa__c != \'Pendiente\'',
      'Origen__c != \'Balance Anual\''
    };
  }

  private static Datetime parseCursor(String cursorFecha) {
    if (String.isBlank(cursorFecha)) {
      return null;
    }
    return (Datetime) JSON.deserialize('"' + cursorFecha + '"', Datetime.class);
  }

  private static String likeTerm(String buscar) {
    if (String.isBlank(buscar)) {
      return null;
    }
    String clean = buscar.trim()
      .replace('\\', '')
      .replace('%', '')
      .replace('_', '');
    return String.isBlank(clean) ? null : '%' + clean + '%';
  }

  private static String csvCampo(String valor) {
    String texto = valor == null ? '' : valor;
    if (texto.contains(';') || texto.contains('"') || texto.contains('\n')) {
      return '"' + texto.replace('"', '""') + '"';
    }
    return texto;
  }

  private class OrigenAcum {
    String origen;
    Decimal toneladas = 0;
    Integer movimientos = 0;

    OrigenAcum(String origen) {
      this.origen = origen;
    }

    Map<String, Object> toMap() {
      return new Map<String, Object>{
        'origen' => origen,
        'etiqueta' => etiquetaOrigen(origen),
        'toneladas' => toneladas,
        'movimientos' => movimientos,
        'esNegativo' => toneladas < 0
      };
    }
  }
}
