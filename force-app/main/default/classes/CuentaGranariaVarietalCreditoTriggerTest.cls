/**
 * Tests del trigger CuentaGranariaVarietalCreditoTrigger (after insert/update/
 * delete/undelete sobre Hectareas_Tecnologicas__c): recalcula el crédito
 * varietal de la Cuenta Granaria cuando cambia una HT de cultivo varietal.
 */
@isTest
private class CuentaGranariaVarietalCreditoTriggerTest {
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
    // SE dates en el pasado para que el flow "HT_Asignar_Campa_a" no pise la
    // Campania__c de la HT a null (así el trigger encuentra la CG por campaña).
    campana.Fecha_Inicio_SE__c = Date.today().addDays(-100);
    campana.Fecha_Fin_SE__c = Date.today().addDays(-50);
    update campana;

    Account productor = Test_TestUtils.crearProductor();

    insert new Variedad__c(
      Name = 'CATALPA',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );

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
  }

  private static Hectareas_Tecnologicas__c insertarHt() {
    Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
    Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c LIMIT 1];
    Account productor = [SELECT Id FROM Account LIMIT 1];
    Variedad__c variedad = [SELECT Id FROM Variedad__c LIMIT 1];

    Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Origen__c = 'Compra HT',
      Signo__c = 1,
      Etapa__c = 'Cobrada',
      Cantidad__c = 5,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert ht;
    return ht;
  }

  @isTest
  static void afterInsertCreaDetalle() {
    Variedad__c variedad = [SELECT Id FROM Variedad__c LIMIT 1];

    Test.startTest();
    insertarHt();
    Test.stopTest();

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Detalle_Variedad_CG__c
        WHERE Variedad__c = :variedad.Id
      ],
      'Debe crear el Detalle al insertar una HT de cultivo varietal'
    );
  }

  @isTest
  static void afterDeleteReseteaDetalle() {
    Variedad__c variedad = [SELECT Id FROM Variedad__c LIMIT 1];
    Hectareas_Tecnologicas__c ht = insertarHt();

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Detalle_Variedad_CG__c
        WHERE Variedad__c = :variedad.Id
      ],
      'Debe existir el Detalle tras insertar la HT'
    );

    Test.startTest();
    delete ht;
    Test.stopTest();

    List<Detalle_Variedad_CG__c> detalles = [
      SELECT Credito_Variedad__c, Saldo_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Variedad__c = :variedad.Id
    ];
    System.assertEquals(
      1,
      detalles.size(),
      'El Detalle no se borra, se resetea'
    );
    System.assertEquals(
      0,
      detalles[0].Credito_Variedad__c,
      'Al borrar la HT el crédito queda en 0'
    );
  }
}
