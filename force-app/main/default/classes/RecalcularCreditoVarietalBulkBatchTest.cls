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
      Clave_Unica__c =
        productor.Id +
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
}
