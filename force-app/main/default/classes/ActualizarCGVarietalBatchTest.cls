@isTest
private class ActualizarCGVarietalBatchTest {
  @isTest
  static void testDebitoMarcaMbtProcesado() {
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

    Variedad__c variedad = new Variedad__c(
      Name = 'CATALPA',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert variedad;

    insert new Cuenta_Granaria__c(
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

    Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
      Estado__c = 'A procesar',
      Cultivo_Varietal__c = true,
      No_Debitar__c = false,
      Peso_Neto__c = 100000,
      Titular__c = productor.Id,
      Cultivo__c = 'TRIGO',
      Cosecha__c = '2025',
      Tecnologia__c = 'RR1/RR2 - BT/Convencional',
      CTG__c = '123',
      Codigo_de_Muestra__c = '123',
      Fecha_de_Analisis__c = '15/10/2023',
      CUIT_Titular__c = productor.N_CUIT__c,
      Cuit_Destinatario__c = productor.N_CUIT__c
    );
    insert mbt;

    insert new Detalle_Variedad_MBT__c(
      Movimiento_BolsaTech__c = mbt.Id,
      Variedad__c = variedad.Id,
      Porcentaje_Varietal__c = 100,
      Clave_Linea__c = mbt.Id + '|' + variedad.Id
    );

    Test.startTest();
    Database.executeBatch(new ActualizarCuentaGranariaVarietalBatch(), 200);
    Test.stopTest();

    Movimiento_BolsaTech__c procesado = [
      SELECT Estado__c, Cuenta_Granaria__c
      FROM Movimiento_BolsaTech__c
      WHERE Id = :mbt.Id
    ];
    System.assertEquals('Procesado', procesado.Estado__c);
    System.assertNotEquals(null, procesado.Cuenta_Granaria__c);

    List<Tonelada__c> debitos = [
      SELECT Id
      FROM Tonelada__c
      WHERE Origen__c = 'Escáner varietal' AND Mov_BolsaTech__c = :mbt.Id
    ];
    System.assertEquals(1, debitos.size());
  }
}
