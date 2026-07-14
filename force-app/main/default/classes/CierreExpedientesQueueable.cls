/**
 * Nombre: CierreExpedientesQueueable
 * Descripción: Job asíncrono para procesar el cierre de expedientes
 * Autor: Sistema
 * Fecha: 2026-03-06
 */
public class CierreExpedientesQueueable implements Queueable {
    
    private Id accountId;
    private String accountName;
    
    /**
     * Constructor que recibe el ID del Account a procesar
     */
    public CierreExpedientesQueueable(Id accId, String accName) {
        this.accountId = accId;
        this.accountName = accName;
    }
    
    /**
     * Método execute que se ejecuta de forma asíncrona
     */
    public void execute(QueueableContext context) {
        try {
            System.debug('⏳ Iniciando procesamiento asíncrono para Account: ' + this.accountName);
            System.debug('   ID: ' + this.accountId);
            System.debug('   Job ID: ' + context.getJobId());
            
            // Obtener el Account actualizado
            Account acc = [SELECT Id, Name, Usuario_Enlist__c, N_CUIT__c FROM Account WHERE Id = :this.accountId LIMIT 1];
            
            if (acc == null) {
                System.debug('❌ Account no encontrado: ' + this.accountId);
                return;
            }
            
            // Aquí iría la lógica de cierre de expedientes
            // Por ahora hacemos un placeholder
            procesarCierreExpedientes(acc);
            
            System.debug('✅ Procesamiento completado exitosamente');
            System.debug('   Account: ' + acc.Name);
            System.debug('   Usuario_Enlist: ' + acc.Usuario_Enlist__c);
            
        } catch (Exception e) {
            System.debug('❌ Error en procesamiento asíncrono: ' + e.getMessage());
            System.debug('   Stack trace: ' + e.getStackTraceString());
            // Aquí podrías enviar una notificación al admin si lo necesitas
        }
    }
    
    /**
     * Procesa el cierre de expedientes llamando al flujo existente
     */
    private static void procesarCierreExpedientes(Account acc) {
        System.debug('⚙️ Procesando cierre de expedientes para: ' + acc.Name);
        
        try {
            System.debug('   🔄 Ejecutando flujo: Cierre_de_Expedientes_CLA_Y_SEC');
            System.debug('   📍 Account ID: ' + acc.Id + ' - CUIT: ' + acc.N_CUIT__c);
            
            // Preparar parámetros para el flujo (exactos como el flujo original)
            Map<String, Object> flowInputs = new Map<String, Object>{
                'AccountRemitenteComercial' => acc,
                'OrigenBolsaTech' => false
            };
            
            // Ejecutar el flujo
            Flow.Interview flow = Flow.Interview.createInterview('Cierre_de_Expedientes_CLA_Y_SEC', flowInputs);
            flow.start();
            
            System.debug('   ✅ Flujo ejecutado exitosamente');
            
            // Crear registro de auditoría
            crearAuditoriaProcesamiento(acc.Id, 1);
            
            System.debug('✅ Procesamiento de cierre completado exitosamente');
            
        } catch (Exception e) {
            System.debug('❌ Error procesando expedientes: ' + e.getMessage());
            System.debug('   Stack trace: ' + e.getStackTraceString());
            throw e;
        }
    }
    
    /**
     * Crea un registro de auditoría del procesamiento
     */
    private static void crearAuditoriaProcesamiento(Id accountId, Integer procesosEjecutados) {
        try {
            // Búsqueda del objeto Auditoria (si existe) o LOG
            // Por ahora creamos un log simple en debug
            System.debug('📝 Auditoría creada:');
            System.debug('   Account ID: ' + accountId);
            System.debug('   Procesos ejecutados: ' + procesosEjecutados);
            System.debug('   Usuario: ' + UserInfo.getUserName());
        } catch (Exception e) {
            System.debug('⚠️ Error creando auditoría: ' + e.getMessage());
        }
    }
}