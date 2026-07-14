@isTest
public class ObtenerCampanaTest {

    @TestSetup
    static void setupTestData() {
        // Cultivo principal con campañas
        Cultivo__c testCultivo = new Cultivo__c(
            Name = 'TRIGO',
            Temporada__c = 'Anual',
            Densidad_de_Siembra__c = 23
        );
        insert testCultivo;

        // Cultivo sin campañas (para cubrir path "No se encontraron campañas")
        Cultivo__c cultivoSinCampanas = new Cultivo__c(
            Name = 'CEBADA',
            Temporada__c = 'Anual',
            Densidad_de_Siembra__c = 20
        );
        insert cultivoSinCampanas;

        // Tres campañas consecutivas para TRIGO con fechas SE
        List<Campana_Agricola__c> campanas = new List<Campana_Agricola__c>();

        campanas.add(new Campana_Agricola__c(
            Name = 'Campaña 2024',
            Ano__c = '2024',
            Id_Externo__c = 'EXT2024',
            SKEY_CAMPANIA__c = 2024001,
            Z9_Clave_Unica__c = 'Z9_2024',
            Cultivo__c = testCultivo.Id,
            Fecha_Inicio_SE__c = Date.newInstance(2024, 1, 1),
            Fecha_Fin_SE__c = Date.newInstance(2024, 6, 30)
        ));

        campanas.add(new Campana_Agricola__c(
            Name = 'Campaña 2025',
            Ano__c = '2025',
            Id_Externo__c = 'EXT2025',
            SKEY_CAMPANIA__c = 2025001,
            Z9_Clave_Unica__c = 'Z9_2025',
            Cultivo__c = testCultivo.Id,
            Fecha_Inicio_SE__c = Date.newInstance(2024, 7, 1),
            Fecha_Fin_SE__c = Date.newInstance(2025, 6, 30)
        ));

        campanas.add(new Campana_Agricola__c(
            Name = 'Campaña 2026',
            Ano__c = '2026',
            Id_Externo__c = 'EXT2026',
            SKEY_CAMPANIA__c = 2026001,
            Z9_Clave_Unica__c = 'Z9_2026',
            Cultivo__c = testCultivo.Id,
            Fecha_Inicio_SE__c = Date.newInstance(2025, 7, 1),
            Fecha_Fin_SE__c = Date.newInstance(2026, 6, 30)
        ));

        insert campanas;
    }

    // ─── Helpers ────────────────────────────────────────────────────────────────

    private static Cultivo__c getCultivo(String nombre) {
        return [SELECT Id FROM Cultivo__c WHERE Name = :nombre LIMIT 1];
    }

    private static ObtenerCampana.CampanaRequest buildRequest(Id cultivoId, String cultivo, String fecha, String tipoCompra) {
        ObtenerCampana.CampanaRequest req = new ObtenerCampana.CampanaRequest();
        req.origenCampana = 'Compra HT';
        req.nombreCultivo = cultivo;
        req.fechaCreacion = fecha;
        req.tipoCompra = tipoCompra;
        req.cultivoId = cultivoId;
        return req;
    }

    // ─── Compra Futura: buscarCampanaPorRangoFecha encuentra match ──────────────

    @isTest
    static void testFutura_CampanaEncontrada() {
        Id cultivoId = getCultivo('TRIGO').Id;
        // 2025-03-15 cae dentro de Campaña 2025 (2024-07-01 a 2025-06-30)
        ObtenerCampana.CampanaRequest req = buildRequest(cultivoId, 'TRIGO', '2025-03-15', 'Futura');

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(
            new List<ObtenerCampana.CampanaRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(true, res[0].esExitoso, 'Debe encontrar campaña para Futura');
        System.assertNotEquals(null, res[0].campanaId, 'Debe devolver ID de campaña');
        System.assertEquals('2025', res[0].anoCampana);
    }

    // ─── Compra Futura: sin match en rango de fechas ────────────────────────────

    @isTest
    static void testFutura_SinMatch() {
        Id cultivoId = getCultivo('TRIGO').Id;
        // 2099-01-01 no cae en ningún rango
        ObtenerCampana.CampanaRequest req = buildRequest(cultivoId, 'TRIGO', '2099-01-01', 'Futura');

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(
            new List<ObtenerCampana.CampanaRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, res[0].esExitoso, 'No debe encontrar campaña');
        System.assertEquals('No se encontró campaña con los criterios especificados', res[0].mensajeError);
    }

    // ─── Disponible: buscarCampanaAnterior devuelve la previa a la vigente ──────

    @isTest
    static void testDisponible_CampanaAnteriorEncontrada() {
        Id cultivoId = getCultivo('TRIGO').Id;
        // 2025-03-15 cae en Campaña 2025 (índice 1), la anterior es Campaña 2024 (índice 0)
        ObtenerCampana.CampanaRequest req = buildRequest(cultivoId, 'TRIGO', '2025-03-15', 'Disponible');

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(
            new List<ObtenerCampana.CampanaRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, res[0].esExitoso, 'Debe encontrar campaña anterior');
        System.assertEquals('2024', res[0].anoCampana, 'Debe devolver la campaña anterior (2024)');
    }

    // ─── Disponible: campaña actual es la primera, no hay anterior ──────────────

    @isTest
    static void testDisponible_SinCampanaAnterior() {
        Id cultivoId = getCultivo('TRIGO').Id;
        // 2024-03-15 cae en Campaña 2024 (índice 0), no hay anterior y ninguna terminó antes
        ObtenerCampana.CampanaRequest req = buildRequest(cultivoId, 'TRIGO', '2024-03-15', 'Disponible');

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(
            new List<ObtenerCampana.CampanaRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, res[0].esExitoso, 'No debe encontrar campaña anterior');
        System.assertEquals('No se encontró campaña con los criterios especificados', res[0].mensajeError);
    }

    // ─── Disponible: fallback - fecha fuera de todos los rangos, devuelve última finalizada ─

    @isTest
    static void testDisponible_FallbackUltimaFinalizada() {
        Id cultivoId = getCultivo('TRIGO').Id;
        // 2026-08-15 está fuera de todos los rangos; Campaña 2026 terminó 2026-06-30 < 2026-08-15
        ObtenerCampana.CampanaRequest req = buildRequest(cultivoId, 'TRIGO', '2026-08-15', 'Disponible');

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(
            new List<ObtenerCampana.CampanaRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, res[0].esExitoso, 'Debe encontrar campaña por fallback');
        System.assertEquals('2026', res[0].anoCampana, 'Debe devolver la última campaña finalizada');
    }

    // ─── Tipo de compra null (no Futura) → busca anterior ───────────────────────

    @isTest
    static void testTipoCompraNullBuscaAnterior() {
        Id cultivoId = getCultivo('TRIGO').Id;
        // tipoCompra null → se trata como no-Futura → busca anterior
        ObtenerCampana.CampanaRequest req = buildRequest(cultivoId, 'TRIGO', '2025-03-15', null);

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(
            new List<ObtenerCampana.CampanaRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, res[0].esExitoso, 'Debe resolver como no-Futura y devolver anterior');
        System.assertEquals('2024', res[0].anoCampana);
    }

    // ─── Cultivo sin campañas ───────────────────────────────────────────────────

    @isTest
    static void testCultivoSinCampanas() {
        Id cultivoId = getCultivo('CEBADA').Id;
        ObtenerCampana.CampanaRequest req = buildRequest(cultivoId, 'CEBADA', '2025-03-15', 'Futura');

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(
            new List<ObtenerCampana.CampanaRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, res[0].esExitoso);
        System.assertEquals('No se encontraron campañas para el cultivo especificado', res[0].mensajeError);
    }

    // ─── Parámetros requeridos faltantes ────────────────────────────────────────

    @isTest
    static void testParametrosRequeridosFaltantes() {
        ObtenerCampana.CampanaRequest req1 = new ObtenerCampana.CampanaRequest();
        req1.origenCampana = '';
        req1.nombreCultivo = '';
        req1.fechaCreacion = '';
        req1.tipoCompra = '';
        req1.cultivoId = null;

        ObtenerCampana.CampanaRequest req2 = new ObtenerCampana.CampanaRequest();
        req2.origenCampana = null;
        req2.nombreCultivo = null;
        req2.fechaCreacion = null;
        req2.tipoCompra = null;
        req2.cultivoId = null;

        List<ObtenerCampana.CampanaRequest> requests = new List<ObtenerCampana.CampanaRequest>{ req1, req2 };

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(requests);
        Test.stopTest();

        System.assertEquals(2, res.size());
        for (ObtenerCampana.CampanaResponse r : res) {
            System.assertEquals(false, r.esExitoso);
            System.assertEquals('Error: parámetros requeridos faltantes', r.mensajeError);
        }
    }

    // ─── Todos los requests inválidos → cultivoIds vacío → early return ─────────

    @isTest
    static void testTodosInvalidos_EarlyReturn() {
        ObtenerCampana.CampanaRequest req = new ObtenerCampana.CampanaRequest();
        req.cultivoId = null;
        req.nombreCultivo = '';
        req.fechaCreacion = '';

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(
            new List<ObtenerCampana.CampanaRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(false, res[0].esExitoso);
    }

    // ─── Fecha con formato inválido → catch en procesamiento individual ─────────

    @isTest
    static void testFechaInvalida_ExcepcionEnProcesamiento() {
        Id cultivoId = getCultivo('TRIGO').Id;
        ObtenerCampana.CampanaRequest req = buildRequest(cultivoId, 'TRIGO', 'NO-ES-FECHA', 'Futura');

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(
            new List<ObtenerCampana.CampanaRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, res[0].esExitoso, 'Debe fallar con fecha inválida');
        System.assert(res[0].mensajeError.contains('Error procesando request'), 'Debe contener mensaje de error de procesamiento');
    }

    // ─── Múltiples requests mixtos (válidos + inválidos + distintos tipos) ──────

    @isTest
    static void testMultipleRequestsMixtos() {
        Id cultivoTrigo = getCultivo('TRIGO').Id;
        Id cultivoCebada = getCultivo('CEBADA').Id;

        List<ObtenerCampana.CampanaRequest> requests = new List<ObtenerCampana.CampanaRequest>();

        // 1: Futura válido → éxito
        requests.add(buildRequest(cultivoTrigo, 'TRIGO', '2025-03-15', 'Futura'));
        // 2: Disponible válido → anterior
        requests.add(buildRequest(cultivoTrigo, 'TRIGO', '2026-01-15', 'Disponible'));
        // 3: Parámetros faltantes → error validación
        ObtenerCampana.CampanaRequest reqInvalido = new ObtenerCampana.CampanaRequest();
        reqInvalido.cultivoId = null;
        reqInvalido.nombreCultivo = '';
        reqInvalido.fechaCreacion = '';
        requests.add(reqInvalido);
        // 4: Cultivo sin campañas → no encontradas
        requests.add(buildRequest(cultivoCebada, 'CEBADA', '2025-05-15', 'Futura'));

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res = ObtenerCampana.obtenerIdCampanaInvocable(requests);
        Test.stopTest();

        System.assertEquals(4, res.size(), 'Debe retornar 4 respuestas');
        // 1: Futura encontrada
        System.assertEquals(true, res[0].esExitoso);
        System.assertEquals('2025', res[0].anoCampana);
        // 2: Disponible → anterior (Campaña 2025)
        System.assertEquals(true, res[1].esExitoso);
        System.assertEquals('2025', res[1].anoCampana);
        // 3: Inválido
        System.assertEquals(false, res[2].esExitoso);
        System.assertEquals('Error: parámetros requeridos faltantes', res[2].mensajeError);
        // 4: Cultivo sin campañas
        System.assertEquals(false, res[3].esExitoso);
    }

    // ─── Doble invocación (cobertura de re-entrada) ─────────────────────────────

    @isTest
    static void testDobleInvocacion() {
        Id cultivoId = getCultivo('TRIGO').Id;
        ObtenerCampana.CampanaRequest req = buildRequest(cultivoId, 'TRIGO', '2025-03-15', 'Futura');
        List<ObtenerCampana.CampanaRequest> requests = new List<ObtenerCampana.CampanaRequest>{ req };

        Test.startTest();
        List<ObtenerCampana.CampanaResponse> res1 = ObtenerCampana.obtenerIdCampanaInvocable(requests);
        List<ObtenerCampana.CampanaResponse> res2 = ObtenerCampana.obtenerIdCampanaInvocable(requests);
        Test.stopTest();

        System.assertEquals(true, res1[0].esExitoso);
        System.assertEquals(true, res2[0].esExitoso);
    }
}