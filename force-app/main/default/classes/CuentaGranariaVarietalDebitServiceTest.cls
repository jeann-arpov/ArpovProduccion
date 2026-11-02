@isTest
private class CuentaGranariaVarietalDebitServiceTest {
  @testSetup
  static void setup() {
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
    productor.N_CUIT__c = '30502874353';
    productor.RecordTypeId = [
      SELECT Id
      FROM RecordType
      WHERE SObjectType = 'Account' AND DeveloperName = 'Productor'
      LIMIT 1
    ]
    .Id;
    update productor;

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
  static void testUmbralUnaVariedadNoDebita() {
    Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
    Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c LIMIT 1];
    Account productor = [SELECT Id FROM Account LIMIT 1];
    Variedad__c variedadA = [
      SELECT Id
      FROM Variedad__c
      WHERE Name = 'CATALPA'
      LIMIT 1
    ];
    Variedad__c variedadB = [
      SELECT Id
      FROM Variedad__c
      WHERE Name = 'TIPANA'
      LIMIT 1
    ];
    Variedad__c variedadC = [
      SELECT Id
      FROM Variedad__c
      WHERE Name = 'BAGUETTE'
      LIMIT 1
    ];

    List<CuentaGranariaVarietalDebitService.LineaVarietal> lineas = new List<CuentaGranariaVarietalDebitService.LineaVarietal>{
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadA.Id, 50),
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadB.Id, 45),
      new CuentaGranariaVarietalDebitService.LineaVarietal(variedadC.Id, 5)
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

    List<Tonelada__c> debitos = [
      SELECT Id, Variedad__c
      FROM Tonelada__c
      WHERE Origen__c = 'Escáner varietal'
    ];
    System.assertEquals(2, debitos.size());

    Set<Id> variedadesDebitadas = new Set<Id>();
    for (Tonelada__c tn : debitos) {
      variedadesDebitadas.add(tn.Variedad__c);
    }
    System.assert(variedadesDebitadas.contains(variedadA.Id));
    System.assert(variedadesDebitadas.contains(variedadB.Id));
    System.assert(!variedadesDebitadas.contains(variedadC.Id));
  }

  @isTest
  static void testDebitoAmbasSobreUmbral() {
    Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
    Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c LIMIT 1];
    Account productor = [SELECT Id FROM Account LIMIT 1];
    Variedad__c variedadA = [
      SELECT Id
      FROM Variedad__c
      WHERE Name = 'CATALPA'
      LIMIT 1
    ];
    Variedad__c variedadB = [
      SELECT Id
      FROM Variedad__c
      WHERE Name = 'TIPANA'
      LIMIT 1
    ];

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
      WHERE Variedad__c = :variedadA.Id
      LIMIT 1
    ];
    System.assertEquals(-50, scA.Saldo_Variedad__c);
  }
}
