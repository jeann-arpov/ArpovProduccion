/**
 * Tests de HtToneladaRecreador: recreación de la Tonelada__c al restaurar una
 * HT desde la papelera (after undelete).
 *
 * Cubre el filtro PPH, la lista vacía/nula, el vínculo TN_Id__c y las ramas de
 * calcularFechaFin alcanzables sin Linea_de_Compra_HT__c (Compra SF, Semilla
 * Original, Semilla Pre Básica y el caso por defecto).
 */
@isTest
private class HtToneladaRecreadorTest {
  private static final Date FECHA_BASE = Date.newInstance(2025, 3, 10);

  @testSetup
  static void setup() {
    Test_TestUtils.disableFlows();

    Cultivo__c cultivo = Test_TestUtils.crearCultivo('TRIGO', 1, true);

    Account productor = Test_TestUtils.crearProductor();

    insert new Variedad__c(
      Name = 'VAR TEST',
      Cultivar_Inase__c = 'VAR TEST',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );

    insert new Campana_Agricola__c(
      Name = 'Campana Test',
      Ano__c = '2025',
      Cultivo__c = cultivo.Id
    );
  }

  private static Cultivo__c getCultivo() {
    return [SELECT Id FROM Cultivo__c LIMIT 1];
  }

  private static Account getProductor() {
    return [SELECT Id FROM Account LIMIT 1];
  }

  private static Variedad__c getVariedad() {
    return [SELECT Id FROM Variedad__c LIMIT 1];
  }

  private static Campana_Agricola__c getCampana() {
    return [SELECT Id FROM Campana_Agricola__c LIMIT 1];
  }

  private static Hectareas_Tecnologicas__c insertarHt(
    String origen,
    Date fechaFin
  ) {
    Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c(
      Productor__c = getProductor().Id,
      Cultivo__c = getCultivo().Id,
      Campania__c = getCampana().Id,
      Variedad__c = getVariedad().Id,
      Origen__c = origen,
      Signo__c = 1,
      Etapa__c = 'Cobrada',
      Cantidad__c = 20000,
      Valor_Conversion__c = 1,
      Fecha_Fin__c = fechaFin
    );
    insert ht;
    return ht;
  }

  private static Tonelada__c getTonelada(Id htId) {
    return [
      SELECT
        Id,
        HT_Id__c,
        Origen__c,
        Signo__c,
        Etapa__c,
        Fecha_Fin__c,
        Expediente_de_Negativos__c
      FROM Tonelada__c
      WHERE HT_Id__c = :htId
      LIMIT 1
    ];
  }

  private static Integer contarToneladas(Id htId) {
    return [SELECT COUNT() FROM Tonelada__c WHERE HT_Id__c = :htId];
  }

  @isTest
  static void recreaToneladaAlRestaurarHt() {
    Hectareas_Tecnologicas__c ht = insertarHt('Compra HT', FECHA_BASE);

    Test.startTest();
    HtToneladaRecreador.recrearToneladas(
      new List<Hectareas_Tecnologicas__c>{ ht }
    );
    Test.stopTest();

    Tonelada__c tn = getTonelada(ht.Id);
    System.assertEquals('Compra HT', tn.Origen__c, 'Debe copiar el origen');
    System.assertEquals(1, tn.Signo__c, 'Debe copiar el signo');
    System.assertEquals(
      Date.today(),
      tn.Fecha_Fin__c,
      'Compra HT sin línea (default) => Fecha_Fin = hoy'
    );

    Hectareas_Tecnologicas__c htActualizada = [
      SELECT TN_Id__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :ht.Id
    ];
    System.assertEquals(
      tn.Id,
      htActualizada.TN_Id__c,
      'Debe vincular TN_Id__c'
    );
  }

  @isTest
  static void noRecreaToneladaParaPph() {
    Hectareas_Tecnologicas__c ht = insertarHt('PPH', null);

    Test.startTest();
    HtToneladaRecreador.recrearToneladas(
      new List<Hectareas_Tecnologicas__c>{ ht }
    );
    Test.stopTest();

    System.assertEquals(
      0,
      contarToneladas(ht.Id),
      'PPH no debe generar tonelada'
    );
  }

  @isTest
  static void noRecreaConListaVacia() {
    Test.startTest();
    HtToneladaRecreador.recrearToneladas(null);
    HtToneladaRecreador.recrearToneladas(new List<Hectareas_Tecnologicas__c>());
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Tonelada__c],
      'No debe crear toneladas'
    );
  }

  @isTest
  static void recreaToneladaCompraSfConFechaFin() {
    Hectareas_Tecnologicas__c ht = insertarHt('Compra SF', FECHA_BASE);

    Test.startTest();
    HtToneladaRecreador.recrearToneladas(
      new List<Hectareas_Tecnologicas__c>{ ht }
    );
    Test.stopTest();

    Date esperado = Date.newInstance(
      FECHA_BASE.year() + 3,
      FECHA_BASE.month(),
      FECHA_BASE.day()
    );
    System.assertEquals(
      esperado,
      getTonelada(ht.Id).Fecha_Fin__c,
      'Compra SF => Fecha_Fin = año + 3'
    );
  }

  @isTest
  static void recreaToneladaCompraSfSinFechaFin() {
    Hectareas_Tecnologicas__c ht = insertarHt('Compra SF', null);

    Test.startTest();
    HtToneladaRecreador.recrearToneladas(
      new List<Hectareas_Tecnologicas__c>{ ht }
    );
    Test.stopTest();

    System.assertEquals(
      Date.today(),
      getTonelada(ht.Id).Fecha_Fin__c,
      'Compra SF sin Fecha_Fin => hoy'
    );
  }

  @isTest
  static void recreaToneladaSemillaOriginal() {
    Hectareas_Tecnologicas__c ht = insertarHt('Semilla Original', FECHA_BASE);

    Test.startTest();
    HtToneladaRecreador.recrearToneladas(
      new List<Hectareas_Tecnologicas__c>{ ht }
    );
    Test.stopTest();

    Date esperado = Date.newInstance(
      FECHA_BASE.year() + 1,
      FECHA_BASE.month(),
      FECHA_BASE.day()
    );
    System.assertEquals(
      esperado,
      getTonelada(ht.Id).Fecha_Fin__c,
      'Semilla Original => Fecha_Fin = año + 1'
    );
  }

  @isTest
  static void recreaToneladaSemillaPreBasica() {
    Hectareas_Tecnologicas__c ht = insertarHt('Semilla Pre Básica', FECHA_BASE);

    Test.startTest();
    HtToneladaRecreador.recrearToneladas(
      new List<Hectareas_Tecnologicas__c>{ ht }
    );
    Test.stopTest();

    Date esperado = Date.newInstance(
      FECHA_BASE.year() + 1,
      FECHA_BASE.month(),
      FECHA_BASE.day()
    );
    System.assertEquals(
      esperado,
      getTonelada(ht.Id).Fecha_Fin__c,
      'Semilla Pre Básica => Fecha_Fin = año + 1'
    );
  }

  @isTest
  static void recreaToneladaVinculadaAExpediente() {
    Account productor = getProductor();
    Expediente_de_Negativos__c exp = new Expediente_de_Negativos__c(
      Cuenta__c = productor.Id,
      Estado_de_la_Etapa__c = 'No empezado'
    );
    insert exp;

    Hectareas_Tecnologicas__c ht = insertarHt('Compra HT', FECHA_BASE);

    Test.startTest();
    HtToneladaRecreador.recrearToneladas(
      new List<Hectareas_Tecnologicas__c>{ ht }
    );
    Test.stopTest();

    System.assertEquals(
      exp.Id,
      getTonelada(ht.Id).Expediente_de_Negativos__c,
      'Debe vincular la tonelada al expediente abierto'
    );
  }
}
