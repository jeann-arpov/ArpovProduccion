@isTest
public class CuentaGranariaTest {

    @testSetup
    static void setup() {
        Test_TestUtils.disableFlows();

        Account prod = Test_TestUtils.crearProductor();

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Tipo_de_Especie__c = 'SOJA',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c campana = Test_TestUtils.crearCampanaAgricola(
            '2025', cultivo, Date.today().addMonths(-3), Date.today().addMonths(9), 'SOJA 2025'
        );

        Campana_Agricola__c campana2 = Test_TestUtils.crearCampanaAgricola(
            '2024', cultivo, Date.today().addYears(-1), Date.today().addMonths(-6), 'SOJA 2024'
        );

        // Tonelada regular con campaña — el trigger crea automáticamente la Cuenta Granaria regular
        Tonelada__c tn1 = new Tonelada__c(
            Productor__c = prod.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'Enlist E3',
            Cantidad__c = 100,
            Signo__c = 1,
            Fecha_Inicio__c = Date.today().addDays(-5),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = 'Compra SF'
        );
        insert tn1;
        // El trigger de Tonelada crea automáticamente la Cuenta Granaria HT (sin campaña)
        // vía procesarToneladasEspecificas, no es necesario insertarla manualmente.
    }

    @isTest
    static void testGetLoadData() {
        Map<String, Object> result = CuentaGranaria.getLoadData();
        System.assertNotEquals(null, result);
        System.assert(result.containsKey('cultivos'));
    }

    @isTest
    static void testGetAdhesion() {
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
        List<Plan_de_Siembra__c> result = CuentaGranaria.getAdhesion(cultivo.Id);
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetCampanasConTotales() {
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];

        List<CuentaGranaria.CampanaConTotales> result = CuentaGranaria.getCampanasConTotales(
            cultivo.Id, 'Enlist E3/Conkesta E3'
        );
        System.assertNotEquals(null, result);
        System.assert(result.size() > 0, 'Debe devolver al menos una campaña');

        CuentaGranaria.CampanaConTotales primera = result[0];
        System.assertNotEquals(null, primera.id);
        System.assertNotEquals(null, primera.name);
        System.assertNotEquals(null, primera.ano);
    }

    @isTest
    static void testGetCampanasConTotalesSinResultados() {
        // Cultivo sin campañas
        Cultivo__c cultivoVacio = new Cultivo__c(
            Name = 'TRIGO',
            Tipo_de_Especie__c = 'TRIGO',
            Densidad_de_Siembra__c = 50,
            Sembra_Evolucion__c = true
        );
        insert cultivoVacio;

        List<CuentaGranaria.CampanaConTotales> result = CuentaGranaria.getCampanasConTotales(
            cultivoVacio.Id, 'Convencional'
        );
        System.assertEquals(0, result.size());
    }

    private static Cultivo__c crearCultivoConVentanasSE(Date finVentana2026) {
        Date hoy = Date.today();
        Cultivo__c cultivo = new Cultivo__c(
            Name = 'CEBADA',
            Tipo_de_Especie__c = 'CEBADA',
            Densidad_de_Siembra__c = 100,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c c23 = Test_TestUtils.crearCampanaAgricola('2023', cultivo, hoy.addYears(-3), null, '2023 - CEBADA', false);
        Campana_Agricola__c c24 = Test_TestUtils.crearCampanaAgricola('2024', cultivo, hoy.addYears(-2), null, '2024 - CEBADA', false);
        Campana_Agricola__c c25 = Test_TestUtils.crearCampanaAgricola('2025', cultivo, hoy.addYears(-1), null, '2025 - CEBADA', false);
        Campana_Agricola__c c26 = Test_TestUtils.crearCampanaAgricola('2026', cultivo, hoy.addDays(-5), null, '2026 - CEBADA', false);
        c23.Estado__c = 'Completa';
        c24.Estado__c = 'Completa';
        c24.Fecha_Inicio_SE__c = finVentana2026.addYears(-3).addDays(1);
        c24.Fecha_Fin_SE__c = finVentana2026.addYears(-2);
        c25.Estado__c = 'Activa';
        c25.Fecha_Inicio_SE__c = finVentana2026.addYears(-2).addDays(1);
        c25.Fecha_Fin_SE__c = finVentana2026.addYears(-1);
        c26.Estado__c = 'En Preparación';
        c26.Fecha_Inicio_SE__c = finVentana2026.addYears(-1).addDays(1);
        c26.Fecha_Fin_SE__c = finVentana2026;
        insert new List<Campana_Agricola__c>{ c23, c24, c25, c26 };
        return cultivo;
    }

    private static List<String> anos(List<Campana_Agricola__c> campanas) {
        List<String> result = new List<String>();
        for (Campana_Agricola__c c : campanas) result.add(c.Ano__c);
        return result;
    }

    @isTest
    static void testCampanaNuevaOcultaHastaCerrarVentanaSE() {
        // 26/27 ya pasó su Fecha_de_Inicio__c pero su ventana SE sigue abierta: no se muestra todavía.
        Cultivo__c cultivo = crearCultivoConVentanasSE(Date.today().addMonths(5));

        Test.startTest();
        List<Campana_Agricola__c> visibles = CuentaGranaria.getCampanasVisiblesPorCultivo(new Set<Id>{ cultivo.Id }).get(cultivo.Id);
        List<CuentaGranaria.CampanaConTotales> conTotales = CuentaGranaria.getCampanasConTotales(cultivo.Id, 'Convencional');
        Test.stopTest();

        System.assertEquals(new List<String>{ '2025', '2024', '2023' }, anos(visibles),
            'Debe mostrar la actual (25/26) y las 2 anteriores, sin la 26/27');
        System.assertEquals(3, conTotales.size());
        for (CuentaGranaria.CampanaConTotales c : conTotales) {
            System.assertEquals(c.ano == '2025', c.esActual, 'Solo la 25/26 es la campaña actual');
        }
    }

    @isTest
    static void testCampanaNuevaVisibleAlCerrarVentanaSE() {
        Cultivo__c cultivo = crearCultivoConVentanasSE(Date.today().addDays(-1));

        Test.startTest();
        List<Campana_Agricola__c> visibles = CuentaGranaria.getCampanasVisiblesPorCultivo(new Set<Id>{ cultivo.Id }).get(cultivo.Id);
        Test.stopTest();

        System.assertEquals(new List<String>{ '2026', '2025', '2024' }, anos(visibles),
            'Al cerrar la ventana SE de la 26/27 pasa a ser la actual y sale la 23/24');
    }

    @isTest
    static void testGetCampanas() {
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
        List<Campana_Agricola__c> result = CuentaGranaria.getCampanas(cultivo.Id);
        System.assert(result.size() > 0);
    }

    @isTest
    static void testGetToneladasByCampana() {
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Ano__c = '2025' LIMIT 1];

        List<Tonelada__c> result = CuentaGranaria.getToneladasByCampana(
            cultivo.Id, campana.Id, 'Enlist E3/Conkesta E3'
        );
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetDetalleBT() {
        String result = CuentaGranaria.getDetalleBT(new List<String>());
        System.assertNotEquals(null, result);
    }
}