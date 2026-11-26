/**
 * Test del scheduler de expedientes varietales: verifica que dispare la
 * apertura de expedientes de negativos (delega en
 * CuentaGranariaVarietalExpedienteService.procesarAperturasYCierres).
 */
@isTest
private class ScheduleVarietalExpedienteTest {
  @testSetup
  static void setup() {
    Test_TestUtils.disableFlows();

    Cultivo__c cultivo = Test_TestUtils.crearCultivo('TRIGO', 1, true);
    String anio = String.valueOf(Date.today().year());
    Campana_Agricola__c campana = Test_TestUtils.crearCampanaAgricola(
      anio,
      cultivo,
      Date.today().addDays(-10),
      Date.today().addDays(10),
      anio + ' - TRIGO',
      true
    );
    Account productor = Test_TestUtils.crearProductor();

    Variedad__c variedad = new Variedad__c(
      Name = 'CATALPA',
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

    insert new Detalle_Variedad_CG__c(
      Cuenta_Granaria__c = cg.Id,
      Variedad__c = variedad.Id,
      Clave_Varietal__c = cg.Id + '|' + variedad.Id,
      Saldo_Variedad__c = -20
    );
  }

  @isTest
  static void ejecutaAperturaDeExpedientes() {
    Test.startTest();
    new ScheduleCuentaGranariaVarietalExpediente().execute(null);
    Test.stopTest();

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Expediente_de_Negativos__c
        WHERE Detalle_Variedad_CG__c != NULL
      ],
      'Debe abrir el expediente de la sub-cuenta negativa'
    );
  }
}
