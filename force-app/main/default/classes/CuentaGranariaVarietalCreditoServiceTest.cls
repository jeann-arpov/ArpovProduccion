/**
 * Tests del servicio de crédito varietal: vínculo de HT a Detalle,
 * acreditación de toneladas de crédito y cálculo de crédito por etapa.
 */
@isTest
private class CuentaGranariaVarietalCreditoServiceTest {
  /**
   * Verifica que recalcularCreditos vincule la HT de crédito a su Detalle_Variedad_CG.
   */
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
      Clave_Unica__c = productor.Id +
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

  /**
   * Verifica que acreditarToneladasCredito vincule a la CG solo las toneladas
   * en etapa de crédito (Cobrada), sin modificar etapa y dejando Pendiente fuera.
   */
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
      Clave_Unica__c = productor.Id +
        '|' +
        campana.Id +
        '|' +
        cultivo.Id +
        '|RR1/RR2 - BT/Convencional'
    );

    Tonelada__c tnCobrada = new Tonelada__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Biotecnologia__c = 'Convencional',
      Origen__c = 'Compra SF',
      Cantidad__c = 20,
      Signo__c = 1,
      Etapa__c = 'Cobrada',
      Fecha_Inicio__c = Date.today().addDays(-1),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    Tonelada__c tnPendiente = new Tonelada__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Biotecnologia__c = 'Convencional',
      Origen__c = 'Compra SF',
      Cantidad__c = 8,
      Signo__c = -1,
      Etapa__c = 'Pendiente',
      Fecha_Inicio__c = Date.today().addDays(-1),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert new List<Tonelada__c>{ tnCobrada, tnPendiente };

    Test.startTest();
    CuentaGranariaVarietalCreditoService.acreditarToneladasCredito(
      new List<Tonelada__c>{ tnCobrada, tnPendiente }
    );
    Test.stopTest();

    Tonelada__c tnCobradaActualizada = [
      SELECT Id, Cuenta_Granaria__c, Etapa__c
      FROM Tonelada__c
      WHERE Id = :tnCobrada.Id
    ];
    System.assertNotEquals(
      null,
      tnCobradaActualizada.Cuenta_Granaria__c,
      'La tonelada Cobrada debe quedar vinculada a la CG'
    );
    System.assertEquals(
      'Cobrada',
      tnCobradaActualizada.Etapa__c,
      'La tonelada Cobrada debe conservar su etapa'
    );

    Tonelada__c tnPendienteActualizada = [
      SELECT Id, Cuenta_Granaria__c, Etapa__c
      FROM Tonelada__c
      WHERE Id = :tnPendiente.Id
    ];
    System.assertEquals(
      null,
      tnPendienteActualizada.Cuenta_Granaria__c,
      'La tonelada no Cobrada no debe vincularse a la CG'
    );
    System.assertEquals(
      'Pendiente',
      tnPendienteActualizada.Etapa__c,
      'La tonelada no Cobrada no debe forzarse a Cobrada'
    );
  }

  /**
   * Solo la HT Cobrada acredita. Cancelada por NC y Aplicada no participan.
   */
  @isTest
  static void testCalcularCreditoPorEtapa() {
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
      Name = 'TIPATEST3',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert variedad;

    Hectareas_Tecnologicas__c htCobrada = new Hectareas_Tecnologicas__c(
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
    insert htCobrada;

    Hectareas_Tecnologicas__c htCancelada = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 3,
      Signo__c = 1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Cancelada por NC',
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert htCancelada;

    Hectareas_Tecnologicas__c htAplicadaRelacionada = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 1,
      Signo__c = -1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Aplicada',
      HT_Original__c = htCancelada.Id,
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert htAplicadaRelacionada;

    Hectareas_Tecnologicas__c htAplicadaSuelta = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 2,
      Signo__c = -1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Aplicada',
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert htAplicadaSuelta;

    Hectareas_Tecnologicas__c relCheck = [
      SELECT Etapa__c, HT_Original__c, HT_Original__r.Etapa__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :htAplicadaRelacionada.Id
    ];
    System.assertEquals(
      'Aplicada',
      relCheck.Etapa__c,
      'La HT de devolución debe quedar en Aplicada'
    );
    System.assertEquals(
      'Cancelada por NC',
      relCheck.HT_Original__r.Etapa__c,
      'La original debe quedar en Cancelada por NC'
    );

    Id campaniaReal = [
      SELECT Campania__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :htCobrada.Id
    ]
    .Campania__c;

    Hectareas_Tecnologicas__c aplicadaCampania = [
      SELECT Campania__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :htAplicadaRelacionada.Id
    ];
    System.assertEquals(
      campaniaReal,
      aplicadaCampania.Campania__c,
      'La Aplicada debe tener la misma Campania que la Cobrada'
    );

    insert new Cuenta_Granaria__c(
      Productor__c = productor.Id,
      Campania__c = campaniaReal,
      Cultivo__c = cultivo.Id,
      Tecnologia__c = 'RR1/RR2 - BT/Convencional',
      Clave_Unica__c = productor.Id +
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

    Detalle_Variedad_CG__c detalle = [
      SELECT Credito_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Variedad__c = :variedad.Id
      LIMIT 1
    ];
    System.assertEquals(
      20,
      detalle.Credito_Variedad__c,
      'Solo la Cobrada acredita (20 t). Cancelada por NC y Aplicada no suman ni restan dos veces'
    );
  }

  /**
   * obtenerCreditos lista solo compras cobradas (sin Cancelada por NC ni Aplicada).
   */
  @isTest
  static void testObtenerCreditos() {
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

    Variedad__c variedadA = new Variedad__c(
      Name = 'TIPA A',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    Variedad__c variedadB = new Variedad__c(
      Name = 'TIPA B',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert new List<Variedad__c>{ variedadA, variedadB };

    Hectareas_Tecnologicas__c htCobrada = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedadA.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 5,
      Signo__c = 1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Cobrada',
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert htCobrada;

    Hectareas_Tecnologicas__c htCancelada = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedadA.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 3,
      Signo__c = 1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Cancelada por NC',
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert htCancelada;

    // Devolución: variedad propia B, pero HT_Original apunta a la cancelada (variedad A)
    Hectareas_Tecnologicas__c htAplicada = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedadB.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 1,
      Signo__c = -1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Aplicada',
      HT_Original__c = htCancelada.Id,
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert htAplicada;

    Id campaniaReal = [
      SELECT Campania__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :htCobrada.Id
    ]
    .Campania__c;

    Test.startTest();
    List<CuentaGranariaVarietalCreditoService.CreditoVariedad> creditos = CuentaGranariaVarietalCreditoService.obtenerCreditos(
      productor.Id,
      cultivo.Id,
      campaniaReal
    );
    Test.stopTest();

    System.assertEquals(
      1,
      creditos.size(),
      'Solo la compra Cobrada aparece; Cancelada por NC y Aplicada no van a la lista'
    );
    System.assertEquals(
      variedadA.Id,
      creditos[0].variedadId,
      'El crédito vigente usa su propia variedad'
    );
    System.assertEquals(
      20,
      creditos[0].toneladas,
      'toneladas = Toneladas (20) * Signo (1)'
    );
  }

  @isTest
  static void testB01AcreditaAlCrearCgDespuesDeLaHt() {
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
      Name = 'TIPA B01',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert variedad;

    insert new Hectareas_Tecnologicas__c(
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

    Test.startTest();
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
    Hectareas_Tecnologicas__c htAntes = [
      SELECT Id, Campania__c
      FROM Hectareas_Tecnologicas__c
      WHERE Variedad__c = :variedad.Id
      LIMIT 1
    ];
    if (htAntes.Campania__c == null) {
      htAntes.Campania__c = campana.Id;
      update htAntes;
    }
    CuentaGranariaVarietalCreditoService.recalcularCreditos(
      productor.Id,
      cultivo.Id,
      campana.Id
    );
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
      'B-01: al crear la CG después de la HT, TIPA queda en 20 t'
    );

    Hectareas_Tecnologicas__c ht = [
      SELECT Detalle_Variedad_CG__c
      FROM Hectareas_Tecnologicas__c
      WHERE Variedad__c = :variedad.Id
      LIMIT 1
    ];
    System.assertNotEquals(
      null,
      ht.Detalle_Variedad_CG__c,
      'B-01: la HT queda vinculada al Detalle'
    );
  }

  @isTest
  static void testB02PendienteYNcSalenDeHtsDeCredito() {
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
      Name = 'TIPA B02',
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

    Hectareas_Tecnologicas__c cobrada = nuevaHt(
      productor.Id,
      cultivo.Id,
      campana.Id,
      variedad.Id,
      'Compra HT',
      'Cobrada'
    );
    Hectareas_Tecnologicas__c pendiente = nuevaHt(
      productor.Id,
      cultivo.Id,
      campana.Id,
      variedad.Id,
      'Compra HT',
      'Pendiente'
    );
    insert new List<Hectareas_Tecnologicas__c>{ cobrada, pendiente };

    Test.startTest();
    pendiente.Etapa__c = 'Cancelada por NC';
    update pendiente;
    Test.stopTest();

    Map<Id, Hectareas_Tecnologicas__c> porId = new Map<Id, Hectareas_Tecnologicas__c>(
      [
        SELECT Id, Etapa__c, Detalle_Variedad_CG__c
        FROM Hectareas_Tecnologicas__c
        WHERE Id IN :new Set<Id>{ cobrada.Id, pendiente.Id }
      ]
    );
    System.assertNotEquals(
      null,
      porId.get(cobrada.Id).Detalle_Variedad_CG__c,
      'B-02: la Cobrada sigue en HTs de Crédito'
    );
    System.assertEquals(
      null,
      porId.get(pendiente.Id).Detalle_Variedad_CG__c,
      'B-02: Pendiente / Cancelada por NC sale de HTs de Crédito'
    );
  }

  @isTest
  static void testB05PendienteACobradaSincronizaTonelada() {
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
      Name = 'TIPA B05',
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

    Hectareas_Tecnologicas__c ht = nuevaHt(
      productor.Id,
      cultivo.Id,
      campana.Id,
      variedad.Id,
      'Compra HT',
      'Pendiente'
    );
    insert ht;

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
      HT_Id__c = ht.Id,
      Fecha_Inicio__c = Date.today().addDays(-1),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert tn;
    ht.TN_Id__c = tn.Id;
    update ht;

    Test.startTest();
    ht.Etapa__c = 'Cobrada';
    update ht;
    Test.stopTest();

    Tonelada__c tnAct = [
      SELECT Etapa__c, Cuenta_Granaria__c
      FROM Tonelada__c
      WHERE Id = :tn.Id
    ];
    System.assertEquals(
      'Cobrada',
      tnAct.Etapa__c,
      'B-05: la tonelada pasa a Cobrada con la HT'
    );
    System.assertNotEquals(
      null,
      tnAct.Cuenta_Granaria__c,
      'B-05: la tonelada queda asignada a la CG'
    );
  }

  @isTest
  static void testB06CompraSfVinculaYNcRevierte() {
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
      Name = 'TIPA B06',
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

    Hectareas_Tecnologicas__c ht = nuevaHt(
      productor.Id,
      cultivo.Id,
      campana.Id,
      variedad.Id,
      'Compra SF',
      'Cobrada'
    );
    insert ht;

    Hectareas_Tecnologicas__c htCobrada = [
      SELECT Detalle_Variedad_CG__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :ht.Id
    ];
    System.assertNotEquals(
      null,
      htCobrada.Detalle_Variedad_CG__c,
      'B-06: Compra SF cobrada se vincula al Detalle'
    );

    Test.startTest();
    ht.Etapa__c = 'Cancelada por NC';
    update ht;
    Test.stopTest();

    Hectareas_Tecnologicas__c htNc = [
      SELECT Detalle_Variedad_CG__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :ht.Id
    ];
    System.assertEquals(
      null,
      htNc.Detalle_Variedad_CG__c,
      'B-06: al cancelar por NC sale de HTs de Crédito'
    );
    System.assertEquals(
      0,
      [
        SELECT Credito_Variedad__c
        FROM Detalle_Variedad_CG__c
        WHERE Variedad__c = :variedad.Id
        LIMIT 1
      ]
      .Credito_Variedad__c,
      'B-06: el crédito de Compra SF se revierte'
    );
  }

  /**
   * SE-392 CP-01 / SE-410: NC total. Tres compras Canceladas por NC con
   * tonelada en la CG, dos NC Aplicadas y una NC sin tonelada. El crédito
   * no suma esas toneladas: queda 0 / 0.
   */
  @isTest
  static void testCp01NcTotalSinToneladaDejaCreditoEnCero() {
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
      Name = 'TIPA CP01',
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

    Hectareas_Tecnologicas__c primera = nuevaHt(
      productor.Id,
      cultivo.Id,
      campana.Id,
      variedad.Id,
      'Compra HT',
      'Cobrada'
    );
    insert primera;
    CuentaGranariaVarietalCreditoService.recalcularCreditos(
      productor.Id,
      cultivo.Id,
      campana.Id
    );
    primera.Etapa__c = 'Cancelada por NC';
    update primera;

    List<Hectareas_Tecnologicas__c> otrasCanceladas = new List<Hectareas_Tecnologicas__c>{
      nuevaHt(productor.Id, cultivo.Id, campana.Id, variedad.Id, 'Compra HT', 'Cancelada por NC'),
      nuevaHt(productor.Id, cultivo.Id, campana.Id, variedad.Id, 'Compra HT', 'Cancelada por NC')
    };
    List<Hectareas_Tecnologicas__c> aplicadas = new List<Hectareas_Tecnologicas__c>();
    for (Integer i = 0; i < 2; i++) {
      Hectareas_Tecnologicas__c nc = nuevaHt(
        productor.Id,
        cultivo.Id,
        campana.Id,
        variedad.Id,
        'Compra HT',
        'Aplicada'
      );
      nc.Signo__c = -1;
      aplicadas.add(nc);
    }
    Hectareas_Tecnologicas__c ncSinTonelada = nuevaHt(
      productor.Id,
      cultivo.Id,
      campana.Id,
      variedad.Id,
      'Compra HT',
      'Aplicada'
    );
    ncSinTonelada.Signo__c = -1;
    List<Hectareas_Tecnologicas__c> htsNuevas = new List<Hectareas_Tecnologicas__c>();
    htsNuevas.addAll(otrasCanceladas);
    htsNuevas.addAll(aplicadas);
    htsNuevas.add(ncSinTonelada);
    insert htsNuevas;

    List<Hectareas_Tecnologicas__c> canceladas = new List<Hectareas_Tecnologicas__c>{
      primera
    };
    canceladas.addAll(otrasCanceladas);

    List<Tonelada__c> toneladas = new List<Tonelada__c>();
    for (Hectareas_Tecnologicas__c ht : canceladas) {
      toneladas.add(
        nuevaTonelada(productor.Id, cultivo.Id, campana.Id, variedad.Id, cg.Id, ht.Id, 1, 'Cancelada por NC')
      );
    }
    for (Hectareas_Tecnologicas__c ht : aplicadas) {
      toneladas.add(
        nuevaTonelada(productor.Id, cultivo.Id, campana.Id, variedad.Id, cg.Id, ht.Id, -1, 'Aplicada')
      );
    }
    insert toneladas;

    Test.startTest();
    CuentaGranariaVarietalCreditoService.recalcularCreditos(
      productor.Id,
      cultivo.Id,
      campana.Id
    );
    Test.stopTest();

    Detalle_Variedad_CG__c detalle = [
      SELECT Credito_Variedad__c, Saldo_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Variedad__c = :variedad.Id
      LIMIT 1
    ];
    System.assertEquals(
      0,
      detalle.Credito_Variedad__c,
      'CP-01: sin compras Cobrada el crédito es 0, aunque queden toneladas canceladas en la CG'
    );
    System.assertEquals(
      0,
      detalle.Saldo_Variedad__c,
      'CP-01: el saldo del detalle queda 0 / 0'
    );
  }

  private static Tonelada__c nuevaTonelada(
    Id productorId,
    Id cultivoId,
    Id campanaId,
    Id variedadId,
    Id cgId,
    Id htId,
    Decimal signo,
    String etapa
  ) {
    return new Tonelada__c(
      Productor__c = productorId,
      Cultivo__c = cultivoId,
      Campania__c = campanaId,
      Variedad__c = variedadId,
      Cuenta_Granaria__c = cgId,
      HT_Id__c = htId,
      Biotecnologia__c = 'Convencional',
      Origen__c = 'Compra HT',
      Cantidad__c = 20,
      Signo__c = signo,
      Etapa__c = etapa,
      Fecha_Inicio__c = Date.today().addDays(-1),
      Fecha_Fin__c = Date.today().addDays(300)
    );
  }

  private static Hectareas_Tecnologicas__c nuevaHt(
    Id productorId,
    Id cultivoId,
    Id campanaId,
    Id variedadId,
    String origen,
    String etapa
  ) {
    return new Hectareas_Tecnologicas__c(
      Productor__c = productorId,
      Cultivo__c = cultivoId,
      Campania__c = campanaId,
      Variedad__c = variedadId,
      Origen__c = origen,
      Cantidad__c = 5,
      Signo__c = 1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = etapa,
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
  }
}
