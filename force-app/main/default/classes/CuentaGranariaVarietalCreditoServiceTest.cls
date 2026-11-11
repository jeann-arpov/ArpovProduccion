@isTest
private class CuentaGranariaVarietalCreditoServiceTest {
  @isTest
  static void testVincularHtAlDetalleVariedad() {
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
      Name = 'TIPATEST',
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
    CuentaGranariaVarietalCreditoService.recalcularCreditos(
      productor.Id,
      cultivo.Id,
      campaniaReal
    );
    Test.stopTest();

    Hectareas_Tecnologicas__c htActualizada = [
      SELECT Id, Detalle_Variedad_CG__c, Detalle_Variedad_CG__r.Variedad__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :ht.Id
    ];
    System.assertNotEquals(
      null,
      htActualizada.Detalle_Variedad_CG__c,
      'La HT debe quedar vinculada al Detalle_Variedad_CG'
    );
    System.assertEquals(
      variedad.Id,
      htActualizada.Detalle_Variedad_CG__r.Variedad__c,
      'El Detalle debe corresponder a la variedad de la HT'
    );
  }

  @isTest
  static void testAcreditarToneladasCredito() {
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
      Name = 'TIPATEST2',
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
      Clave_Unica__c =
        productor.Id +
        '|' +
        campana.Id +
        '|' +
        cultivo.Id +
        '|RR1/RR2 - BT/Convencional'
    );

    Tonelada__c tn = new Tonelada__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Biotecnologia__c = 'Convencional',
      Origen__c = 'Compra HT',
      Cantidad__c = 20,
      Signo__c = 1,
      Etapa__c = 'Pendiente',
      Fecha_Inicio__c = Date.today().addDays(-1),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert tn;

    Test.startTest();
    CuentaGranariaVarietalCreditoService.acreditarToneladasCredito(
      new List<Tonelada__c>{ tn }
    );
    Test.stopTest();

    Tonelada__c tnActualizada = [
      SELECT Id, Cuenta_Granaria__c, Etapa__c
      FROM Tonelada__c
      WHERE Id = :tn.Id
    ];
    System.assertNotEquals(
      null,
      tnActualizada.Cuenta_Granaria__c,
      'La tonelada debe quedar vinculada a la CG'
    );
    System.assertEquals(
      'Cobrada',
      tnActualizada.Etapa__c,
      'La tonelada debe quedar en etapa Cobrada'
    );
  }
}
