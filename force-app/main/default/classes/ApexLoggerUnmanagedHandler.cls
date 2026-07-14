global class ApexLoggerUnmanagedHandler extends ERPvs.ApexLoggerHandler{
    global override void debug(LoggingLevel loggingLevel, String label, Object msg){
        System.Debug(loggingLevel, label + ': ' + msg);
    }
}