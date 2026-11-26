/**
 * Tests del servicio de expedientes de negativos varietales: apertura con saldo
 * por debajo del umbral y cierre al regularizar.
 */
@isTest
private class CuentaGranariaVarietalExpedienteTest {
  /**
   * Datos base: cultivo, campaña, productor, variedad y sub-cuenta con saldo -20.
   */
  @testSetup
  static void setup() {
    Test_TestUtils.disableFlows();

    Cultivo__c cultivo = Test_TestUtils.crearCultivo('TRIGO', 1, true);
    Campana_Agricola__c campana = Test_TestUtils.crearCampanaAgricola(
      '2025',
      cultivo,
      Date.today().addDays(-10),
      Date.today().addDays(10),
      '2025 - TRIGO',
      true
    );

    Account productor = Test_TestUtils.crearProductor();
    productor.N_CUIT__c = '30502874353';
    update productor;

    Account obtentor = Test_TestUtils.crearObtentor();

    Variedad__c variedad = new Variedad__c(
      Name = 'CATALPA',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert variedad;

    Cuenta_Granaria__c cg = new Cuenta_Granaria__c(
      Productor__c = productor.Id,
      Campania__c = campana.Id,
      Cultivo__c = cultivo.Id,
      Tecnologia__c = 'RR1/RR2 - BT/Convencional',
      Clave_Unica__c = productor.Id +
        '|' +
        campana.Id +
        '|' +
        cultivo.Id +
        '|RR1/RR2 - BT/Convencional'
    );
    insert cg;

    insert new Detalle_Variedad_CG__c(
      Cuenta_Granaria__c = cg.Id,
      Variedad__c = variedad.Id,
      Clave_Varietal__c = cg.Id + '|' + variedad.Id,
      Saldo_Variedad__c = -20
    );
  }

  private static void habilitarExpedientes() {
    CuentaGranariaVarietalExpedienteService.forzarExpedientesHabilitados = true;
  }

  /**
   * Verifica que se abra un expediente con nombre EXP-<CUIT>... para la
   * sub-cuenta con saldo negativo.
   */
  @isTest
  static void testAperturaExpedienteVarietal() {
    Variedad__c variedad = [
      SELECT Id, Obtentor_Comercializa__c
      FROM Variedad__c
      LIMIT 1
    ];
    habilitarExpedientes();
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];

    Test.startTest();
    Integer creados = CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();
    Test.stopTest();

    System.assertEquals(1, creados);
    List<Expediente_de_Negativos__c> exps = [
      SELECT
        Id,
        Name,
        Detalle_Variedad_CG__c,
        Variedad__c,
        Obtentor__c,
        Estado_de_la_Etapa__c
      FROM Expediente_de_Negativos__c
      WHERE Detalle_Variedad_CG__c = :subCuenta.Id
    ];
    System.assertEquals(1, exps.size());
    System.assert(exps[0].Name.startsWith('EXP-30502874353'));
    System.assertEquals(variedad.Id, exps[0].Variedad__c);
    System.assertEquals(
      variedad.Obtentor_Comercializa__c,
      exps[0].Obtentor__c,
      'El expediente debe guardar el obtentor de la variedad'
    );
    System.assertEquals('No empezado', exps[0].Estado_de_la_Etapa__c);
  }

  /**
   * Verifica que al regularizar el saldo (>= umbral) el expediente se finalice.
   */
  @isTest
  static void testCierreExpedienteRegularizado() {
    habilitarExpedientes();
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];
    CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();

    subCuenta.Saldo_Variedad__c = 5;
    update subCuenta;

    Test.startTest();
    Integer cerrados = CuentaGranariaVarietalExpedienteService.cerrarExpedientesRegularizados();
    Test.stopTest();

    System.assertEquals(1, cerrados);
    Expediente_de_Negativos__c exp = [
      SELECT Estado_de_la_Etapa__c, Fecha_de_finalizacion__c
      FROM Expediente_de_Negativos__c
      WHERE Detalle_Variedad_CG__c = :subCuenta.Id
      LIMIT 1
    ];
    System.assertEquals('Finalizado', exp.Estado_de_la_Etapa__c);
    System.assertEquals(Date.today(), exp.Fecha_de_finalizacion__c);
  }

  @isTest
  static void testNoAbreConSaldoIgualAlUmbral() {
    habilitarExpedientes();
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];
    subCuenta.Saldo_Variedad__c = -4;
    update subCuenta;

    Test.startTest();
    Integer creados = CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();
    Test.stopTest();

    System.assertEquals(0, creados);
  }

  @isTest
  static void testNoAbreConSaldoSobreElUmbral() {
    habilitarExpedientes();
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];
    subCuenta.Saldo_Variedad__c = -3;
    update subCuenta;

    Test.startTest();
    Integer creados = CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();
    Test.stopTest();

    System.assertEquals(0, creados);
  }

  @isTest
  static void testCierraConSaldoIgualAlUmbral() {
    habilitarExpedientes();
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];
    subCuenta.Saldo_Variedad__c = -5;
    update subCuenta;

    CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();

    subCuenta.Saldo_Variedad__c = -4;
    update subCuenta;

    Test.startTest();
    Integer cerrados = CuentaGranariaVarietalExpedienteService.cerrarExpedientesRegularizados();
    Test.stopTest();

    System.assertEquals(1, cerrados);
  }

  /**
   * Cubre procesarAperturasYCierres (cierre + apertura en un solo paso).
   */
  @isTest
  static void testProcesarAperturasYCierres() {
    habilitarExpedientes();
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];

    Test.startTest();
    CuentaGranariaVarietalExpedienteService.ResultadoExpedientes apertura = CuentaGranariaVarietalExpedienteService.procesarAperturasYCierres();

    subCuenta.Saldo_Variedad__c = 5;
    update subCuenta;

    CuentaGranariaVarietalExpedienteService.ResultadoExpedientes cierre = CuentaGranariaVarietalExpedienteService.procesarAperturasYCierres();
    Test.stopTest();

    System.assertEquals(1, apertura.expedientesCreados);
    System.assertEquals(0, apertura.expedientesCerrados);
    System.assertEquals(0, cierre.expedientesCreados);
    System.assertEquals(1, cierre.expedientesCerrados);
  }

  /**
   * No abre un segundo expediente si la sub-cuenta ya tiene uno activo.
   */
  @isTest
  static void testNoDuplicaExpedienteActivo() {
    habilitarExpedientes();
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];

    Test.startTest();
    Integer primeros = CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();
    Integer segundos = CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();
    Test.stopTest();

    System.assertEquals(1, primeros);
    System.assertEquals(0, segundos);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Expediente_de_Negativos__c
        WHERE Detalle_Variedad_CG__c = :subCuenta.Id
      ],
      'No debe duplicar el expediente activo'
    );
  }

  /**
   * Cubre cerrarExpedientesRegularizadosPorSubCuentas (null, vacío y dirigido).
   */
  @isTest
  static void testCerrarExpedientesRegularizadosPorSubCuentas() {
    habilitarExpedientes();
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];
    CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();

    Test.startTest();
    Integer vacio1 = CuentaGranariaVarietalExpedienteService.cerrarExpedientesRegularizadosPorSubCuentas(
      null
    );
    Integer vacio2 = CuentaGranariaVarietalExpedienteService.cerrarExpedientesRegularizadosPorSubCuentas(
      new Set<Id>()
    );

    subCuenta.Saldo_Variedad__c = 5;
    update subCuenta;

    Integer cerrados = CuentaGranariaVarietalExpedienteService.cerrarExpedientesRegularizadosPorSubCuentas(
      new Set<Id>{ subCuenta.Id }
    );
    Test.stopTest();

    System.assertEquals(0, vacio1);
    System.assertEquals(0, vacio2);
    System.assertEquals(1, cerrados);
  }

  /**
   * Al abrir el expediente, la Tonelada de débito de la sub-cuenta debe quedar
   * vinculada al expediente (Tonelada__c.Expediente_de_Negativos__c).
   */
  @isTest
  static void testVincularToneladaAlExpediente() {
    Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
    Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c LIMIT 1];
    Account productor = [SELECT Id FROM Account LIMIT 1];
    Variedad__c variedad = [SELECT Id FROM Variedad__c LIMIT 1];
    Cuenta_Granaria__c cg = [SELECT Id FROM Cuenta_Granaria__c LIMIT 1];
    habilitarExpedientes();
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];

    Tonelada__c tn = new Tonelada__c(
      Productor__c = productor.Id,
      Campania__c = campana.Id,
      Cultivo__c = cultivo.Id,
      Variedad__c = variedad.Id,
      Detalle_Variedad_CG__c = subCuenta.Id,
      Cuenta_Granaria__c = cg.Id,
      Origen__c = 'Escáner varietal',
      Signo__c = -1,
      Cantidad__c = 10,
      Etapa__c = 'Cobrada',
      Fecha_Inicio__c = Date.today()
    );
    insert tn;

    Test.startTest();
    Integer creados = CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();
    Test.stopTest();

    System.assertEquals(1, creados, 'Debe abrir el expediente');
    Tonelada__c tnActualizada = [
      SELECT Expediente_de_Negativos__c
      FROM Tonelada__c
      WHERE Id = :tn.Id
    ];
    System.assertNotEquals(
      null,
      tnActualizada.Expediente_de_Negativos__c,
      'La Tonelada debe quedar vinculada al expediente de negativos'
    );
  }
}
