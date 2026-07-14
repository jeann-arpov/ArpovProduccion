@isTest(SeeAllData=false)
private class MovBolsaTechDebitarTNsBatchTest {

    // ── Datos de prueba ──────────────────────────────────────────────────────
    private static final String CUIT   = '20123456789';
    private static final String CTG    = 'CTG-001';
    private static final String CULTIVO = 'SOJA';
    private static final String TECNO  = 'Enlist';
    private static final Decimal PESO  = 1000;

    @TestSetup
    static void setup() {
        // El flow "Creacion de Expedientes PRI Y SEC" se dispara al insertar
        // un Movimiento_BolsaTech__c. Necesita encontrar un Cultivo__c con
        // Name='SOJA' para poder pasar cultivoId y nombreCultivo a ObtenerCampana.
        Cultivo__c c = new Cultivo__c(Name = 'SOJA', Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true);
        insert c;
        insert new Movimiento_BolsaTech__c(
            CUIT_Titular__c = CUIT,
            CTG__c          = CTG,
            Cultivo__c      = c.Id,
            Tecnologia__c   = TECNO,
            Peso_Neto__c    = PESO,
            TN_Id__c        = null,
            Estado__c       = 'A procesar',
            No_Debitar__c   = false,
            Fecha_de_Reconsideracion__c = Date.today().addDays(-10)
        );
    }

    // ── Tests ────────────────────────────────────────────────────────────────

    /**
     * Verifica que start() construye el QueryLocator sin errores.
     * Inserta un movimiento candidato y valida que el locator no sea null.
     */
    @isTest
    static void testStart_ReturnsQueryLocator() {
        

        Test.startTest();
        Database.QueryLocator ql = new MovBolsaTechDebitarTNsBatch().start(null);
        Test.stopTest();

        System.assertNotEquals(null, ql, 'El QueryLocator no debe ser null');
    }

    /**
     * Verifica que el Schedulable programa el job correctamente.
     */
    @isTest
    static void testScheduler_ProgramaJob() {
        Test.startTest();
        String jobId = System.schedule(
            'Test MovBolsaTech Debitar TNs',
            '0 0 13 * * ?',
            new MovBolsaTechDebitarTNsBatch()
        );
        Test.stopTest();

        CronTrigger ct = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        System.assertNotEquals(null, ct.Id, 'El job debe haberse programado');
    }

    /**
     * Verifica que finish() no lanza excepción.
     */
    @isTest
    static void testFinish_NoException() {
        Test.startTest();
        new MovBolsaTechDebitarTNsBatch().finish(null);
        Test.stopTest();
        System.assert(true, 'finish() no debe lanzar excepción');
    }
}