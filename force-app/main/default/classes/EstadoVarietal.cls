public inherited sharing class EstadoVarietal {

    public static final String DEBE_REGULARIZAR = 'Debe regularizar';
    public static final String EN_REGLA = 'En regla';
    public static final String SIN_ENTREGAS = 'Sin entregas';

    // Umbral en toneladas cuando no hay Configuracion_Varietal__mdt para trigo: −1 HT = −4 t.
    public static final Decimal UMBRAL_POR_DEFECTO = -4;
    private static final String CULTIVO = 'TRIGO';

    public static final Set<String> ORIGENES_ENTREGA = new Set<String>{ 'BolsaTech', 'Escáner varietal' };

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

    // Mismo umbral que usa el expediente de negativos (Configuracion_Varietal__mdt.Umbral_Apertura_Expediente__c).
    public static Decimal umbral() {
        if (umbralCache == null) {
            umbralCache = UMBRAL_POR_DEFECTO;
            for (Configuracion_Varietal__mdt cfg : Configuracion_Varietal__mdt.getAll().values()) {
                if (cfg.Umbral_Apertura_Expediente__c != null && aplicaATrigo(cfg.Cultivos_Varietales__c)) {
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
