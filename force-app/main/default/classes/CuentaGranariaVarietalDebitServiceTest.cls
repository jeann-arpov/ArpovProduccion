@isTest
private class CuentaGranariaVarietalDebitServiceTest {
  private static Cultivo__c cultivo;
  private static Campana_Agricola__c campana;
  private static Account productor;
  private static Cuenta_Granaria__c cg;
  private static Variedad__c variedadA;
  private static Variedad__c variedadB;

  private static void prepararDatos() {
    cultivo = Test_TestUtils.crearCultivo('TRIGO', 1, true);
    campana = Test_TestUtils.crearCampanaAgricola(
      '2025',
      cultivo,
      Date.today().addDays(-10),
      Date.today().addDays(10),
      '2025 - TRIGO',
      true
    );
    productor = Test_TestUtils.crearProductor();
    productor.N_CUIT__c = '30502874353';
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
    insert new List<Variedad__c>{ variedadA, variedadB };

    cg = new Cuenta_Granaria__c(
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
  }

  @isTest
  static void testUmbral80SoloDebitaMayorIgual() {
    prepararDatos();

    List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas = new List<CuentaGranariaVarietalDebitService.LineaVarietal>{
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadA.Id, 85),
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadB.Id, 15)
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

    System.assertEquals(1, resultado.debitosCreados);

    List<Tonelada__c> debitos = [
      SELECT Id, Variedad__c, Cantidad_con_Signo__c
      FROM Tonelada__c
      WHERE Origen__c = 'Escáner varietal'
    ];
    System.assertEquals(1, debitos.size());
    System.assertEquals(variedadA.Id, debitos[0].Variedad__c);
    System.assertEquals(-85, debitos[0].Cantidad_con_Signo__c);
  }

  @isTest
  static void testDebitoAmbasSobreUmbral() {
    prepararDatos();

    List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas = new List<CuentaGranariaVarietalDebitService.LineaVarietal>{
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadA.Id, 50),
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadB.Id, 50)
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

    System.assertEquals(true, resultado.exitoso);
    System.assertEquals(2, resultado.debitosCreados);

    Detalle_Variedad_CG__c scA = [
      SELECT Saldo_Variedad__c
      FROM Detalle_Variedad_CG__c
      WHERE Cuenta_Granaria__c = :cg.Id AND Variedad__c = :variedadA.Id
      LIMIT 1
    ];
    System.assertEquals(-50, scA.Saldo_Variedad__c);
  }
}
