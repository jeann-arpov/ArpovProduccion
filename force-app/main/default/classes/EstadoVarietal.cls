public inherited sharing class EstadoVarietal {
  public static final String DEBE_REGULARIZAR = 'Debe regularizar';
  public static final String EN_REGLA = 'En regla';
  public static final String SIN_ENTREGAS = 'Sin entregas';

  // Umbral de estado (t) por defecto cuando no hay Configuracion_Varietal__mdt para trigo: saldo < 0 = "Debe regularizar".
  public static final Decimal UMBRAL_POR_DEFECTO = 0;
  private static final String CULTIVO = 'TRIGO';

  public static final Set<String> ORIGENES_ENTREGA = new Set<String>{
    'BolsaTech',
    'Escáner varietal'
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

  public static Boolean debeRegularizar(Decimal saldo) {
    return saldo != null && saldo < umbral();
  }

  public static Boolean esEntrega(String origen) {
    return ORIGENES_ENTREGA.contains(origen);
  }

  // Umbral de estado (saldo < 0 = "Debe regularizar"), independiente del
  // umbral de apertura de expediente. Se lee de Configuracion_Varietal__mdt.Umbral_Estado__c.
  public static Decimal umbral() {
    if (umbralCache == null) {
      umbralCache = UMBRAL_POR_DEFECTO;
      for (
        Configuracion_Varietal__mdt cfg : Configuracion_Varietal__mdt.getAll()
          .values()
      ) {
        if (
          cfg.Umbral_Estado__c != null &&
          aplicaATrigo(cfg.Cultivos_Varietales__c)
        ) {
          umbralCache = cfg.Umbral_Estado__c;
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
