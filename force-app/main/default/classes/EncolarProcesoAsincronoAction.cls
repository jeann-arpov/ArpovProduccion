/**
 * Nombre: EncolarProcesoAsincronoAction
 * Descripción: Acción Apex invocable que encola el procesamiento asíncrono
 * Autor: Sistema
 * Fecha: 2026-03-06
 */
public class EncolarProcesoAsincronoAction {
    
    /**
     * Método invocable que encola el procesamiento asíncrono
     * @param accountId ID del Account a procesar
     * @param accountName Nombre del Account
     */
    @InvocableMethod(label='Encolar Procesamiento Asíncrono' description='Encola el procesamiento de cierre de expedientes de forma asíncrona')
    public static void encolarProceso(List<EncolarRequest> requests) {
        try {
            for (EncolarRequest req : requests) {
                System.debug('📤 Encolando procesamiento para Account: ' + req.accountName);
                
                // Encolar el job asíncrono
                CierreExpedientesQueueable job = new CierreExpedientesQueueable(req.accountId, req.accountName);
                Id jobId = System.enqueueJob(job);
                
                System.debug('✅ Job encolado exitosamente');
                System.debug('   Job ID: ' + jobId);
                System.debug('   Account ID: ' + req.accountId);
                System.debug('   Account Name: ' + req.accountName);
            }
        } catch (Exception e) {System.debug('❌ Error al encolar el proceso: ' + e.getMessage());System.debug('   Tipo: ' + e.getTypeName());System.debug('   Stack: ' + e.getStackTraceString());throw new AuraHandledException('Error al procesar: ' + e.getMessage());
        }
    }
    
    /**
     * Clase interna para los parámetros de entrada
     */
    public class EncolarRequest {
        @InvocableVariable(label='Account ID' description='ID del Account a procesar' required=true)
        public Id accountId;
        
        @InvocableVariable(label='Account Name' description='Nombre del Account' required=true)
        public String accountName;
    }
}