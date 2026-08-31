public with sharing class FooterContactController {
  private static final String DEFAULT_TEXT = '¡Resolvé tu duda!';
  private static final String DEFAULT_URL = 'https://www.sembraevolucion.com.ar/preguntas-frecuentes';

  @AuraEnabled(cacheable=true)
  public static FooterCtaConfig getFooterCtaConfig() {
    Configuracion_Footer_Portal__mdt config = Configuracion_Footer_Portal__mdt.getInstance(
      'default'
    );

    FooterCtaConfig result = new FooterCtaConfig();
    result.mostrar = config != null && config.Mostrar_CTA_Resolve_Duda__c;
    result.texto = config != null &&
      String.isNotBlank(config.Texto_CTA_Resolve_Duda__c)
      ? config.Texto_CTA_Resolve_Duda__c
      : DEFAULT_TEXT;
    result.url = config != null &&
      String.isNotBlank(config.URL_CTA_Resolve_Duda__c)
      ? config.URL_CTA_Resolve_Duda__c
      : DEFAULT_URL;

    return result;
  }

  public class FooterCtaConfig {
    @AuraEnabled
    public Boolean mostrar;

    @AuraEnabled
    public String texto;

    @AuraEnabled
    public String url;
  }
}
