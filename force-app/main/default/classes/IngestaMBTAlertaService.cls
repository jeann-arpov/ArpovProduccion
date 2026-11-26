/**
 * Servicio de alerta por falta de ingesta de MBT (archivos varietales).
 *
 * Lógica:
 *  - Solo evalúa en días hábiles (no feriado + dentro de BusinessHours).
 *  - Solo espera archivo de lunes a jueves: el viernes (con sábado y domingo)
 *    se informa el lunes, así que ese día no se controla.
 *  - Si no hay Ingesta_MBT__c con Fecha_Ingesta__c del día, avisa a la cola
 *    de Operaciones configurada en Custom Metadata (Configuracion_Ingesta_MBT__mdt):
 *      1. Email a los miembros activos de la cola.
 *      2. Notificación in-app (CustomNotification "Alerta_Ingesta_MBT").
 *
 * Se ejecuta desde ScheduleAlertaIngestaMBT (Schedulable) una vez al día.
 */
public with sharing class IngestaMBTAlertaService {
  private static final String ASUNTO_ALERTA = 'Alerta: no se registró ingesta de MBT';
  private static final String CONFIG_NAME = 'Default';
  private static final String TIPO_NOTIFICACION = 'Alerta_Ingesta_MBT';

  /**
   * Punto de entrada público: verifica la ingesta del día actual.
   * Equivale a verificarIngesta(Date.today(), Datetime.now()).
   */
  public static void verificarIngestaDelDia() {
    verificarIngesta(Date.today(), Datetime.now());
  }

  /**
   * Núcleo de la verificación, testeable con fecha/momento fijos.
   * Si la fecha es día hábil y no hay ingesta ese día, resuelve la cola de
   * Operaciones y dispara el email y la notificación in-app.
   *
   * @param fecha   Fecha a evaluar (para el conteo de ingestas del día).
   * @param momento Momento a evaluar contra el horario laboral.
   */
  @TestVisible
  private static void verificarIngesta(Date fecha, Datetime momento) {
    if (!esDiaHabil(fecha, momento) || !esDiaConArchivoEsperado(fecha)) {
      return;
    }
    Datetime inicio = Datetime.newInstance(
      fecha.year(),
      fecha.month(),
      fecha.day(),
      0,
      0,
      0
    );
    Integer ingestas = [
      SELECT COUNT()
      FROM Ingesta_MBT__c
      WHERE
        Fecha_Ingesta__c >= :inicio
        AND Fecha_Ingesta__c < :inicio.addDays(1)
    ];
    if (ingestas == 0) {
      Configuracion_Ingesta_MBT__mdt cfg = Configuracion_Ingesta_MBT__mdt.getInstance(
        CONFIG_NAME
      );
      if (cfg == null) {
        return;
      }

      Set<String> userIds = new Set<String>();
      String colaNombre = cfg.Cola_Operaciones__c;
      if (String.isNotBlank(colaNombre)) {
        userIds = obtenerMiembrosCola(colaNombre);
      }

      List<String> correos = new List<String>();
      if (!userIds.isEmpty()) {
        for (User u : [
          SELECT Email
          FROM User
          WHERE Id IN :userIds AND IsActive = TRUE
        ]) {
          if (String.isNotBlank(u.Email)) {
            correos.add(u.Email);
          }
        }
      }

      if (!correos.isEmpty()) {
        enviarAlerta(correos, fecha);
      }
      if (!userIds.isEmpty()) {
        enviarNotificacion(userIds, fecha);
      }
    }
  }

  /**
   * Determina si hoy es día hábil (conveniencia: hoy + ahora).
   *
   * @return true si hoy es día hábil.
   */
  @TestVisible
  private static Boolean esDiaHabil() {
    return esDiaHabil(Date.today(), Datetime.now());
  }

  /**
   * Determina si la fecha/momento dados son día hábil:
   *  1. No debe ser feriado (objeto estándar Holiday).
   *  2. Debe estar dentro del horario laboral (BusinessHours, configurable en la org).
   * Sin BusinessHours activo configurado no se considera día hábil (sin fallback).
   *
   * @param fecha   Fecha a evaluar.
   * @param momento Momento (hora) a evaluar dentro del horario laboral.
   * @return true si es día hábil.
   */
  @TestVisible
  private static Boolean esDiaHabil(Date fecha, Datetime momento) {
    Integer feriados = [
      SELECT COUNT()
      FROM Holiday
      WHERE ActivityDate = :fecha
    ];
    if (feriados > 0) {
      return false;
    }

    List<BusinessHours> bhs = [
      SELECT Id
      FROM BusinessHours
      WHERE IsActive = TRUE
      ORDER BY IsDefault DESC, CreatedDate ASC
      LIMIT 1
    ];
    if (bhs.isEmpty()) {
      return false;
    }
    return BusinessHours.isWithin(bhs[0].Id, momento);
  }

  /**
   * Determina si la fecha es un día con archivo esperado: lunes a jueves.
   * El viernes (junto con sábado y domingo) se informa el lunes,
   * por lo que ese día no se espera archivo.
   *
   * @param fecha Fecha a evaluar.
   * @return true si es lunes, martes, miércoles o jueves.
   */
  @TestVisible
  private static Boolean esDiaConArchivoEsperado(Date fecha) {
    Datetime momento = Datetime.newInstance(
      fecha.year(),
      fecha.month(),
      fecha.day(),
      12,
      0,
      0
    );
    Integer diaSemana = Integer.valueOf(momento.format('u')); // 1=lun .. 7=dom
    return diaSemana >= 1 && diaSemana <= 4;
  }

  /**
   * Devuelve los Ids de usuario miembros de una cola (Queue) por su DeveloperName.
   *
   * @param colaNombre DeveloperName de la cola (Group con Type='Queue').
   * @return Set de Ids de usuario miembros (vacío si la cola no existe o no tiene miembros).
   */
  @TestVisible
  private static Set<String> obtenerMiembrosCola(String colaNombre) {
    Set<String> userIds = new Set<String>();
    List<Group> colas = [
      SELECT Id
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = :colaNombre
      LIMIT 1
    ];
    if (colas.isEmpty()) {
      return userIds;
    }
    for (GroupMember gm : [
      SELECT UserOrGroupId
      FROM GroupMember
      WHERE GroupId = :colas[0].Id
    ]) {
      userIds.add(gm.UserOrGroupId);
    }
    return userIds;
  }

  /**
   * Envía el email de alerta a los correos indicados.
   *
   * @param correos Lista de emails destinatarios.
   * @param fecha   Fecha del aviso (se incluye en asunto y cuerpo).
   */
  @TestVisible
  private static void enviarAlerta(List<String> correos, Date fecha) {
    Messaging.SingleEmailMessage mensaje = new Messaging.SingleEmailMessage();
    mensaje.setToAddresses(correos);
    mensaje.setSubject(ASUNTO_ALERTA + ' - ' + fecha.format());
    mensaje.setPlainTextBody(
      'No se registró ninguna ingesta de MBT en el día ' + fecha.format() + '.'
    );
    mensaje.setSaveAsActivity(false);
    Messaging.sendEmail(
      new List<Messaging.SingleEmailMessage>{ mensaje },
      false
    );
  }

  /**
   * Envía la notificación in-app (campanita) a los usuarios indicados.
   * Usa el CustomNotificationType "Alerta_Ingesta_MBT" con target de navegación
   * a la lista de Ingesta_MBT__c.
   *
   * @param userIds Set de Ids de usuario destinatarios.
   * @param fecha   Fecha del aviso (se incluye en el cuerpo).
   */
  @TestVisible
  private static void enviarNotificacion(Set<String> userIds, Date fecha) {
    List<CustomNotificationType> tipos = [
      SELECT Id
      FROM CustomNotificationType
      WHERE DeveloperName = :TIPO_NOTIFICACION
      LIMIT 1
    ];
    if (tipos.isEmpty()) {
      return;
    }

    Messaging.CustomNotification notif = new Messaging.CustomNotification();
    notif.setTitle(ASUNTO_ALERTA);
    notif.setBody(
      'No se registró ingesta de archivo varietal en el día ' +
        fecha.format() +
        '.'
    );
    notif.setNotificationTypeId(tipos[0].Id);
    notif.setTargetPageRef(
      '{"type":"standard__objectPage","attributes":{"objectApiName":"Ingesta_MBT__c","actionName":"list"}}'
    );
    notif.setSenderId(UserInfo.getUserId());
    notif.send(userIds);
  }
}
