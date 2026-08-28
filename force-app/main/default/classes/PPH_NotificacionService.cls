public with sharing class PPH_NotificacionService {
  public static final String SENDER_ADDRESS = 'gestion@sembraevolucion.com.ar';

  public static Messaging.SingleEmailMessage buildMail(
    String toAddress,
    String asunto,
    String cuerpo
  ) {
    if (String.isBlank(toAddress)) {
      return null;
    }

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new List<String>{ toAddress });
    mail.setSubject(asunto);
    mail.setPlainTextBody(cuerpo);

    OrgWideEmailAddress sender = getSenderEmail();
    if (sender != null) {
      mail.setOrgWideEmailAddressId(sender.Id);
    }
    return mail;
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

  public static void send(List<Messaging.SingleEmailMessage> mails) {
    if (mails == null || mails.isEmpty()) {
      return;
    }

    try {
      Messaging.sendEmail(mails);
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Error enviando notificación PPH: ' + e.getMessage()
      );
    }
  }
}
