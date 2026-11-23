@isTest
private class HtToneladaRecreadorTest {
  @isTest
  static void recreaToneladaAlRestaurarHt() {
    Test_TestUtils.disableFlows();

    Cultivo__c cultivo = new Cultivo__c(
      Name = 'TRIGO',
      Densidad_de_Siembra__c = 75
    );
    insert cultivo;

    Account productor = Test_TestUtils.crearProductor();

    Variedad__c variedad = new Variedad__c(
      Name = 'VAR TEST',
      Cultivar_Inase__c = 'VAR TEST',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert variedad;

    Campana_Agricola__c campana = new Campana_Agricola__c(
      Name = 'Campana Test 25/26',
      Ano__c = '2025',
      Cultivo__c = cultivo.Id
    );
    insert campana;

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
      Fecha_Fin__c = Date.today()
    );
    insert ht;

    Test.startTest();
    HtToneladaRecreador.recrearToneladas(
      new List<Hectareas_Tecnologicas__c>{ ht }
    );
    Test.stopTest();

    List<Tonelada__c> toneladas = [
      SELECT Id, HT_Id__c, Origen__c, Signo__c, Etapa__c
      FROM Tonelada__c
      WHERE HT_Id__c = :ht.Id
    ];
    System.assertEquals(1, toneladas.size(), 'Debe recrear una tonelada');
    System.assertEquals('Compra HT', toneladas[0].Origen__c);
    System.assertEquals(1, toneladas[0].Signo__c);
  }

  @isTest
  static void noRecreaToneladaParaPph() {
    Test_TestUtils.disableFlows();

    Cultivo__c cultivo = new Cultivo__c(
      Name = 'SOJA',
      Densidad_de_Siembra__c = 75
    );
    insert cultivo;

    Account productor = Test_TestUtils.crearProductor();

    Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Origen__c = 'PPH',
      Signo__c = 1,
      Etapa__c = 'Cobrada',
      Cantidad__c = 10000,
      Valor_Conversion__c = 1,
      Fecha_Fin__c = Date.today()
    );
    insert ht;

    Test.startTest();
    HtToneladaRecreador.recrearToneladas(
      new List<Hectareas_Tecnologicas__c>{ ht }
    );
    Test.stopTest();

    List<Tonelada__c> toneladas = [
      SELECT Id
      FROM Tonelada__c
      WHERE HT_Id__c = :ht.Id
    ];
    System.assertEquals(0, toneladas.size(), 'PPH no debe generar tonelada');
  }
}
