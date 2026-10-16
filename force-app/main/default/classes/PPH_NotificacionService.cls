public with sharing class PPH_NotificacionService {
  public static final String SENDER_ADDRESS = 'info@sembraevolucion.com.ar';
  public static final String PROCESO = 'PPH';
  public static final String OBJETO = 'Plan_de_Siembra__c';

  public class Envio {
    public Messaging.SingleEmailMessage mail;
    public Id planId;
    public String nombreRegistro;
    public Id productorId;
    public Id contactoId;
    public String cuit;
    public String toAddress;
    public String asunto;
    public String evento;
    public String plantilla;
    public Id plantillaId;
  }

  public static Envio crearEnvio(
    String templateDeveloperName,
    String evento,
    Plan_de_Siembra__c plan,
    Id contactId,
    String toAddress,
    String cuit
  ) {
    Messaging.SingleEmailMessage mail = buildTemplateMail(
      templateDeveloperName,
      plan.Id,
      contactId,
      toAddress
    );
    if (mail == null) {
      return null;
    }

    Envio envio = new Envio();
    envio.mail = mail;
    envio.planId = plan.Id;
    envio.nombreRegistro = plan.Name;
    envio.productorId = plan.Productor__c;
    envio.contactoId = contactId;
    envio.cuit = cuit;
    envio.toAddress = toAddress;
    envio.asunto = getAsunto(templateDeveloperName);
    envio.evento = evento;
    envio.plantilla = templateDeveloperName;
    envio.plantillaId = getPlantillaId(templateDeveloperName);
    return envio;
  }

  public static Messaging.SingleEmailMessage buildTemplateMail(
    String templateDeveloperName,
    Id planId,
    Id contactId,
    String toAddress
  ) {
    if (String.isBlank(toAddress) || planId == null || contactId == null) {
      return null;
    }

    EmailTemplate template = getTemplate(templateDeveloperName);
    if (template == null) {
      return null;
    }

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setTemplateId(template.Id);
    mail.setWhatId(planId);
    mail.setTargetObjectId(contactId);
    mail.setTreatTargetObjectAsRecipient(false);
    mail.setToAddresses(new List<String>{ toAddress });
    mail.setSaveAsActivity(false);
    mail.setUseSignature(false);

    OrgWideEmailAddress sender = getSenderEmail();
    if (sender != null) {
      mail.setOrgWideEmailAddressId(sender.Id);
    }
    return mail;
  }

  public static String getAsunto(String templateDeveloperName) {
    EmailTemplate template = getTemplate(templateDeveloperName);
    return template != null ? template.Subject : null;
  }

  private static Id getPlantillaId(String templateDeveloperName) {
    EmailTemplate template = getTemplate(templateDeveloperName);
    return template != null ? template.Id : null;
  }

  public static EmailTemplate getTemplate(String developerName) {
    List<EmailTemplate> templates = [
      SELECT Id, Subject
      FROM EmailTemplate
      WHERE DeveloperName = :developerName
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0];
  }

  public static OrgWideEmailAddress getSenderEmail() {
    List<OrgWideEmailAddress> owds = [
      SELECT Id
      FROM OrgWideEmailAddress
      WHERE Address = :SENDER_ADDRESS
      LIMIT 1
    ];
    return owds.isEmpty() ? null : owds[0];
  }

  public static void send(List<Envio> envios) {
    if (envios == null || envios.isEmpty()) {
      return;
    }

    List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
    for (Envio envio : envios) {
      mails.add(envio.mail);
    }

    List<Envio_Correo__c> registros = new List<Envio_Correo__c>();
    try {
      Messaging.SendEmailResult[] resultados = Messaging.sendEmail(mails);
      for (Integer i = 0; i < resultados.size(); i++) {
        Envio_Correo__c registro = crearRegistro(envios[i]);
        if (resultados[i].isSuccess()) {
          registro.Estado__c = 'Enviado';
        } else {
          registro.Estado__c = 'Error';
          registro.Mensaje_Error__c = mensajeError(resultados[i]);
        }
        registros.add(registro);
      }
    } catch (Exception e) {
      for (Envio envio : envios) {
        Envio_Correo__c registro = crearRegistro(envio);
        registro.Estado__c = 'Error';
        registro.Mensaje_Error__c = e.getMessage();
        registros.add(registro);
      }
      System.debug(
        LoggingLevel.ERROR,
        'Error enviando notificación PPH: ' + e.getMessage()
      );
    }

    if (!registros.isEmpty()) {
      insert registros;
    }
  }

  private static Envio_Correo__c crearRegistro(Envio envio) {
    return new Envio_Correo__c(
      Proceso__c = PROCESO,
      Objeto__c = OBJETO,
      Id_Registro__c = String.valueOf(envio.planId),
      Nombre_Registro__c = envio.nombreRegistro,
      Productor__c = envio.productorId,
      Contacto__c = envio.contactoId,
      CUIT__c = envio.cuit,
      Evento__c = envio.evento,
      Plantilla__c = envio.plantilla,
      Id_Plantilla__c = String.valueOf(envio.plantillaId),
      Para__c = envio.toAddress,
      Asunto__c = String.isBlank(envio.asunto) ? PROCESO : envio.asunto,
      De__c = SENDER_ADDRESS,
      Estado__c = 'Enviado',
      Fecha_Envio__c = System.now()
    );
  }

  private static String mensajeError(Messaging.SendEmailResult resultado) {
    if (resultado.getErrors() == null || resultado.getErrors().isEmpty()) {
      return 'El envío fue rechazado.';
    }
    return resultado.getErrors()[0].getMessage();
  }
}
