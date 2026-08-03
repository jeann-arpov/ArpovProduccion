/**
 * @description Clase base para controllers Apex. Encapsula el patron:
 *              loggear error en ErrorLog__c + retornar AuraHandledException con
 *              mensaje amigable + codigo de error para el usuario.
 * @date 2026-07-31
 *
 * @example
 *   public class CrearVentaController extends ApexErrorHandler {
 *       @AuraEnabled
 *       public static void guardar(Id ventaId) {
 *           try {
 *               // logica de negocio
 *           } catch (Exception e) {
 *               throw handleException(e, 'ERR-VTA-001', 'CrearVenta', ventaId);
 *           }
 *       }
 *   }
 */
public virtual with sharing class ApexErrorHandler {

    /**
     * @description Maneja una excepcion: loguea y lanza mensaje amigable.
     */
    protected static AuraHandledException handleException(Exception ex, String errorCode,
                                                           String component) {
        return handleException(ex, errorCode, component, null, null);
    }

    protected static AuraHandledException handleException(Exception ex, String errorCode,
                                                           String component, Id recordId) {
        Map<String, Object> ctx = new Map<String, Object>();
        if (recordId != null) ctx.put('recordId', recordId);
        return handleException(ex, errorCode, component, ctx, null);
    }

    protected static AuraHandledException handleException(Exception ex, String errorCode,
                                                           String component,
                                                           Map<String, Object> contextData) {
        return handleException(ex, errorCode, component, contextData, null);
    }

    /**
     * @description Maneja una excepcion con mensaje personalizado adicional.
     * @param customMessage Mensaje extra que se guarda en el contexto (ej: 'No se pudo validar la cuenta')
     */
    protected static AuraHandledException handleException(Exception ex, String errorCode,
                                                           String component,
                                                           Map<String, Object> contextData,
                                                           String customMessage) {
        if (contextData == null) contextData = new Map<String, Object>();
        contextData.put('handler', 'ApexErrorHandler');

        if (String.isNotBlank(customMessage)) {
            contextData.put('customMessage', customMessage);
        }

        ErrorLogService.log(ex, errorCode, ErrorLogService.Severity.ERROR, component, contextData);

        String userMsg = ErrorLogService.getUserFriendlyMessage(errorCode);
        AuraHandledException auraEx = new AuraHandledException(userMsg);
        auraEx.setMessage(userMsg);
        return auraEx;
    }

    /**
     * @description Loguea un warning sin detener la ejecucion.
     */
    protected static void logWarning(Exception ex, String errorCode, String component,
                                     Map<String, Object> contextData) {
        if (contextData == null) contextData = new Map<String, Object>();
        ErrorLogService.log(ex, errorCode, ErrorLogService.Severity.WARNING, component, contextData);
    }

    /**
     * @description Loguea un mensaje informativo para auditoria.
     */
    protected static void logInfo(String message, String errorCode, String component,
                                  Map<String, Object> contextData) {
        if (contextData == null) contextData = new Map<String, Object>();
        ErrorLogService.logMessage(message, errorCode, ErrorLogService.Severity.INFO, component, contextData);
    }
}
