/**
 * Tests del validador varietal: regla MD-11 (suma de porcentajes = 100).
 */
@isTest
private class CuentaGranariaVarietalValidatorTest {
  private static Cultivo__c cultivo;
  private static Account productor;
  private static Variedad__c variedadA;
  private static Variedad__c variedadB;
  private static Variedad__c variedadC;

  /**
   * Prepara cultivo, productor y tres variedades.
   */
  private static void prepararDatos() {
    Test_TestUtils.disableFlows();

    cultivo = Test_TestUtils.crearCultivo('TRIGO', 1, true);
    productor = Test_TestUtils.crearProductor();
    productor.N_CUIT__c = '30502874353';
    productor.RecordTypeId = [
      SELECT Id
      FROM RecordType
      WHERE SObjectType = 'Account' AND DeveloperName = 'Productor'
      LIMIT 1
    ]
    .Id;
    productor.Type = 'Productor';
    productor.ParentId = null;
    update productor;

    // Un workflow ("Carga Datos Proveedor") cambia el RecordType a 'Proveedor';
    // lo forzamos de vuelta a 'Productor' para que la resolución por CUIT lo encuentre.
    productor = [
      SELECT Id, N_CUIT__c, RecordTypeId, Type, ParentId
      FROM Account
      WHERE Id = :productor.Id
    ];
    productor.RecordTypeId = [
      SELECT Id
      FROM RecordType
      WHERE SObjectType = 'Account' AND DeveloperName = 'Productor'
      LIMIT 1
    ]
    .Id;
    productor.Type = 'Productor';
    productor.ParentId = null;
    update productor;

    variedadA = new Variedad__c(
      Name = 'CATALPA',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN',
      Sembra_Evolucion__c = true,
      Cultivar_Inase__c = 'CATALPA'
    );
    variedadB = new Variedad__c(
      Name = 'TIPANA',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN',
      Sembra_Evolucion__c = true,
      Cultivar_Inase__c = 'TIPANA'
    );
    variedadC = new Variedad__c(
      Name = 'BAGUETTE',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN',
      Sembra_Evolucion__c = true,
      Cultivar_Inase__c = 'BAGUETTE'
    );
    insert new List<Variedad__c>{ variedadA, variedadB, variedadC };
  }

  /**
   * Crea un camión varietal con las líneas indicadas (porcentajes) y sufijo único.
   */
  private static Movimiento_BolsaTech__c crearMbt(
    List<Decimal> porcentajes,
    String sufijo
  ) {
    Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
      Estado__c = 'Con error',
      Cultivo_Varietal__c = true,
      No_Debitar__c = false,
      Peso_Neto__c = 100000,
      Cultivo__c = 'TRIGO',
      Cosecha__c = '2025',
      Tecnologia__c = 'RR1/RR2 - BT/Convencional',
      CTG__c = 'CTG-' + sufijo,
      Codigo_de_Muestra__c = 'MUESTRA-' + sufijo,
      Fecha_de_Analisis__c = '2026-10-01',
      CUIT_Titular__c = productor.N_CUIT__c,
      Cuit_Destinatario__c = productor.N_CUIT__c
    );
    insert mbt;

    List<Variedad__c> variedades = new List<Variedad__c>{
      variedadA,
      variedadB,
      variedadC
    };
    List<Detalle_Variedad_MBT__c> lineas = new List<Detalle_Variedad_MBT__c>();
    for (Integer i = 0; i < porcentajes.size(); i++) {
      lineas.add(
        new Detalle_Variedad_MBT__c(
          Movimiento_BolsaTech__c = mbt.Id,
          Cultivar__c = variedades[i].Cultivar_Inase__c,
          Porcentaje_Varietal__c = porcentajes[i],
          Clave_Linea__c = mbt.Id + '|' + variedades[i].Cultivar_Inase__c
        )
      );
    }
    insert lineas;
    return mbt;
  }

  /**
   * Suma de porcentajes > 100 debe dejar el camión 'Con error' reportando MD-11.
   */
  @isTest
  static void testSumaMayorA100QuedaConError() {
    prepararDatos();
    Movimiento_BolsaTech__c mbt = crearMbt(
      new List<Decimal>{ 60, 40, 20 },
      'UC3'
    );

    Test.startTest();
    CuentaGranariaVarietalValidator.validate(
      new List<Movimiento_BolsaTech__c>{ mbt }
    );
    Test.stopTest();

    System.assertEquals('Con error', mbt.Estado__c);
    System.assert(
      mbt.Resultado__c != null && mbt.Resultado__c.contains('MD-11'),
      'Debe reportar MD-11: ' + mbt.Resultado__c
    );
  }

  /**
   * Suma de porcentajes = 100 debe dejar el camión 'A procesar' con resultado OK.
   */
  @isTest
  static void testSuma100QuedaAProcesar() {
    prepararDatos();
    Movimiento_BolsaTech__c mbt = crearMbt(
      new List<Decimal>{ 50, 30, 20 },
      'UC4'
    );

    Test.startTest();
    CuentaGranariaVarietalValidator.validate(
      new List<Movimiento_BolsaTech__c>{ mbt }
    );
    Test.stopTest();

    System.assertEquals(
      'A procesar',
      mbt.Estado__c,
      'Resultado__c=' + mbt.Resultado__c
    );
    System.assertEquals('OK', mbt.Resultado__c);
  }

  /**
   * Validación desde el front (@AuraEnabled validate(Id)): si el camión no está
   * en 'Creado' ni 'Con error', debe lanzar excepción.
   */
  @isTest
  static void testValidateDesdeFrontEstadoNoPermitido() {
    prepararDatos();
    Movimiento_BolsaTech__c mbt = crearMbt(
      new List<Decimal>{ 50, 30, 20 },
      'UC5'
    );
    mbt.Estado__c = 'Procesado';
    update mbt;

    Test.startTest();
    try {
      CuentaGranariaVarietalValidator.validate(mbt.Id);
      System.assert(false, 'Debe lanzar excepción por estado no permitido');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /**
   * Cultivar inexistente debe dejar el camión 'Con error' reportando el cultivar
   * y el código de muestra.
   */
  @isTest
  static void testCultivarNoEncontrado() {
    prepararDatos();
    Movimiento_BolsaTech__c mbt = crearMbt(
      new List<Decimal>{ 50, 30, 20 },
      'UC6'
    );

    Detalle_Variedad_MBT__c linea = [
      SELECT Id, Cultivar__c
      FROM Detalle_Variedad_MBT__c
      WHERE Movimiento_BolsaTech__c = :mbt.Id
      LIMIT 1
    ];
    linea.Cultivar__c = 'CULTIVAR_INEXISTENTE';
    update linea;

    Test.startTest();
    CuentaGranariaVarietalValidator.validate(
      new List<Movimiento_BolsaTech__c>{ mbt }
    );
    Test.stopTest();

    System.assertEquals('Con error', mbt.Estado__c);
    System.assert(
      mbt.Resultado__c.contains('Cultivar no encontrado'),
      'Debe reportar cultivar no encontrado: ' + mbt.Resultado__c
    );
    System.assert(
      mbt.Resultado__c.contains('MUESTRA-UC6'),
      'Debe incluir el código de muestra: ' + mbt.Resultado__c
    );
  }
}
