@IsTest
private class PlanDeSiembraTriggerHandlerTest {
  @IsTest
  static void marcaPPHAdheridaAlPasarAAdherido() {
    Test_TestUtils.disableFlows();

    Account productor = Test_TestUtils.crearProductor();

    Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
    cultivo.Sembra_Evolucion__c = true;
    insert cultivo;

    String sufijo = String.valueOf(Datetime.now().getTime());
    Campana_Agricola__c campania = new Campana_Agricola__c(
      Name = 'SOJA 2025 PPH TEST ' + sufijo,
      Ano__c = '2025',
      Estado__c = 'Activa',
      Cultivo__c = cultivo.Id,
      Fecha_de_Inicio__c = Date.today().addMonths(-2),
      Fecha_de_Fin__c = Date.today().addMonths(8)
    );
    insert campania;

    Parametro_PPH__c parametro = new Parametro_PPH__c();
    parametro.Cultivo__c = cultivo.Id;
    parametro.Campana__c = campania.Id;
    parametro.Fecha_Inicio_Adhesion_PPH__c = Date.today();
    parametro.Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2);
    parametro.Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(30);
    parametro.Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(50);
    parametro.Fecha_Fin_Rectificacion_1__c = Date.today().addDays(40);
    parametro.Fecha_Fin_Rectificacion_2__c = Date.today().addDays(60);
    parametro.Fecha_Vencimiento_PPH__c = Date.today().addMonths(6);
    insert parametro;

    Plan_de_Siembra__c plan = new Plan_de_Siembra__c(
      Productor__c = productor.Id,
      Parametro_PPH__c = parametro.Id,
      Estado__c = 'En Preparación',
      Version__c = 'Original',
      Name = 'Plan test PPH'
    );
    insert plan;

    String tecnologia = 'RR1/RR2 - BT/Convencional';
    Cuenta_Granaria__c cuentaGranaria = new Cuenta_Granaria__c(
      Productor__c = productor.Id,
      Cultivo__c = cultivo.Id,
      Campania__c = campania.Id,
      Tecnologia__c = tecnologia,
      Clave_Unica__c = productor.Id +
        '|' +
        campania.Id +
        '|' +
        cultivo.Id +
        '|' +
        tecnologia,
      PPH_Adherida__c = false
    );
    insert cuentaGranaria;

    Test.startTest();
    plan.Estado__c = 'Adherido';
    update plan;
    Test.stopTest();

    cuentaGranaria = [
      SELECT PPH_Adherida__c
      FROM Cuenta_Granaria__c
      WHERE Id = :cuentaGranaria.Id
    ];
    System.assertEquals(true, cuentaGranaria.PPH_Adherida__c);
  }

  @IsTest
  static void notificaAprobacionAlPasarAAdherido() {
    Plan_de_Siembra__c plan = crearPlanEnPreparacion();

    plan.Estado__c = 'Adherido';
    update plan;

    System.assertEquals(1, Limits.getEmailInvocations());
  }

  @IsTest
  static void notificaRechazoAlPasarARechazado() {
    Plan_de_Siembra__c plan = crearPlanEnPreparacion();

    plan.Estado__c = 'Rechazado';
    update plan;

    System.assertEquals(1, Limits.getEmailInvocations());
  }

  @IsTest
  static void registraFechaDeteccionAlPoblarCriterio() {
    Plan_de_Siembra__c plan = crearPlanEnPreparacion();

    plan.Criterio_Alerta__c = '03 - Deuda o expedientes abiertos';
    update plan;

    plan = [
      SELECT Fecha_Detectada_Alerta__c, Fecha_Limite_Resolucion__c
      FROM Plan_de_Siembra__c
      WHERE Id = :plan.Id
    ];

    System.assertEquals(Date.today(), plan.Fecha_Detectada_Alerta__c);
    System.assertEquals(
      Date.today().addDays(30),
      plan.Fecha_Limite_Resolucion__c
    );
  }

  private static Plan_de_Siembra__c crearPlanEnPreparacion() {
    Test_TestUtils.disableFlows();

    Account productor = Test_TestUtils.crearProductor();

    Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
    cultivo.Sembra_Evolucion__c = true;
    insert cultivo;

    Parametro_PPH__c parametro = new Parametro_PPH__c();
    parametro.Cultivo__c = cultivo.Id;
    parametro.Fecha_Inicio_Adhesion_PPH__c = Date.today();
    parametro.Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2);
    parametro.Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(30);
    parametro.Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(50);
    parametro.Fecha_Fin_Rectificacion_1__c = Date.today().addDays(40);
    parametro.Fecha_Fin_Rectificacion_2__c = Date.today().addDays(60);
    parametro.Fecha_Vencimiento_PPH__c = Date.today().addMonths(6);
    insert parametro;

    Plan_de_Siembra__c plan = new Plan_de_Siembra__c(
      Productor__c = productor.Id,
      Parametro_PPH__c = parametro.Id,
      Estado__c = 'En Preparación',
      Version__c = 'Original',
      Name = 'Plan test PPH'
    );
    insert plan;

    return plan;
  }
}
