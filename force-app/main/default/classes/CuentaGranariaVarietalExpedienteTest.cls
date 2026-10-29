@isTest
private class CuentaGranariaVarietalExpedienteTest {
  private static Cultivo__c cultivo;
  private static Campana_Agricola__c campana;
  private static Account productor;
  private static Cuenta_Granaria__c cg;
  private static Variedad__c variedad;
  private static Detalle_Variedad_CG__c subCuenta;

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

    variedad = new Variedad__c(
      Name = 'CATALPA',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN'
    );
    insert variedad;

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

    subCuenta = new Detalle_Variedad_CG__c(
      Cuenta_Granaria__c = cg.Id,
      Variedad__c = variedad.Id,
      Clave_Varietal__c = cg.Id + '|' + variedad.Id,
      Saldo_Variedad__c = -20
    );
    insert subCuenta;
  }

  @isTest
  static void testAperturaExpedienteVarietal() {
    prepararDatos();

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
    prepararDatos();
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
