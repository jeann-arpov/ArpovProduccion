/**
 * @description Controller Apex expuesto para que LWC registren errores en ErrorLog__c.
 *              Fire-and-forget: no bloquea al usuario, no retorna resultados.
 * @date 2026-07-31
 */
public with sharing class ErrorLogLWCController {

    /**
     * @description Registra un error desde el frontend LWC.
     *              Se llama en modo fire-and-forget (sin await) desde el JS.
     */
    @AuraEnabled(Cacheable=false)
    public static void logClientError(String errorMessage, String componentName,
                                       String pageUrl, String userMessage, String contextJson) {
        Map<String, Object> contextData = new Map<String, Object>();
        contextData.put('source', 'LWC');
        contextData.put('componentName', componentName);
        contextData.put('pageUrl', pageUrl);

        if (String.isNotBlank(contextJson)) {
            try {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(contextJson);
                contextData.putAll(parsed);
            } catch (Exception e) {
                contextData.put('contextParseError', e.getMessage());
            }
        }

        ErrorLogService.logMessage(errorMessage, 'ERR-LWC-001',
                                    ErrorLogService.Severity.ERROR, componentName, contextData);
    }
}
