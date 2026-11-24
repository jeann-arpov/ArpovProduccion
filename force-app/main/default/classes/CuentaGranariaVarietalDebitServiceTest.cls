/**
 * Tests del servicio de débito varietal (CuentaGranariaVarietalDebitService).
 *
 * Cubre:
 *  - Filtro por umbral de presencia (variedades por debajo no se debitan).
 *  - Creación de débitos por variedad y actualización de Saldo_Variedad__c.
 *  - Camino "sin débito" (todas las variedades bajo el umbral).
 *  - Caminos de error (parámetros insuficientes, Cuenta Granaria no encontrada).
 *  - Idempotencia por camión (Mov_BolsaTech__c).
 *
 * Los umbrales y la tecnología se leen de Configuracion_Varietal__mdt, sin
 * valores hardcodeados, para que el test no dependa de valores fijos del CMDT.
 */
@isTest
private class CuentaGranariaVarietalDebitServiceTest {
  private static final String ORIGEN_ESCANER = 'Escáner varietal';

  @testSetup
  static void setup() {
    Test_TestUtils.disableFlows();

    String tecnologia = obtenerTecnologia();

    Cultivo__c cultivo = Test_TestUtils.crearCultivo('TRIGO', 1, true);
    // El flow "Creacion de Expedientes PRI Y SEC" (SOJA) se dispara al insertar
    // un Movimiento_BolsaTech__c y necesita encontrar un Cultivo__c SOJA.
    insert new Cultivo__c(
      Name = 'SOJA',
      Densidad_de_Siembra__c = 75,
      Sembra_Evolucion__c = true
    );
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

    insert new List<Variedad__c>{
      new Variedad__c(
        Name = 'CATALPA',
        Cultivo__c = cultivo.Id,
        Biotecnologia__c = 'Convencional',
        Uso_Comercial_Dureza__c = 'PAN'
      ),
      new Variedad__c(
        Name = 'TIPANA',
        Cultivo__c = cultivo.Id,
        Biotecnologia__c = 'Convencional',
        Uso_Comercial_Dureza__c = 'PAN'
      ),
      new Variedad__c(
        Name = 'BAGUETTE',
        Cultivo__c = cultivo.Id,
        Biotecnologia__c = 'Convencional',
        Uso_Comercial_Dureza__c = 'PAN'
      )
    };

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
  }

  private static Configuracion_Varietal__mdt obtenerConfiguracion() {
    List<Configuracion_Varietal__mdt> cfgs = Configuracion_Varietal__mdt.getAll()
      .values();
    return cfgs.isEmpty() ? null : cfgs[0];
  }

  private static String obtenerTecnologia() {
    Configuracion_Varietal__mdt cfg = obtenerConfiguracion();
    return cfg != null &&
      cfg.Tecnologia__c != null
      ? cfg.Tecnologia__c
      : 'RR1/RR2 - BT/Convencional';
  }

  private static Decimal obtenerUmbral() {
    Configuracion_Varietal__mdt cfg = obtenerConfiguracion();
    return cfg != null &&
      cfg.Umbral_Presencia__c != null
      ? cfg.Umbral_Presencia__c
      : 0;
  }

  private static Cultivo__c getCultivo() {
    return [SELECT Id FROM Cultivo__c LIMIT 1];
  }

  private static Campana_Agricola__c getCampana() {
    return [SELECT Id FROM Campana_Agricola__c LIMIT 1];
  }

  private static Account getProductor() {
    return [SELECT Id, N_CUIT__c FROM Account LIMIT 1];
  }

  private static Variedad__c getVariedad(String name) {
    return [SELECT Id FROM Variedad__c WHERE Name = :name LIMIT 1];
  }

  /**
   * Variedades por debajo del umbral no se debitan; las demás sí (2 débitos).
   */
  @isTest
  static void testDebitoFiltraPorUmbral() {
    Cultivo__c cultivo = getCultivo();
    Campana_Agricola__c campana = getCampana();
    Account productor = getProductor();
    Variedad__c variedadA = getVariedad('CATALPA');
    Variedad__c variedadB = getVariedad('TIPANA');
    Variedad__c variedadC = getVariedad('BAGUETTE');

    Decimal umbral = obtenerUmbral();
    Decimal porcentajeSobre = umbral + 40 > 100 ? 100 : umbral + 40;
    Decimal porcentajeBajo = umbral - 5 < 0 ? 0 : umbral - 5;

    List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas = new List<CuentaGranariaVarietalDebitService.LineaVarietal>{
      new CuentaGranariaVarietalDebitService.LineaVarietal(
        variedadA.Id,
        porcentajeSobre
      ),
      new CuentaGranariaVarietalDebitService.LineaVarietal(
        variedadB.Id,
        porcentajeSobre
      ),
      new CuentaGranariaVarietalDebitService.LineaVarietal(
        variedadC.Id,
        porcentajeBajo
      )
    };

    Test.startTest();
    CuentaGranariaVarietalDebitService.ResultadoDebito resultado = CuentaGranariaVarietalDebitService.procesarDebito(
      productor.Id,
      campana.Id,
      cultivo.Id,
      100000,
      lineas
    );
    Test.stopTest();

    System.assertEquals(true, resultado.exitoso, 'El débito debe ser exitoso');
    System.assertEquals(2, resultado.debitosCreados, 'Deben crearse 2 débitos');

    List<Tonelada__c> debitos = [
      SELECT Id, Variedad__c, Origen__c, Signo__c
      FROM Tonelada__c
      WHERE Origen__c = :ORIGEN_ESCANER
    ];
    System.assertEquals(
      2,
      debitos.size(),
      'Deben existir 2 Toneladas de débito'
    );

    Set<Id> variedadesDebitadas = new Set<Id>();
    for (Tonelada__c tn : debitos) {
      System.assertEquals(
        -1,
        tn.Signo__c,
        'El débito debe tener signo negativo'
      );
      variedadesDebitadas.add(tn.Variedad__c);
    }
    System.assert(
      variedadesDebitadas.contains(variedadA.Id),
      'La variedad A debe debitarse'
    );
    System.assert(
      variedadesDebitadas.contains(variedadB.Id),
      'La variedad B debe debitarse'
    );
    System.assert(
      !variedadesDebitadas.contains(variedadC.Id),
      'La variedad C no debe debitarse'
    );
  }

  /**
   * Con ambas variedades sobre el umbral se debitan las dos y el saldo de la
   * sub-cuenta refleja el débito.
   */
  @isTest
  static void testDebitoAmbasSobreUmbralActualizaSaldo() {
    Cultivo__c cultivo = getCultivo();
    Campana_Agricola__c campana = getCampana();
    Account productor = getProductor();
    Variedad__c variedadA = getVariedad('CATALPA');
    Variedad__c variedadB = getVariedad('TIPANA');

    Decimal pesoKg = 100000;
    Decimal porcentaje = 50;
    Decimal toneladasEsperadas = pesoKg / 1000 * (porcentaje / 100);

    List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas = new List<CuentaGranariaVarietalDebitService.LineaVarietal>{
      new CuentaGranariaVarietalDebitService.LineaVarietal(
        variedadA.Id,
        porcentaje
      ),
      new CuentaGranariaVarietalDebitService.LineaVarietal(
        variedadB.Id,
        porcentaje
      )
    };

    Test.startTest();
    CuentaGranariaVarietalDebitService.ResultadoDebito resultado = CuentaGranariaVarietalDebitService.procesarDebito(
      productor.Id,
      campana.Id,
      cultivo.Id,
      pesoKg,
      lineas
    );
    Test.stopTest();

    System.assertEquals(true, resultado.exitoso, 'El débito debe ser exitoso');
    System.assertEquals(2, resultado.debitosCreados, 'Deben crearse 2 débitos');
    System.assertEquals(
      2 * toneladasEsperadas,
      resultado.debitoTotalTn,
      'El total debitado debe ser 2 x toneladas de la variedad'
    );

    Detalle_Variedad_CG__c scA = [
      SELECT Saldo_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Variedad__c = :variedadA.Id
      LIMIT 1
    ];
    System.assertEquals(
      -toneladasEsperadas,
      scA.Saldo_Variedad__c,
      'El saldo de la sub-cuenta debe reflejar el débito'
    );
  }

  /**
   * Si ninguna variedad supera el umbral, no hay débito (sinDebito) ni Toneladas.
   */
  @isTest
  static void testSinDebitoCuandoTodasBajoUmbral() {
    Cultivo__c cultivo = getCultivo();
    Campana_Agricola__c campana = getCampana();
    Account productor = getProductor();
    Variedad__c variedadA = getVariedad('CATALPA');
    Variedad__c variedadB = getVariedad('TIPANA');

    Decimal umbral = obtenerUmbral();
    Decimal porcentajeBajo = umbral - 5 < 0 ? 0 : umbral - 5;

    List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas = new List<CuentaGranariaVarietalDebitService.LineaVarietal>{
      new CuentaGranariaVarietalDebitService.LineaVarietal(
        variedadA.Id,
        porcentajeBajo
      ),
      new CuentaGranariaVarietalDebitService.LineaVarietal(
        variedadB.Id,
        porcentajeBajo
      )
    };

    Test.startTest();
    CuentaGranariaVarietalDebitService.ResultadoDebito resultado = CuentaGranariaVarietalDebitService.procesarDebito(
      productor.Id,
      campana.Id,
      cultivo.Id,
      100000,
      lineas
    );
    Test.stopTest();

    System.assertEquals(true, resultado.sinDebito, 'Debe marcar sinDebito');
    System.assertEquals(false, resultado.exitoso, 'No debe ser exitoso');
    System.assertEquals(0, resultado.debitosCreados, 'No debe crear débitos');

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Tonelada__c WHERE Origen__c = :ORIGEN_ESCANER],
      'No debe crear Toneladas de débito'
    );
  }

  /**
   * Sin datos suficientes el servicio devuelve error sin crear débitos.
   */
  @isTest
  static void testParametrosInsuficientes() {
    Cultivo__c cultivo = getCultivo();
    Campana_Agricola__c campana = getCampana();
    Account productor = getProductor();

    Test.startTest();
    CuentaGranariaVarietalDebitService.ResultadoDebito r1 = CuentaGranariaVarietalDebitService.procesarDebito(
      null,
      null,
      null,
      100,
      null
    );
    CuentaGranariaVarietalDebitService.ResultadoDebito r2 = CuentaGranariaVarietalDebitService.procesarDebito(
      productor.Id,
      campana.Id,
      cultivo.Id,
      100,
      new List<CuentaGranariaVarietalDebitService.LineaVarietal>()
    );
    Test.stopTest();

    System.assertEquals(false, r1.exitoso, 'Sin params no debe ser exitoso');
    System.assertNotEquals(null, r1.mensaje, 'Debe devolver un mensaje');

    System.assertEquals(false, r2.exitoso, 'Sin líneas no debe ser exitoso');
    System.assertNotEquals(null, r2.mensaje, 'Debe devolver un mensaje');
  }

  /**
   * Si no existe la Cuenta Granaria varietal, devuelve error sin crear débitos.
   */
  @isTest
  static void testCuentaGranariaNoEncontrada() {
    Cultivo__c cultivo = getCultivo();
    Account productor = getProductor();
    Variedad__c variedadA = getVariedad('CATALPA');

    String anio = String.valueOf(Date.today().year() - 1);
    Campana_Agricola__c otraCampana = Test_TestUtils.crearCampanaAgricola(
      anio,
      cultivo,
      Date.today().addYears(-2),
      Date.today().addYears(-1),
      anio + ' - TRIGO',
      true
    );

    List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas = new List<CuentaGranariaVarietalDebitService.LineaVarietal>{
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadA.Id, 50)
    };

    Test.startTest();
    CuentaGranariaVarietalDebitService.ResultadoDebito resultado = CuentaGranariaVarietalDebitService.procesarDebito(
      productor.Id,
      otraCampana.Id,
      cultivo.Id,
      100000,
      lineas
    );
    Test.stopTest();

    System.assertEquals(false, resultado.exitoso, 'No debe ser exitoso');
    System.assertEquals(
      'No se encontró Cuenta Granaria para el productor/campaña/cultivo.',
      resultado.mensaje,
      'Debe indicar que no encontró la CG'
    );
  }

  /**
   * Para el mismo camión (Mov_BolsaTech__c) el débito es idempotente: la
   * segunda pasada no vuelve a debitar las variedades ya debitadas.
   */
  @isTest
  static void testDebitoIdempotentePorMbt() {
    Cultivo__c cultivo = getCultivo();
    Campana_Agricola__c campana = getCampana();
    Account productor = getProductor();
    Variedad__c variedadA = getVariedad('CATALPA');
    Variedad__c variedadB = getVariedad('TIPANA');

    Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
      Estado__c = 'A procesar',
      No_Debitar__c = false,
      Peso_Neto__c = 100000,
      Titular__c = productor.Id,
      Cultivo__c = 'TRIGO',
      Cosecha__c = String.valueOf(Date.today().year()),
      Tecnologia__c = 'RR1/RR2 - BT/Convencional',
      CTG__c = 'CTG-DEB-001',
      Codigo_de_Muestra__c = 'MUE-DEB-001',
      Fecha_de_Analisis__c = '15/10/2023',
      CUIT_Titular__c = productor.N_CUIT__c,
      Cuit_Destinatario__c = productor.N_CUIT__c
    );
    insert mbt;

    List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas = new List<CuentaGranariaVarietalDebitService.LineaVarietal>{
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadA.Id, 50),
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadB.Id, 50)
    };

    Test.startTest();
    CuentaGranariaVarietalDebitService.ResultadoDebito primera = CuentaGranariaVarietalDebitService.procesarDebito(
      productor.Id,
      campana.Id,
      cultivo.Id,
      100000,
      lineas,
      mbt.Id
    );
    CuentaGranariaVarietalDebitService.ResultadoDebito segunda = CuentaGranariaVarietalDebitService.procesarDebito(
      productor.Id,
      campana.Id,
      cultivo.Id,
      100000,
      lineas,
      mbt.Id
    );
    Test.stopTest();

    System.assertEquals(
      true,
      primera.exitoso,
      'La primera pasada debe debitar'
    );
    System.assertEquals(
      2,
      primera.debitosCreados,
      'La primera pasada crea 2 débitos'
    );

    System.assertEquals(
      true,
      segunda.sinDebito,
      'La segunda pasada no debe debitar'
    );
    System.assertEquals(
      0,
      segunda.debitosCreados,
      'La segunda pasada no crea débitos'
    );

    List<Tonelada__c> debitos = [
      SELECT Id, Mov_BolsaTech__c
      FROM Tonelada__c
      WHERE Origen__c = :ORIGEN_ESCANER
    ];
    System.assertEquals(2, debitos.size(), 'No debe duplicar los débitos');
    for (Tonelada__c tn : debitos) {
      System.assertEquals(
        mbt.Id,
        tn.Mov_BolsaTech__c,
        'El débito debe vincularse al camión'
      );
    }
  }
}
