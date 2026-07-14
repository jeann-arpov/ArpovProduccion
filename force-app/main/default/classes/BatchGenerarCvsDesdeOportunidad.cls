/*
    @author: julian
    @date: 22/4/2022
*/
public class BatchGenerarCvsDesdeOportunidad implements Database.Batchable<sObject>, Database.Stateful {
    
    private List<String> errors = new List<String>();
    private List<Id> ids = new List<Id>();

    public static final Integer BATCH_SIZE = 50;

    public BatchGenerarCvsDesdeOportunidad() {
        this(null);
    }

    public BatchGenerarCvsDesdeOportunidad(List<Id> oppIds) {
        this.ids = oppIds;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String extraCond = this.ids != null && this.ids.size() > 0 ? ' AND id in: ids' : '';
        extraCond += ' AND id not in (select Oportunidad__c from ERPvs__Comprobante_Venta__c where ERPvs__Contabilizar__c = false and ERPvs__Signo__c = -1)';  // ignoro las nc que ya se generaron
        extraCond += ' AND Punto_de_Venta__c != true'; // ignoro las que son para punto de venta
        return Database.getQueryLocator('select id from opportunity where Recordtype.Developername = \'Sembra_Evolucion\' and StageName = \'Pendiente de Facturación\' and Compra_HT__r.Resultado_Validacion_Analista__c = \'Positiva\' and id in (select opportunityId from OpportunityLineItem where Estado__c = \'Facturable\' and Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c = true AND Product2.Variedad2__r.Obtentor_Comercializa__r.Dias_de_Exclusion_de_Facturacion_SE__c excludes (\''+System.now().format('dd')+'\'))' + extraCond);
    }

    public void execute(Database.BatchableContext BC, List<Opportunity> scope) {
        errors.addAll(UtilsComprobanteVenta.createComprobantesVentaFromOpps(new Map<Id, Opportunity>(scope).keySet(), System.today()));
    }

    public void finish(Database.BatchableContext BC) {
        BatchErrorHelper.sendEmail(BC.getJobId(), errors, 'Errores en BatchGenerarCvsDesdeOportunidad');
    }
}