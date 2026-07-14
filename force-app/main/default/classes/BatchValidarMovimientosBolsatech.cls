public class BatchValidarMovimientosBolsatech implements Database.Batchable<sObject>, Database.Stateful {
    List<String> errors = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([select Codigo_de_Muestra__c, CUIT_Titular__c, Cuit_Destinatario__c, Cuit_Remitente_Comercial__c, Peso_Neto__c, Fecha_de_Analisis__c, Cultivo__c, Tecnologia__c, CTG__c from Movimiento_BolsaTech__c where Estado__c in ('Creado', 'Con error')]);
    }

    public void execute(Database.BatchableContext BC, List<Movimiento_BolsaTech__c> scope) {
        Bolsatech.validate(scope);
        errors.addAll(BatchErrorHelper.getErrors(Database.update(scope, false), scope));
    }

    public void finish(Database.BatchableContext BC) {
        BatchErrorHelper.sendEmail(BC.getJobId(), errors, 'Arpov: Errores en BatchValidarMovimientosBolsatech');
    } 
}