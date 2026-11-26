/**
 * Test del scheduler de validación varietal: verifica que encola
 * BatchValidarCuentaGranariaVarietal.
 */
@isTest
private class ScheduleValidarVarietalTest {
  @isTest
  static void encolaBatchValidacion() {
    Test.startTest();
    new ScheduleValidarCuentaGranariaVarietal().execute(null);
    Test.stopTest();

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM AsyncApexJob
        WHERE
          ApexClass.Name = 'BatchValidarCuentaGranariaVarietal'
          AND JobType = 'BatchApex'
      ],
      'Debe encolar el batch de validación varietal'
    );
  }
}
