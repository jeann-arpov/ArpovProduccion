public with sharing class IngestaMBTAlertaService {
  // Correo de Operaciones que recibe la alerta (configurable).
  private static final String CORREO_OPERACIONES = 'operaciones@sembraevolucion.com.ar';
  private static final String ASUNTO_ALERTA = 'Alerta: no se registró ingesta de MBT';

  public static void verificarIngestaDelDia() {
    Date hoy = Date.today();
    if (!esDiaHabil(hoy)) {
      return;
    }
    Datetime inicioHoy = Datetime.newInstance(
      hoy.year(),
      hoy.month(),
      hoy.day(),
      0,
      0,
      0
    );
    Integer ingestas = [
      SELECT COUNT()
      FROM Ingesta_MBT__c
      WHERE Fecha_Ingesta__c >= :inicioHoy
        AND Fecha_Ingesta__c < :inicioHoy.addDays(1)
    ];
    if (ingestas == 0) {
      enviarAlerta(hoy);
    }
  }

  private static Boolean esDiaHabil(Date d) {
    Integer diaSemana = Integer.valueOf(
      Datetime.newInstance(d.year(), d.month(), d.day()).format('u')
    );
    return diaSemana >= 1 && diaSemana <= 5;
  }

  private static void enviarAlerta(Date hoy) {
    Messaging.SingleEmailMessage correo = new Messaging.SingleEmailMessage();
    correo.setToAddresses(new List<String>{ CORREO_OPERACIONES });
    correo.setSubject(ASUNTO_ALERTA + ' - ' + hoy.format());
    correo.setPlainTextBody(
      'No se registró ninguna ingesta de MBT en el día ' + hoy.format() + '.'
    );
    correo.setSaveAsActivity(false);
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ correo }, false);
  }
}
