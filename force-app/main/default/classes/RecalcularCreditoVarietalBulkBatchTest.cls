/**
 * Test del backfill bulkificado (RecalcularCreditoVarietalBulkBatch):
 * 5 HT x 4 t = crédito y saldo de 20 t.
 */
@isTest
private class RecalcularCreditoVarietalBulkBatchTest {
  @isTest
  static void testRecalculaCreditoYSaldo() {
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

    Variedad__c variedad = new Variedad__c(
      Name = 'TIPABULK',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert variedad;

    Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 5,
      Signo__c = 1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Cobrada',
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert ht;

    Id campaniaReal = [
      SELECT Campania__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :ht.Id
    ]
    .Campania__c;

    insert new Cuenta_Granaria__c(
      Productor__c = productor.Id,
      Campania__c = campaniaReal,
      Cultivo__c = cultivo.Id,
      Tecnologia__c = 'RR1/RR2 - BT/Convencional',
      Clave_Unica__c = productor.Id +
        '|' +
        campaniaReal +
        '|' +
        cultivo.Id +
        '|RR1/RR2 - BT/Convencional'
    );

    Test.startTest();
    Database.executeBatch(new RecalcularCreditoVarietalBulkBatch(), 50);
    Test.stopTest();

    Detalle_Variedad_CG__c detalle = [
      SELECT Credito_Variedad__c, Saldo_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Variedad__c = :variedad.Id
      LIMIT 1
    ];
    System.assertEquals(
      20,
      detalle.Credito_Variedad__c,
      'El crédito debe ser 20 (5 HT x 4 t)'
    );
    System.assertEquals(
      20,
      detalle.Saldo_Variedad__c,
      'El saldo debe ser 20 (crédito 20 + débito 0)'
    );
  }

  /**
   * Verifica el débito del escáner varietal y que actualice (no duplique) el
   * Detalle_Variedad_CG__c existente.
   */
  @isTest
  static void testDebitoActualizaDetalle() {
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

    Variedad__c variedad = new Variedad__c(
      Name = 'TIPABULK2',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
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

    Detalle_Variedad_CG__c detalle = new Detalle_Variedad_CG__c(
      Cuenta_Granaria__c = cg.Id,
      Variedad__c = variedad.Id,
      Clave_Varietal__c = cg.Id + '|' + variedad.Id,
      Credito_Variedad__c = 0,
      Saldo_Variedad__c = 0
    );
    insert detalle;

    insert new Tonelada__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Cuenta_Granaria__c = cg.Id,
      Origen__c = 'Escáner varietal',
      Cantidad__c = 13,
      Signo__c = -1,
      Etapa__c = 'Cobrada',
      Fecha_Inicio__c = Date.today(),
      Fecha_Fin__c = Date.today().addDays(300)
    );

    Test.startTest();
    Database.executeBatch(new RecalcularCreditoVarietalBulkBatch(), 50);
    Test.stopTest();

    Detalle_Variedad_CG__c d = [
      SELECT Id, Saldo_Variedad__c, Credito_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Id = :detalle.Id
    ];
    System.assertEquals(
      -13,
      d.Saldo_Variedad__c,
      'Saldo = crédito 0 + débito -13'
    );
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Detalle_Variedad_CG__c
        WHERE Cuenta_Granaria__c = :cg.Id
      ],
      'No debe duplicar el detalle existente'
    );
  }

  /**
   * Verifica la devolución por NC (usa la variedad de la original) y el
   * reseteo de un detalle que queda sin crédito ni débito.
   */
  @isTest
  static void testDevolucionYReseteo() {
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

    Variedad__c variedadA = new Variedad__c(
      Name = 'TIPABULK_A',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    Variedad__c variedadB = new Variedad__c(
      Name = 'TIPABULK_B',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert new List<Variedad__c>{ variedadA, variedadB };

    Hectareas_Tecnologicas__c htCancelada = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedadA.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 3,
      Signo__c = 1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Cancelada por NC',
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert htCancelada;

    Hectareas_Tecnologicas__c htAplicada = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedadB.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 1,
      Signo__c = -1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Aplicada',
      HT_Original__c = htCancelada.Id,
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert htAplicada;

    Id campaniaReal = [
      SELECT Campania__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :htCancelada.Id
    ]
    .Campania__c;

    Cuenta_Granaria__c cg = new Cuenta_Granaria__c(
      Productor__c = productor.Id,
      Campania__c = campaniaReal,
      Cultivo__c = cultivo.Id,
      Tecnologia__c = 'RR1/RR2 - BT/Convencional',
      Clave_Unica__c = productor.Id +
        '|' +
        campaniaReal +
        '|' +
        cultivo.Id +
        '|RR1/RR2 - BT/Convencional'
    );
    insert cg;

    // Detalle de variedadB que quedará sin crédito ni débito → se resetea.
    Detalle_Variedad_CG__c detalleB = new Detalle_Variedad_CG__c(
      Cuenta_Granaria__c = cg.Id,
      Variedad__c = variedadB.Id,
      Clave_Varietal__c = cg.Id + '|' + variedadB.Id,
      Credito_Variedad__c = 100,
      Saldo_Variedad__c = 100
    );
    insert detalleB;

    Test.startTest();
    Database.executeBatch(new RecalcularCreditoVarietalBulkBatch(), 50);
    Test.stopTest();

    Detalle_Variedad_CG__c dB = [
      SELECT Id, Saldo_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Id = :detalleB.Id
    ];
    System.assertEquals(
      0,
      dB.Saldo_Variedad__c,
      'El detalle sin crédito ni débito debe resetearse a 0'
    );

    Detalle_Variedad_CG__c dA = [
      SELECT Credito_Variedad__c, Saldo_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Variedad__c = :variedadA.Id
      LIMIT 1
    ];
    System.assertEquals(
      8,
      dA.Credito_Variedad__c,
      'Crédito variedad A = cancelada 12 - devolución 4 = 8'
    );
  }

  /**
   * Cubre start() y finish() del batch.
   */
  @isTest
  static void testStartYFinish() {
    Test_TestUtils.disableFlows();
    RecalcularCreditoVarietalBulkBatch b = new RecalcularCreditoVarietalBulkBatch();

    Test.startTest();
    Database.QueryLocator ql = b.start(null);
    b.finish(null);
    Test.stopTest();

    System.assertNotEquals(null, ql, 'El QueryLocator no debe ser null');
  }
}
