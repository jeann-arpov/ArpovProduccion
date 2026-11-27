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
   * Solo la HT Cobrada acredita. Cancelada por NC y Aplicada no participan
   * (SE-392 CP-01).
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
      'Solo la Cobrada acredita (20 t). Cancelada por NC y Aplicada no suman ni restan'
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

  /**
   * SE-392 CP-01: NC total. Compras Canceladas por NC con tonelada en la CG
   * y una NC sin tonelada. El crédito no las suma: queda 0 / 0.
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

    Hectareas_Tecnologicas__c cobrada = new Hectareas_Tecnologicas__c(
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
    insert cobrada;
    CuentaGranariaVarietalCreditoService.recalcularCreditos(
      productor.Id,
      cultivo.Id,
      campana.Id
    );
    cobrada.Etapa__c = 'Cancelada por NC';
    update cobrada;

    Hectareas_Tecnologicas__c ncSinTonelada = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campana.Id,
      Variedad__c = variedad.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 5,
      Signo__c = -1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Aplicada',
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert ncSinTonelada;

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
      'CP-01: sin compras Cobrada el crédito es 0'
    );
    System.assertEquals(
      0,
      detalle.Saldo_Variedad__c,
      'CP-01: el saldo del detalle queda 0 / 0'
    );
  }

  @isTest
  static void testB01CompletaCampaniaDeCgExistente() {
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
    campana.Estado__c = 'Activa';
    update campana;
    Account productor = Test_TestUtils.crearProductor();
    Variedad__c variedad = new Variedad__c(
      Name = 'TIPA B01',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert variedad;
    String tecnologia = CuentaGranariaVarietalCreditoService.obtenerTecnologiaVarietal();
    System.assertNotEquals(
      null,
      tecnologia,
      'B-01: hay tecnología varietal en CMDT'
    );
    insert new Cuenta_Granaria__c(
      Productor__c = productor.Id,
      Campania__c = campana.Id,
      Cultivo__c = cultivo.Id,
      Tecnologia__c = tecnologia,
      Clave_Unica__c = productor.Id +
        '|' +
        campana.Id +
        '|' +
        cultivo.Id +
        '|' +
        tecnologia
    );

    Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Variedad__c = variedad.Id,
      Origen__c = 'Compra HT',
      Cantidad__c = 5,
      Signo__c = 1,
      Valor_Conversion__c = 4000,
      Biotecnologia__c = 'Convencional',
      Etapa__c = 'Cobrada',
      No_asignar_campa_a__c = true,
      Fecha_Inicio__c = Date.today().addDays(-5),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert ht;
    Tonelada__c tn = new Tonelada__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Variedad__c = variedad.Id,
      Biotecnologia__c = 'Convencional',
      Origen__c = 'Compra HT',
      Cantidad__c = 20,
      Signo__c = 1,
      Etapa__c = 'Cobrada',
      No_asignar_campa_a__c = true,
      HT_Id__c = ht.Id,
      Fecha_Inicio__c = Date.today().addDays(-1),
      Fecha_Fin__c = Date.today().addDays(300)
    );
    insert tn;
    ht.TN_Id__c = tn.Id;
    update ht;

    Cuenta_Granaria__c cgOk = [
      SELECT Campania__c, Productor__c, Cultivo__c
      FROM Cuenta_Granaria__c
      WHERE Productor__c = :productor.Id
      LIMIT 1
    ];
    System.assertEquals(
      campana.Id,
      cgOk.Campania__c,
      'B-01: la CG de prueba conserva la campaña'
    );
    System.assertEquals(
      campana.Id,
      CuentaGranariaVarietalCreditoService.campanaVarietalExistente(
        productor.Id,
        cultivo.Id
      ),
      'B-01: encuentra la campaña de la CG existente'
    );

    Test.startTest();
    CuentaGranariaVarietalCreditoService.completarCampaniaYAcreditar(
      new Set<Id>{ ht.Id }
    );
    Test.stopTest();

    Hectareas_Tecnologicas__c htOk = [
      SELECT
        Campania__c,
        Detalle_Variedad_CG__c,
        Etapa__c,
        No_asignar_campa_a__c
      FROM Hectareas_Tecnologicas__c
      WHERE Id = :ht.Id
    ];
    Tonelada__c tnOk = [
      SELECT Campania__c, Cuenta_Granaria__c
      FROM Tonelada__c
      WHERE Id = :tn.Id
    ];
    Detalle_Variedad_CG__c detalle = [
      SELECT Credito_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Variedad__c = :variedad.Id
      LIMIT 1
    ];
    System.assertEquals(
      campana.Id,
      htOk.Campania__c,
      'B-01: la HT toma la campaña de la CG (etapa=' +
        htOk.Etapa__c +
        ', noAsignar=' +
        htOk.No_asignar_campa_a__c +
        ')'
    );
    System.assertEquals(campana.Id, tnOk.Campania__c, 'B-01: la TN toma la misma campaña');
    System.assertNotEquals(null, tnOk.Cuenta_Granaria__c, 'B-01: la TN queda en la CG');
    System.assertNotEquals(null, htOk.Detalle_Variedad_CG__c, 'B-01: la HT queda en el Detalle');
    System.assertEquals(20, detalle.Credito_Variedad__c, 'B-01: TIPA acredita 20 t');
  }
}
