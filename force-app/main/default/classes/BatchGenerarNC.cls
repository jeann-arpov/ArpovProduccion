public class BatchGenerarNC implements Database.Batchable<Sobject>, Database.AllowsCallouts, Schedulable, Database.Stateful {
    private List<String> errors = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Id sembra = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Sembra_Evolucion').getRecordTypeId();
        return Database.getQueryLocator([select ERPvs__Comprobante_Venta__c from ERPvs__Vencimientos__c where ERPvs__Fecha_Vencimiento__c <: System.today() and ERPvs__Importe_MO__c != 0 and ERPvs__Comprobante_Venta__r.ERPvs__Tipo_comp__c = 'Factura' and ERPvs__Comprobante_Venta__r.Oportunidad__r.RecordTypeId =: sembra]);
    }

    public void execute(Database.BatchableContext BC, List<ERPvs__Vencimientos__c> scope) {
        for (ERPvs__Vencimientos__c ven: scope) {
            List<String> result = ERPvs.GeneraComprobanteNCController.generarNCDeCV(ven.ERPvs__Comprobante_Venta__c);
            if (result[0] == '0') errors.add(ven.id + ' error ' + result[1]);
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        BatchErrorHelper.sendEmail(BC.getJobId(), errors, 'Errores en BatchGenerarNC');
    }

    public void execute(SchedulableContext sc) {
        database.executebatch(new BatchGenerarNC(), 1);
    }
}