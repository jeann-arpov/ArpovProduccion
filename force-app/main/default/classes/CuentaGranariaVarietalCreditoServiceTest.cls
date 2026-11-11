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
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert ht;

    Test.startTest();
    CuentaGranariaVarietalCreditoService.recalcularCreditos(
      productor.Id,
      cultivo.Id,
      campana.Id
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
}
