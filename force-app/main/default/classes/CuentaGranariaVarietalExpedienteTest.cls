@isTest
private class CuentaGranariaVarietalExpedienteTest {
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
    update productor;

    Variedad__c variedad = new Variedad__c(
      Name = 'CATALPA',
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

    insert new Detalle_Variedad_CG__c(
      Cuenta_Granaria__c = cg.Id,
      Variedad__c = variedad.Id,
      Clave_Varietal__c = cg.Id + '|' + variedad.Id,
      Saldo_Variedad__c = -20
    );
  }

  @isTest
  static void testAperturaExpedienteVarietal() {
    Variedad__c variedad = [SELECT Id FROM Variedad__c LIMIT 1];
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];

    Test.startTest();
    Integer creados = CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();
    Test.stopTest();

    System.assertEquals(1, creados);
    List<Expediente_de_Negativos__c> exps = [
      SELECT
        Id,
        Name,
        Detalle_Variedad_CG__c,
        Variedad__c,
        Estado_de_la_Etapa__c
      FROM Expediente_de_Negativos__c
      WHERE Detalle_Variedad_CG__c = :subCuenta.Id
    ];
    System.assertEquals(1, exps.size());
    System.assert(exps[0].Name.startsWith('EXP-30502874353'));
    System.assertEquals(variedad.Id, exps[0].Variedad__c);
    System.assertEquals('No empezado', exps[0].Estado_de_la_Etapa__c);
  }

  @isTest
  static void testCierreExpedienteRegularizado() {
    Detalle_Variedad_CG__c subCuenta = [
      SELECT Id
      FROM Detalle_Variedad_CG__c
      LIMIT 1
    ];
    CuentaGranariaVarietalExpedienteService.abrirExpedientesVarietales();

    subCuenta.Saldo_Variedad__c = 5;
    update subCuenta;

    Test.startTest();
    Integer cerrados = CuentaGranariaVarietalExpedienteService.cerrarExpedientesRegularizados();
    Test.stopTest();

    System.assertEquals(1, cerrados);
    Expediente_de_Negativos__c exp = [
      SELECT Estado_de_la_Etapa__c, Fecha_de_finalizacion__c
      FROM Expediente_de_Negativos__c
      WHERE Detalle_Variedad_CG__c = :subCuenta.Id
      LIMIT 1
    ];
    System.assertEquals('Finalizado', exp.Estado_de_la_Etapa__c);
    System.assertEquals(Date.today(), exp.Fecha_de_finalizacion__c);
  }
}
