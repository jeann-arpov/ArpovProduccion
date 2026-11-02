@isTest
private class CuentaGranariaVarietalValidatorTest {
  private static Cultivo__c cultivo;
  private static Account productor;
  private static Variedad__c variedadA;
  private static Variedad__c variedadB;
  private static Variedad__c variedadC;

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
    update productor;

    variedadA = new Variedad__c(
      Name = 'CATALPA',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    variedadB = new Variedad__c(
      Name = 'TIPANA',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    variedadC = new Variedad__c(
      Name = 'BAGUETTE',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert new List<Variedad__c>{ variedadA, variedadB, variedadC };
  }

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
          Variedad__c = variedades[i].Id,
          Porcentaje_Varietal__c = porcentajes[i],
          Clave_Linea__c = mbt.Id + '|' + variedades[i].Id
        )
      );
    }
    insert lineas;
    return mbt;
  }

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

    System.assertEquals('A procesar', mbt.Estado__c);
    System.assertEquals('OK', mbt.Resultado__c);
  }
}
