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
        System.assertEquals('Sin entregas', EstadoVarietal.calcular(-2, 0), 'CRM: entre −4 t y 0 no regulariza');
        System.assertEquals('Debe regularizar', EstadoVarietal.calcularVista(-2, 0), 'Portal D-26: cualquier negativo');
        System.assertEquals('Debe regularizar', EstadoVarietal.calcularVista(-2, -10));
        System.assertEquals('Sin entregas', EstadoVarietal.calcularVista(0, 0));
        System.assertEquals('En regla', EstadoVarietal.calcularVista(100, -80));
        System.assertEquals(true, EstadoVarietal.saldoNegativo(-2));
        System.assertEquals(false, EstadoVarietal.saldoNegativo(0));
        System.assertEquals(32, EstadoVarietal.tnEntera(31.5));
        System.assertEquals(-32, EstadoVarietal.tnEntera(-31.5), 'F5: HALF_UP también en negativos');
        System.assertEquals(-32, EstadoVarietal.saldoMostrado(0, 31.5), 'F5: 0 − 32, no redondear −31,5 a −31');
        System.assertEquals(32, EstadoVarietal.toneladasMostradasARegularizar(0, 31.5));
        System.assertEquals(0, EstadoVarietal.toneladasMostradasARegularizar(10, 10.4));
        System.assertEquals(true, EstadoVarietal.acreditaCompra('Compra HT', 'Cobrada'));
        System.assertEquals(false, EstadoVarietal.acreditaCompra('Compra HT', 'Cancelada por NC'));
        System.assertEquals(false, EstadoVarietal.acreditaCompra('Compra HT', 'Aplicada'));
        System.assertEquals(true, EstadoVarietal.acreditaCompra('Compra SF', 'Aplicada'));
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
