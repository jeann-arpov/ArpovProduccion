public virtual with sharing class ApexErrorHandler {
    public static AuraHandledException handleException(Exception ex, String errorCode, String component) {
        return handleException(ex, errorCode, component, null, null);
    }
    public static AuraHandledException handleException(Exception ex, String errorCode, String component, Id recordId) {
        Map<String, Object> ctx = new Map<String, Object>();
        if (recordId != null) ctx.put('recordId', recordId);
        return handleException(ex, errorCode, component, ctx, null);
    }
    public static AuraHandledException handleException(Exception ex, String errorCode, String component, Map<String, Object> contextData) {
        return handleException(ex, errorCode, component, contextData, null);
    }
    public static AuraHandledException handleException(Exception ex, String errorCode, String component, Map<String, Object> contextData, String customMessage) {
        if (contextData == null) contextData = new Map<String, Object>();
        contextData.put('handler', 'ApexErrorHandler');
        if (String.isNotBlank(customMessage)) contextData.put('customMessage', customMessage);
        ErrorLogService.log(ex, errorCode, ErrorLogService.Severity.ERROR, component, contextData);
        String userMsg = ErrorLogService.getUserFriendlyMessage(errorCode);
        AuraHandledException auraEx = new AuraHandledException(userMsg);
        auraEx.setMessage(userMsg);
        return auraEx;
    }
    public static void logWarning(Exception ex, String errorCode, String component, Map<String, Object> contextData) {
        if (contextData == null) contextData = new Map<String, Object>();
        ErrorLogService.log(ex, errorCode, ErrorLogService.Severity.WARNING, component, contextData);
    }
    public static void logInfo(String message, String errorCode, String component, Map<String, Object> contextData) {
        if (contextData == null) contextData = new Map<String, Object>();
        ErrorLogService.logMessage(message, errorCode, ErrorLogService.Severity.INFO, component, contextData);
    }
}
