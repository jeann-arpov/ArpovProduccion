public with sharing class ErrorLogLWCController {
    @AuraEnabled(Cacheable=false)
    public static void logClientError(String errorMessage, String componentName, String pageUrl, String userMessage, String contextJson) {
        Map<String, Object> contextData = new Map<String, Object>();
        contextData.put('source', 'LWC');
        contextData.put('componentName', componentName);
        contextData.put('pageUrl', pageUrl);
        if (String.isNotBlank(contextJson)) {
            try { contextData.putAll((Map<String, Object>) JSON.deserializeUntyped(contextJson)); }
            catch (Exception e) { contextData.put('contextParseError', e.getMessage()); }
        }
        ErrorLogService.logMessage(errorMessage, 'ERR-LWC-001', ErrorLogService.Severity.ERROR, componentName, contextData);
    }
}
