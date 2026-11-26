/**
 * Tests del trigger tg_Hectareas_Tecnologicas_Recrear_Tonelada (after undelete):
 * al restaurar una HT desde la papelera se debe recrear su Tonelada__c.
 */
@isTest
private class HtToneladaRecreadorTriggerTest {
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

    insert new Variedad__c(
      Name = 'VAR TEST',
      Cultivar_Inase__c = 'VAR TEST',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
  }

  @isTest
  static void undeleteRecreaTonelada() {
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
      Cantidad__c = 20000,
      Valor_Conversion__c = 1,
      Fecha_Fin__c = Date.newInstance(2025, 3, 10)
    );
    insert ht;

    Test.startTest();
    delete ht;
    undelete ht;
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Tonelada__c WHERE HT_Id__c = :ht.Id],
      'Debe recrear la Tonelada al restaurar la HT desde la papelera'
    );
  }
}
