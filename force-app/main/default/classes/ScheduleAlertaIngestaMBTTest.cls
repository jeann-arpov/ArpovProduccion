@isTest
private class ScheduleAlertaIngestaMBTTest {
  @isTest
  static void testConIngestaDelDiaNoAlerta() {
    insert new Ingesta_MBT__c(
      Nombre_Archivo__c = 'mbt_2026_11_18.csv',
      Hash__c = 'abc123def456',
      Fecha_Ingesta__c = Datetime.now(),
      Estado__c = 'OK'
    );

    Test.startTest();
    IngestaMBTAlertaService.verificarIngestaDelDia();
    Test.stopTest();
  }

  @isTest
  static void testSinIngestaDelDia() {
    Test.startTest();
    IngestaMBTAlertaService.verificarIngestaDelDia();
    Test.stopTest();
  }

  @isTest
  static void testSchedulable() {
    Test.startTest();
    new ScheduleAlertaIngestaMBT().execute(null);
    Test.stopTest();
  }
}
