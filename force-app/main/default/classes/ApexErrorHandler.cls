public virtual class ApexErrorHandler {

    public static AuraHandledException handleException(Exception e, String errorCode, String module) {
        System.debug(LoggingLevel.ERROR, '[' + module + '][' + errorCode + '] ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, e.getStackTraceString());
        return new AuraHandledException('[' + errorCode + '] ' + e.getMessage());
    }

    public static AuraHandledException handleException(Exception e, String errorCode, String module, String userMessage) {
        System.debug(LoggingLevel.ERROR, '[' + module + '][' + errorCode + '] ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, e.getStackTraceString());
        return new AuraHandledException(userMessage + ': ' + e.getMessage());
    }
}
