/**
 * @description Servicio centralizado de logging de errores para Sembra Evolucion.
 *              Registra en ErrorLog__c con stack trace, clase, metodo, linea y contexto.
 *              Genera mensajes amigables para el usuario final con codigo de error.
 *              Escritura asincrona via @future para no impactar rendimiento.
 */
public with sharing class ErrorLogService {

    public enum Severity { FATAL, ERROR, WARNING, INFO }

    private static Boolean syncMode = false;

    public static void log(Exception ex, String errorCode, Severity severity,
                           String component, Map<String, Object> contextData) {
        ErrorLog__c entry = buildEntry(ex, errorCode, severity, component, contextData);
        if (syncMode || System.isFuture() || System.isBatch() || System.isQueueable()) {
            insertLog(entry);
        } else {
            logAsync(JSON.serialize(entry, true));
        }
    }

    public static void logMessage(String message, String errorCode, Severity severity,
                                  String component, Map<String, Object> contextData) {
        ErrorLog__c entry = buildEntry(null, errorCode, severity, component, contextData);
        entry.OriginalMessage__c = message;
        if (syncMode || System.isFuture() || System.isBatch() || System.isQueueable()) {
            insertLog(entry);
        } else {
            logAsync(JSON.serialize(entry, true));
        }
    }

    public static String getUserFriendlyMessage(String errorCode) {
        String description = getDefaultDescription(errorCode);
        return 'Error ' + errorCode + '. ' + description +
               ' Si el problema persiste, contacte a Mesa de Ayuda e informe el codigo ' + errorCode + '.';
    }

    private static String getDefaultDescription(String errorCode) {
        if (String.isBlank(errorCode)) return 'Ha ocurrido un problema inesperado.';
        Map<String, String> descriptions = new Map<String, String>{
            'ERR-VTA' => 'Ocurrio un problema al procesar la operacion de venta. Intente nuevamente.',
            'ERR-CES' => 'Ocurrio un problema al procesar la cesion de hectareas. Intente nuevamente.',
            'ERR-ADH' => 'Ocurrio un problema al procesar la adhesion a plan de siembra. Intente nuevamente.',
            'ERR-COM' => 'Ocurrio un problema al procesar la compra de HT. Intente nuevamente.',
            'ERR-LIC' => 'Ocurrio un problema al procesar la licencia. Intente nuevamente.',
            'ERR-FAC' => 'Ocurrio un problema al procesar la facturacion o pago. Intente nuevamente.',
            'ERR-DUP' => 'Ocurrio un problema al procesar DUP. Intente nuevamente.',
            'ERR-TRANS' => 'Ocurrio un problema al procesar la transaccion. Intente nuevamente.',
            'ERR-EXP' => 'Ocurrio un problema al procesar el expediente. Intente nuevamente.',
            'ERR-NC' => 'Ocurrio un problema al procesar la nota de credito. Intente nuevamente.',
            'ERR-INT' => 'Ocurrio un problema de integracion con un sistema externo. Intente nuevamente.',
            'ERR-SYS' => 'Ocurrio un problema interno del sistema.',
            'ERR-LWC' => 'Ocurrio un problema en la interfaz de usuario. Recargue la pagina e intente nuevamente.',
            'ERR-FLOW' => 'Ocurrio un problema en el flujo de trabajo automatizado.',
            'ERR-VAL' => 'No se cumple una condicion requerida por el sistema.'
        };
        for (String prefix : descriptions.keySet()) {
            if (errorCode.startsWithIgnoreCase(prefix)) return descriptions.get(prefix);
        }
        return 'Ocurrio un problema inesperado. Intente nuevamente.';
    }

    private static ErrorLog__c buildEntry(Exception ex, String errorCode, Severity severity,
                                          String component, Map<String, Object> contextData) {
        ErrorLog__c entry = new ErrorLog__c();
        entry.ErrorCode__c = errorCode;
        entry.Severity__c = severity.name();
        entry.Component__c = component;
        entry.Origin__c = getOrigin();
        entry.Environment__c = getEnvironment();
        entry.Timestamp__c = DateTime.now();
        entry.UserId__c = UserInfo.getUserId();
        entry.UserMessage__c = getUserFriendlyMessage(errorCode);
        if (ex != null) {
            entry.OriginalMessage__c = ex.getMessage();
            entry.StackTrace__c = ex.getStackTraceString();
            entry.ClassName__c = extractClassName(ex);
            entry.MethodName__c = extractMethodName(ex);
            entry.LineNumber__c = extractLineNumber(ex);
            if (ex instanceof CalloutException) extractHttpStatus(ex, entry);
        }
        if (contextData != null) {
            contextData.put('loggedAt', DateTime.now().formatGmt('yyyy-MM-dd HH:mm:ss'));
            contextData.put('environment', getEnvironment());
            contextData.put('runningUser', UserInfo.getUserName());
            entry.ContextData__c = JSON.serializePretty(contextData);
            if (contextData.containsKey('recordId')) {
                entry.RelatedRecordId__c = String.valueOf(contextData.get('recordId'));
            }
        }
        return entry;
    }

    private static void insertLog(ErrorLog__c entry) {
        try { insert entry; }
        catch (Exception e) { System.debug(LoggingLevel.ERROR, '[ErrorLogService] FALLO al insertar: ' + e.getMessage()); }
    }

    @future private static void logAsync(String logJson) {
        try { insert (ErrorLog__c) JSON.deserialize(logJson, ErrorLog__c.class); }
        catch (Exception e) { System.debug(LoggingLevel.ERROR, '[ErrorLogService] FALLO async: ' + e.getMessage()); }
    }

    private static String getOrigin() {
        if (Trigger.isExecuting) return 'TRIGGER';
        if (System.isBatch()) return 'BATCH';
        return 'APEX';
    }

    private static String getEnvironment() {
        String host = URL.getOrgDomainUrl().toExternalForm().toLowerCase();
        return host.contains('sandbox') || host.contains('--') ? 'SANDBOX' : 'PROD';
    }

    private static String extractClassName(Exception ex) {
        if (ex == null) return null;
        String stack = ex.getStackTraceString();
        if (String.isBlank(stack)) return ex.getTypeName();
        Matcher m = Pattern.compile('Class\\.(\\w+)\\.').matcher(stack);
        return m.find() ? m.group(1) : ex.getTypeName();
    }

    private static String extractMethodName(Exception ex) {
        if (ex == null) return null;
        String stack = ex.getStackTraceString();
        if (String.isBlank(stack)) return null;
        Matcher m = Pattern.compile('Class\\.\\w+\\.(\\w+):').matcher(stack);
        return m.find() ? m.group(1) : null;
    }

    private static Integer extractLineNumber(Exception ex) {
        if (ex == null) return null;
        String stack = ex.getStackTraceString();
        if (String.isBlank(stack)) return null;
        Matcher m = Pattern.compile('line (\\d+)').matcher(stack);
        return m.find() ? Integer.valueOf(m.group(1)) : null;
    }

    private static void extractHttpStatus(Exception ex, ErrorLog__c entry) {
        String msg = ex.getMessage();
        if (msg != null) {
            Matcher m = Pattern.compile('StatusCode=(\\d{3})').matcher(msg);
            if (m.find()) entry.HttpStatusCode__c = m.group(1);
        }
    }

    @TestVisible private static void setSyncMode(Boolean value) { syncMode = value; }
}
