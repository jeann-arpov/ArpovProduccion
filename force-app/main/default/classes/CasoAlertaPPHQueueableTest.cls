@IsTest
private class CasoAlertaPPHQueueableTest {
  @IsTest
  static void creaCasoSEAlDetectarCriterio() {
    Plan_de_Siembra__c plan = crearPlanEnPreparacion();

    Test.startTest();
    plan.Criterio_Alerta__c = '03 - Deuda o expedientes abiertos';
    update plan;
    Test.stopTest();

    List<Case> casos = [
      SELECT
        Id,
        RecordType.DeveloperName,
        Type,
        Tema__c,
        Status,
        AccountId,
        Plan_de_Siembra__c,
        Criterio_Alerta__c,
        Campana__c
      FROM Case
      WHERE Plan_de_Siembra__c = :plan.Id
    ];

    System.assertEquals(1, casos.size());
    Case caso = casos[0];
    System.assertEquals('Sembra_Evolucion', caso.RecordType.DeveloperName);
    System.assertEquals('Consulta', caso.Type);
    System.assertEquals('PPH', caso.Tema__c);
    System.assertEquals('Abierto', caso.Status);
    System.assertEquals(plan.Productor__c, caso.AccountId);
    System.assertEquals(
      '03 - Deuda o expedientes abiertos',
      caso.Criterio_Alerta__c
    );

    Plan_de_Siembra__c planConCampania = [
      SELECT Parametro_PPH__r.Campana__c
      FROM Plan_de_Siembra__c
      WHERE Id = :plan.Id
    ];
    System.assertEquals(
      planConCampania.Parametro_PPH__r.Campana__c,
      caso.Campana__c
    );
  }

  @IsTest
  static void actualizaCasoExistenteSinDuplicar() {
    Plan_de_Siembra__c plan = crearPlanEnPreparacion();
    Test.startTest();
    plan.Criterio_Alerta__c = '03 - Deuda o expedientes abiertos';
    update plan;
    plan.Criterio_Alerta__c = '03 - Deuda o expedientes abiertos;04 - Auditoria documental';
    update plan;
    Test.stopTest();

    List<Case> casos = [
      SELECT Id, Criterio_Alerta__c
      FROM Case
      WHERE Plan_de_Siembra__c = :plan.Id
    ];

    System.assertEquals(1, casos.size());
    System.assertEquals(
      '03 - Deuda o expedientes abiertos;04 - Auditoria documental',
      casos[0].Criterio_Alerta__c
    );
  }

  @IsTest
  static void noActualizaCasoCerrado() {
    Plan_de_Siembra__c plan = crearPlanEnPreparacion();

    Id recordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get('Sembra_Evolucion')
      .getRecordTypeId();

    Case caso = new Case(
      RecordTypeId = recordTypeId,
      Plan_de_Siembra__c = plan.Id,
      AccountId = plan.Productor__c,
      Type = 'Consulta',
      Tema__c = 'PPH',
      Status = 'Abierto',
      Capsula__c = 'MESA DE AYUDA',
      Criterio_Alerta__c = '03 - Deuda o expedientes abiertos'
    );
    insert caso;
    caso.Status = 'Cerrado';
    update caso;

    Test.startTest();
    plan.Criterio_Alerta__c = '04 - Auditoria documental';
    update plan;
    Test.stopTest();

    caso = [
      SELECT Id, Status, Criterio_Alerta__c
      FROM Case
      WHERE Plan_de_Siembra__c = :plan.Id
    ];

    System.assertEquals('Cerrado', caso.Status);
    System.assertEquals(
      '03 - Deuda o expedientes abiertos',
      caso.Criterio_Alerta__c
    );
  }

  @IsTest
  static void noCreaCasoSiCriterioVacio() {
    Plan_de_Siembra__c plan = crearPlanEnPreparacion();

    Test.startTest();
    plan.Estado__c = 'En Revisión';
    update plan;
    Test.stopTest();

    List<Case> casos = [
      SELECT Id
      FROM Case
      WHERE Plan_de_Siembra__c = :plan.Id
    ];

    System.assertEquals(0, casos.size());
  }

  private static Plan_de_Siembra__c crearPlanEnPreparacion() {
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

    Parametro_PPH__c parametro = new Parametro_PPH__c(
      Cultivo__c = cultivo.Id,
      Campana__c = campania.Id,
      Fecha_Inicio_Adhesion_PPH__c = Date.today(),
      Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2),
      Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(30),
      Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(50),
      Fecha_Fin_Rectificacion_1__c = Date.today().addDays(40),
      Fecha_Fin_Rectificacion_2__c = Date.today().addDays(60),
      Fecha_Vencimiento_PPH__c = Date.today().addMonths(6)
    );
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
