public inherited sharing class EstadoVarietal {
  public static final String DEBE_REGULARIZAR = 'Debe regularizar';
  public static final String EN_REGLA = 'En regla';
  public static final String SIN_ENTREGAS = 'Sin entregas';

  // Umbral en toneladas cuando no hay Configuracion_Varietal__mdt para trigo: −1 HT = −4 t.
  public static final Decimal UMBRAL_POR_DEFECTO = -4;
  private static final String CULTIVO = 'TRIGO';

  public static final Set<String> ORIGENES_ENTREGA = new Set<String>{
    'BolsaTech',
    'Escáner varietal'
  };

  // SE-392 CP-01: el crédito de Compra HT/SF cuenta solo Cobrada (y equivalentes).
  public static final Set<String> ORIGENES_COMPRA = new Set<String>{
    'Compra HT',
    'Compra SF'
  };
  public static final Set<String> ETAPAS_CREDITO_COMPRA = new Set<String>{
    'Cobrada',
    'Acreditada',
    'Reacreditada',
    'Recibida'
  };

  private static Decimal umbralCache;

  public static String calcular(Decimal saldo, Decimal entregas) {
    if (debeRegularizar(saldo)) {
      return DEBE_REGULARIZAR;
    }
    if (entregas == null || entregas == 0) {
      return SIN_ENTREGAS;
    }
    return EN_REGLA;
  }

  // Vista del portal (D-26): "Entregaste de más" desde saldo < 0. El CRM y el expediente siguen con umbral().
  public static String calcularVista(Decimal saldo, Decimal entregas) {
    if (saldoNegativo(saldo)) {
      return DEBE_REGULARIZAR;
    }
    if (entregas == null || entregas == 0) {
      return SIN_ENTREGAS;
    }
    return EN_REGLA;
  }

  public static Boolean debeRegularizar(Decimal saldo) {
    return saldo != null && saldo < umbral();
  }

  public static Boolean saldoNegativo(Decimal saldo) {
    return saldo != null && saldo < 0;
  }

  // F5 / D-07: guardar decimales; redondear solo al mostrar (HALF_UP).
  public static Integer tnEntera(Decimal valor) {
    if (valor == null) {
      return 0;
    }
    return valor.setScale(0, RoundingMode.HALF_UP).intValue();
  }

  // Saldo de pantalla = Acreditado mostrado − Entregado mostrado. No redondear el saldo aparte.
  public static Integer saldoMostrado(Decimal credito, Decimal debito) {
    return tnEntera(credito) - tnEntera(debito);
  }

  public static Decimal toneladasMostradasARegularizar(
    Decimal credito,
    Decimal debito
  ) {
    Integer saldo = saldoMostrado(credito, debito);
    return saldo < 0 ? -saldo : 0;
  }

  public static Boolean esEntrega(String origen) {
    return ORIGENES_ENTREGA.contains(origen);
  }

  // Compra HT: el crédito de pantalla solo cuenta Cobrada (SE-392 CP-01).
  public static Boolean acreditaCompra(String origen, String etapa) {
    if (origen != 'Compra HT') {
      return true;
    }
    return etapa != null && ETAPAS_CREDITO_COMPRA.contains(etapa);
  }

  // Mismo umbral que usa el expediente de negativos (Configuracion_Varietal__mdt.Umbral_Apertura_Expediente__c).
  public static Decimal umbral() {
    if (umbralCache == null) {
      umbralCache = UMBRAL_POR_DEFECTO;
      for (
        Configuracion_Varietal__mdt cfg : Configuracion_Varietal__mdt.getAll()
          .values()
      ) {
        if (
          cfg.Umbral_Apertura_Expediente__c != null &&
          aplicaATrigo(cfg.Cultivos_Varietales__c)
        ) {
          umbralCache = cfg.Umbral_Apertura_Expediente__c;
          break;
        }
      }
    }
    return umbralCache;
  }

  private static Boolean aplicaATrigo(String cultivos) {
    if (String.isBlank(cultivos)) {
      return true;
    }
    for (String cultivo : cultivos.split(',')) {
      if (cultivo.trim().equalsIgnoreCase(CULTIVO)) {
        return true;
      }
    }
    return false;
  }
}
