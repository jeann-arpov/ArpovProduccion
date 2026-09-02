@isTest
private class FooterContactControllerTest {
  @isTest
  static void testGetFooterCtaConfig() {
    Test.startTest();
    FooterContactController.FooterCtaConfig config = FooterContactController.getFooterCtaConfig();
    Test.stopTest();

    System.assertNotEquals(null, config, 'La configuración no debe ser nula');
    System.assertNotEquals(null, config.texto, 'El texto no debe ser nulo');
    System.assertNotEquals(null, config.url, 'La URL no debe ser nula');
    System.assert(
      String.isNotBlank(config.texto),
      'El texto no debe estar vacío'
    );
    System.assert(String.isNotBlank(config.url), 'La URL no debe estar vacía');
  }
}
