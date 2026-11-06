@isTest
private class EstadoVarietalTest {

    @isTest
    static void aplicaOrdenYUmbral() {
        Decimal umbral = EstadoVarietal.umbral();
        System.assertEquals('Debe regularizar', EstadoVarietal.calcular(umbral - 36, 0), 'Saldo negativo sin entregas regulariza');
        System.assertEquals('Debe regularizar', EstadoVarietal.calcular(umbral - 1, -10));
        System.assertEquals('Sin entregas', EstadoVarietal.calcular(umbral, 0), 'En el umbral no regulariza');
        System.assertEquals('En regla', EstadoVarietal.calcular(umbral + 1, -20));
        System.assertEquals('Sin entregas', EstadoVarietal.calcular(500, 0));
        System.assertEquals('Sin entregas', EstadoVarietal.calcular(500, null));
        System.assertEquals('En regla', EstadoVarietal.calcular(100, -80));
        System.assertEquals(true, EstadoVarietal.esEntrega('Escáner varietal'));
        System.assertEquals(true, EstadoVarietal.esEntrega('BolsaTech'));
        System.assertEquals(false, EstadoVarietal.esEntrega('Compra SF'));
    }

    @isTest
    static void umbralDesdeConfiguracion() {
        Decimal esperado = EstadoVarietal.UMBRAL_POR_DEFECTO;
        for (Configuracion_Varietal__mdt cfg : Configuracion_Varietal__mdt.getAll().values()) {
            if (cfg.Umbral_Apertura_Expediente__c != null
                    && (String.isBlank(cfg.Cultivos_Varietales__c) || cfg.Cultivos_Varietales__c.toUpperCase().contains('TRIGO'))) {
                esperado = cfg.Umbral_Apertura_Expediente__c;
                break;
            }
        }
        System.assertEquals(esperado, EstadoVarietal.umbral());
    }
}
