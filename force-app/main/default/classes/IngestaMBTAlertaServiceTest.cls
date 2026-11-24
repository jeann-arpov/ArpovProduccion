/**
 * Tests del servicio de alerta de ingesta MBT (IngestaMBTAlertaService).
 *
 * Cubre: días con archivo esperado (lunes a jueves), días hábiles (feriados,
 * BusinessHours), resolución de miembros de cola y el flujo de verificación
 * (no avisar en feriado/viernes/con ingesta; avisar si falta la ingesta).
 */
@isTest
private class IngestaMBTAlertaServiceTest {
  private static final Date LUNES = Date.newInstance(2026, 12, 7);
  private static final Date MARTES = Date.newInstance(2026, 12, 8);
  private static final Date MIERCOLES = Date.newInstance(2026, 12, 9);
  private static final Date JUEVES = Date.newInstance(2026, 12, 10);
  private static final Date VIERNES = Date.newInstance(2026, 12, 11);
  private static final Date SABADO = Date.newInstance(2026, 12, 12);
  private static final Date DOMINGO = Date.newInstance(2026, 12, 13);

  private static final Datetime MIERCOLES_MEDIO = Datetime.newInstance(
    2026,
    12,
    9,
    15,
    0,
    0
  );
  private static final Datetime VIERNES_MEDIO = Datetime.newInstance(
    2026,
    12,
    11,
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

  // ===== esDiaConArchivoEsperado =====

  @isTest
  static void archivoEsperadoLunesAJueves() {
    System.assertEquals(
      true,
      IngestaMBTAlertaService.esDiaConArchivoEsperado(LUNES),
      'Lunes espera archivo'
    );
    System.assertEquals(
      true,
      IngestaMBTAlertaService.esDiaConArchivoEsperado(MARTES),
      'Martes espera archivo'
    );
    System.assertEquals(
      true,
      IngestaMBTAlertaService.esDiaConArchivoEsperado(MIERCOLES),
      'Miércoles espera archivo'
    );
    System.assertEquals(
      true,
      IngestaMBTAlertaService.esDiaConArchivoEsperado(JUEVES),
      'Jueves espera archivo'
    );
  }

  @isTest
  static void archivoNoEsperadoViernesYFinDeSemana() {
    System.assertEquals(
      false,
      IngestaMBTAlertaService.esDiaConArchivoEsperado(VIERNES),
      'Viernes no espera archivo'
    );
    System.assertEquals(
      false,
      IngestaMBTAlertaService.esDiaConArchivoEsperado(SABADO),
      'Sábado no espera archivo'
    );
    System.assertEquals(
      false,
      IngestaMBTAlertaService.esDiaConArchivoEsperado(DOMINGO),
      'Domingo no espera archivo'
    );
  }

  // ===== esDiaHabil =====

  @isTest
  static void diaHabilEnFeriadoEsFalso() {
    insert new Holiday(
      Name = 'Feriado Test',
      ActivityDate = MIERCOLES,
      IsAllDay = true
    );

    System.assertEquals(
      false,
      IngestaMBTAlertaService.esDiaHabil(MIERCOLES, MIERCOLES_MEDIO),
      'Feriado: no debe ser día hábil'
    );
  }

  @isTest
  static void diaHabilEntreSemana() {
    System.assertEquals(
      true,
      IngestaMBTAlertaService.esDiaHabil(MIERCOLES, MIERCOLES_MEDIO),
      'Miércoles hábil (dentro de BusinessHours)'
    );
  }

  @isTest
  static void diaHabilFinDeSemanaEsFalso() {
    System.assertEquals(
      false,
      IngestaMBTAlertaService.esDiaHabil(SABADO, SABADO_MEDIO),
      'Sábado: no debe ser día hábil'
    );
  }

  // ===== obtenerMiembrosCola =====

  @isTest
  static void obtenerMiembrosCola() {
    Group cola = new Group(
      Name = 'Cola Ingesta Test',
      DeveloperName = 'Cola_Ingesta_Test_ABC',
      Type = 'Queue'
    );
    insert cola;
    insert new GroupMember(
      GroupId = cola.Id,
      UserOrGroupId = UserInfo.getUserId()
    );

    Set<String> userIds = IngestaMBTAlertaService.obtenerMiembrosCola(
      'Cola_Ingesta_Test_ABC'
    );

    System.assertEquals(
      1,
      userIds.size(),
      'Debe devolver el miembro de la cola'
    );
    System.assert(
      userIds.contains(UserInfo.getUserId()),
      'Debe incluir al usuario actual'
    );
  }

  @isTest
  static void obtenerMiembrosColaInexistente() {
    Set<String> userIds = IngestaMBTAlertaService.obtenerMiembrosCola(
      'Cola_Inexistente'
    );

    System.assertEquals(0, userIds.size(), 'Cola inexistente: vacío');
  }

  // ===== verificarIngesta =====

  @isTest
  static void noEnviaEnFeriado() {
    insert new Holiday(
      Name = 'Feriado Test',
      ActivityDate = MIERCOLES,
      IsAllDay = true
    );

    Test.startTest();
    IngestaMBTAlertaService.verificarIngesta(MIERCOLES, MIERCOLES_MEDIO);
    Test.stopTest();

    System.assertEquals(
      0,
      Limits.getEmailInvocations(),
      'Feriado: no debe enviar correo'
    );
  }

  @isTest
  static void noEnviaEnViernes() {
    Test.startTest();
    IngestaMBTAlertaService.verificarIngesta(VIERNES, VIERNES_MEDIO);
    Test.stopTest();

    System.assertEquals(
      0,
      Limits.getEmailInvocations(),
      'Viernes (archivo no esperado): no debe enviar correo'
    );
  }

  @isTest
  static void noEnviaCuandoHayIngesta() {
    insert new Ingesta_MBT__c(
      Nombre_Archivo__c = 'mbt_test.csv',
      Hash__c = 'abc123def456',
      Fecha_Ingesta__c = Datetime.newInstance(2026, 12, 9, 10, 0, 0),
      Estado__c = 'OK'
    );

    Test.startTest();
    IngestaMBTAlertaService.verificarIngesta(MIERCOLES, MIERCOLES_MEDIO);
    Test.stopTest();

    System.assertEquals(
      0,
      Limits.getEmailInvocations(),
      'Con ingesta del día: no debe enviar correo'
    );
  }

  @isTest
  static void verificarSinIngestaEjecuta() {
    Test.startTest();
    IngestaMBTAlertaService.verificarIngesta(MIERCOLES, MIERCOLES_MEDIO);
    Test.stopTest();
  }

  @isTest
  static void verificarIngestaDelDiaConIngestaNoEnvia() {
    insert new Ingesta_MBT__c(
      Nombre_Archivo__c = 'mbt_hoy.csv',
      Hash__c = 'hoy123456',
      Fecha_Ingesta__c = Datetime.now(),
      Estado__c = 'OK'
    );

    Test.startTest();
    IngestaMBTAlertaService.verificarIngestaDelDia();
    Test.stopTest();

    System.assertEquals(
      0,
      Limits.getEmailInvocations(),
      'Con ingesta de hoy: no debe enviar correo'
    );
  }

  // ===== envío =====

  @isTest
  static void enviarAlerta() {
    Test.startTest();
    IngestaMBTAlertaService.enviarAlerta(
      new List<String>{ 'test@example.com' },
      MIERCOLES
    );
    Test.stopTest();
  }

  @isTest
  static void enviarNotificacion() {
    Test.startTest();
    IngestaMBTAlertaService.enviarNotificacion(
      new Set<String>{ UserInfo.getUserId() },
      MIERCOLES
    );
    Test.stopTest();
  }
}
