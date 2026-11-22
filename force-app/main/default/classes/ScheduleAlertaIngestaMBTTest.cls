@isTest
private class ScheduleAlertaIngestaMBTTest {
  private static final Datetime MIERCOLES_MEDIO = Datetime.newInstance(
    2026,
    12,
    9,
    15,
    0,
    0
  );
  private static final Datetime SABADO_MEDIO = Datetime.newInstance(
    2026,
    12,
    12,
    15,
    0,
    0
  );

  @isTest
  static void testEsDiaHabilFeriado() {
    insert new Holiday(
      Name = 'Feriado Test',
      ActivityDate = Date.newInstance(2026, 12, 8),
      IsAllDay = true
    );

    Boolean esHabil = IngestaMBTAlertaService.esDiaHabil(
      Date.newInstance(2026, 12, 8),
      MIERCOLES_MEDIO
    );

    System.assertEquals(false, esHabil, 'Feriado: no debe ser día hábil');
  }

  @isTest
  static void testEsDiaHabilDiaDeSemana() {
    Boolean esHabil = IngestaMBTAlertaService.esDiaHabil(
      Date.newInstance(2026, 12, 9),
      MIERCOLES_MEDIO
    );

    System.assertEquals(true, esHabil, 'Miércoles hábil');
  }

  @isTest
  static void testEsDiaHabilFinDeSemana() {
    Boolean esHabil = IngestaMBTAlertaService.esDiaHabil(
      Date.newInstance(2026, 12, 12),
      SABADO_MEDIO
    );

    System.assertEquals(false, esHabil, 'Sábado: no debe ser día hábil');
  }

  @isTest
  static void testObtenerMiembrosCola() {
    Group cola = new Group(
      Name = 'Test Cola Ingesta',
      DeveloperName = 'Test_Cola_Ingesta_XYZ',
      Type = 'Queue'
    );
    insert cola;
    insert new GroupMember(
      GroupId = cola.Id,
      UserOrGroupId = UserInfo.getUserId()
    );

    Set<String> userIds = IngestaMBTAlertaService.obtenerMiembrosCola(
      'Test_Cola_Ingesta_XYZ'
    );

    System.assertEquals(1, userIds.size(), 'Debe devolver el miembro de la cola');
    System.assert(userIds.contains(UserInfo.getUserId()), 'Debe incluir al usuario');
  }

  @isTest
  static void testObtenerMiembrosColaVacia() {
    Set<String> userIds = IngestaMBTAlertaService.obtenerMiembrosCola(
      'Cola_Inexistente'
    );

    System.assertEquals(0, userIds.size(), 'Cola inexistente: vacío');
  }

  @isTest
  static void testEnviarNotificacion() {
    Test.startTest();
    IngestaMBTAlertaService.enviarNotificacion(
      new Set<String>{ UserInfo.getUserId() },
      Date.today()
    );
    Test.stopTest();
  }

  @isTest
  static void testEnviarAlerta() {
    Test.startTest();
    IngestaMBTAlertaService.enviarAlerta(
      new List<String>{ 'test@example.com' },
      Date.today()
    );
    Test.stopTest();
  }

  @isTest
  static void testVerificarIngestaSinIngestaEnvia() {
    Test.startTest();
    IngestaMBTAlertaService.verificarIngesta(
      Date.newInstance(2026, 12, 9),
      MIERCOLES_MEDIO
    );
    Test.stopTest();
  }

  @isTest
  static void testConIngestaDelDiaNoEnviaAlerta() {
    insert new Ingesta_MBT__c(
      Nombre_Archivo__c = 'mbt_test.csv',
      Hash__c = 'abc123def456',
      Fecha_Ingesta__c = Datetime.now(),
      Estado__c = 'OK'
    );

    Test.startTest();
    IngestaMBTAlertaService.verificarIngestaDelDia();
    Test.stopTest();

    System.assertEquals(0, Limits.getEmailInvocations(), 'No debe enviar correo');
  }

  @isTest
  static void testFeriadoNoEnviaAlerta() {
    insert new Holiday(
      Name = 'Feriado Test',
      ActivityDate = Date.today(),
      IsAllDay = true
    );

    Test.startTest();
    IngestaMBTAlertaService.verificarIngestaDelDia();
    Test.stopTest();

    System.assertEquals(0, Limits.getEmailInvocations(), 'Feriado: no debe enviar correo');
  }

  @isTest
  static void testSchedulable() {
    Test.startTest();
    new ScheduleAlertaIngestaMBT().execute(null);
    Test.stopTest();
  }
}
