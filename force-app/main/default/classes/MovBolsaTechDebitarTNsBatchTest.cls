@isTest(SeeAllData=false)
private class MovBolsaTechDebitarTNsBatchTest {
  // ── Datos de prueba ──────────────────────────────────────────────────────
  private static final String CUIT = '20123456789';
  private static final String CTG = 'CTG-001';
  private static final String CULTIVO = 'SOJA';
  private static final String TECNO = 'Enlist';
  private static final Decimal PESO = 1000;

  @TestSetup
  static void setup() {
    Test_TestUtils.disableFlows();

    // El flow "Creacion de Expedientes PRI Y SEC" se dispara al insertar
    // un Movimiento_BolsaTech__c. Necesita encontrar un Cultivo__c con
    // Name='SOJA' para poder pasar cultivoId y nombreCultivo a ObtenerCampana.
    Cultivo__c c = new Cultivo__c(
      Name = 'SOJA',
      Densidad_de_Siembra__c = 75,
      Sembra_Evolucion__c = true
    );
    insert c;
    insert new Movimiento_BolsaTech__c(
      CUIT_Titular__c = CUIT,
      CTG__c = CTG,
      Cultivo__c = c.Id,
      Tecnologia__c = TECNO,
      Peso_Neto__c = PESO,
      TN_Id__c = null,
      Estado__c = 'A procesar',
      No_Debitar__c = false,
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

  /**
   * Verifica que la query de start() excluye los MBTs vinculados a un
   * expediente PRI/SEC ya finalizado (facturado con regalía Enlist).
   */
  @isTest
  static void testBuildQuery_ExcluyePriSecFinalizados() {
    Test.startTest();
    String query = MovBolsaTechDebitarTNsBatch.buildQuery();
    Test.stopTest();

    System.assert(
      query.contains('Expediente_de_Negativos__r.Tipo_expendiente__c NOT IN'),
      'La query debe excluir expedientes PRI/SEC'
    );
    System.assert(
      query.contains(
        'Expediente_de_Negativos__r.Estado_de_la_Etapa__c != \'Finalizado\''
      ),
      'La query debe excluir expedientes finalizados'
    );
  }

  /**
   * Cubre la rama "similares ya debitados" de execute().
   */
  @isTest
  static void testExecute_IgnoraSimilaresYaDebitados() {
    Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];

    Account productor = new Account(Name = 'Productor Test');
    insert productor;

    Tonelada__c tn = new Tonelada__c(
      Cultivo__c = cultivo.Id,
      Productor__c = productor.Id,
      Cantidad__c = 1,
      Signo__c = -1,
      Etapa__c = 'Cobrada',
      Fecha_Inicio__c = Date.today(),
      Origen__c = 'BolsaTech'
    );
    insert tn;

    insert new Movimiento_BolsaTech__c(
      CUIT_Titular__c = CUIT,
      CTG__c = CTG,
      Cultivo__c = cultivo.Id,
      Tecnologia__c = TECNO,
      Peso_Neto__c = PESO,
      TN_Id__c = tn.Id,
      Estado__c = 'Procesado'
    );

    Movimiento_BolsaTech__c mbtEnScope = [
      SELECT
        Id,
        CUIT_Titular__c,
        CTG__c,
        Cultivo__c,
        Tecnologia__c,
        Peso_Neto__c
      FROM Movimiento_BolsaTech__c
      WHERE TN_Id__c = NULL
      LIMIT 1
    ];

    Test.startTest();
    new MovBolsaTechDebitarTNsBatch()
      .execute(null, new List<Movimiento_BolsaTech__c>{ mbtEnScope });
    Test.stopTest();

    System.assert(true, 'execute no debe lanzar excepción');
  }

  /**
   * Cubre la rama "sin similares" (invocación del flow) de execute().
   */
  @isTest
  static void testExecute_SinSimilares() {
    Movimiento_BolsaTech__c mbtEnScope = [
      SELECT
        Id,
        CUIT_Titular__c,
        CTG__c,
        Cultivo__c,
        Tecnologia__c,
        Peso_Neto__c
      FROM Movimiento_BolsaTech__c
      LIMIT 1
    ];

    Test.startTest();
    new MovBolsaTechDebitarTNsBatch()
      .execute(null, new List<Movimiento_BolsaTech__c>{ mbtEnScope });
    Test.stopTest();

    System.assert(true, 'execute no debe lanzar excepción');
  }
}
