@IsTest
private class PPH_Criterio03EmailBatchTest {
  @IsTest
  static void enviaMailCriterio03AlDiaSiguiente() {
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
      Estado__c = 'En Revisión',
      Version__c = 'Original',
      Name = 'Plan test PPH criterio 03',
      Criterio_Alerta__c = '03 - Deuda o expedientes abiertos',
      Fecha_Detectada_Alerta__c = Date.today().addDays(-1),
      Mail_Criterio_03_Enviado__c = null
    );
    insert plan;

    Test.startTest();
    Database.executeBatch(new PPH_Criterio03EmailBatch(), 200);
    Test.stopTest();

    plan = [
      SELECT Mail_Criterio_03_Enviado__c
      FROM Plan_de_Siembra__c
      WHERE Id = :plan.Id
    ];
    System.assertEquals(
      Date.today(),
      plan.Mail_Criterio_03_Enviado__c,
      'El batch debe marcar el mail del criterio 03 como enviado'
    );
  }

  @IsTest
  static void noEnviaSiNoEsCriterio03() {
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
      Estado__c = 'En Revisión',
      Version__c = 'Original',
      Name = 'Plan test PPH criterio 01',
      Criterio_Alerta__c = '01 - Area declarada vs entregas',
      Fecha_Detectada_Alerta__c = Date.today().addDays(-1),
      Mail_Criterio_03_Enviado__c = null
    );
    insert plan;

    Test.startTest();
    Database.executeBatch(new PPH_Criterio03EmailBatch(), 200);
    Test.stopTest();

    plan = [
      SELECT Mail_Criterio_03_Enviado__c
      FROM Plan_de_Siembra__c
      WHERE Id = :plan.Id
    ];
    System.assertEquals(
      null,
      plan.Mail_Criterio_03_Enviado__c,
      'No debe enviar el mail del criterio 03 si el criterio no es 03'
    );
  }
}
