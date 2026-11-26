/**
 * Tests del trigger de crédito varietal (CuentaGranariaVarietalCreditoTrigger
 * sobre Hectareas_Tecnologicas__c): al insertar una HT, el recálculo toma el
 * crédito de las Toneladas de crédito (Compra HT / Compra SF) de la campaña.
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

  @isTest
  static void calculaCreditoDesdeToneladaAlInsertarHt() {
    Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
    Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c LIMIT 1];
    Account productor = [SELECT Id FROM Account LIMIT 1];
    Variedad__c variedad = [SELECT Id FROM Variedad__c LIMIT 1];

    insert new Tonelada__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Biotecnologia__c = 'Convencional',
      Origen__c = 'Compra HT',
      Cantidad__c = 20,
      Signo__c = 1,
      Etapa__c = 'Cobrada',
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );

    Test.startTest();
    insert new Hectareas_Tecnologicas__c(
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
    Test.stopTest();

    Detalle_Variedad_CG__c detalle = [
      SELECT Credito_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Variedad__c = :variedad.Id
      LIMIT 1
    ];
    System.assertEquals(
      20,
      detalle.Credito_Variedad__c,
      'El crédito debe salir de la Tonelada de crédito al recalcular por la HT'
    );
  }
}
