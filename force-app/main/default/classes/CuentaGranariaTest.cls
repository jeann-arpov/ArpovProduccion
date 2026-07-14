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