public with sharing class BatchApexSyncTransaccionesHzpc implements Database.Batchable<sObject>, Database.AllowsCallouts {

    public static final Integer BATCH_SIZE = 200;

    public Set<Id> transaccionesIds;
    public TriggerOperation context;

    public BatchApexSyncTransaccionesHzpc(Set<Id> transaccionesIds, TriggerOperation context) {
        this.transaccionesIds = transaccionesIds;
        this.context = context;
    }

    public List<Transaccion__c> start(Database.BatchableContext bc){
        Id thisJobId = bc.getJobId();

        List<AsyncApexJob> lstJobs = [SELECT Id FROM AsyncApexJob WHERE status IN ('Pending', 'Processing') AND ApexClass.Name = 'BatchApexSyncTransaccionesHzpc' AND id != :thisJobId];
        if(lstJobs.isEmpty() == false){
            return new List<Transaccion__c>();
        }

        return getTransaccionesToSync(transaccionesIds);
    }
    
    public void execute(Database.BatchableContext bc, List<Transaccion__c> scope){
        try {
            HzpcSync.doSyncTransacciones(scope, context);
        } catch (Exception e) {
            System.debug(e.getStackTraceString());
            System.debug(e.getMessage());
        }
    }

    public static List<Transaccion__c> getTransaccionesToSync(Set<Id> transaccionesIds){
        return [SELECT Id, Name, HZPCId__c, Apellido_y_Nombre__c, Ano_Campana__c, Campana_Calculada__c, Cantidad_Bolsas_RC__c, Cantidad_Bolsas_RE__c, Comprobante_Original__c,
                    Contacto__r.Name, Cuenta_Estado__c, N_CUIT__c, Cultivo__r.Name, Descripcion_del_Lote__c, Divisa_Comprobante__c, DUP_Original__r.Name,
                    Edad_de_la_Respuesta__c, Estado__c, Estado_Remesa__c, Etapa__c, Factura__r.Name, Fecha_Alta__c, Fecha_de_Respuesta__c, Fecha_de_Vencimiento__c,
                    Fecha_Emision_Comprobante__c, Fecha_Pedido_Facturacion__c, Fecha_Vencimiento_Comprobante__c, Importe_Total__c, Inscripciones_IIBB__c,
                    Localidad__r.Name, Lote__r.Name, Mes_de_la_Respuesta__c, Modo_de_Envio__c, Neto_Comprobante__c, No_Facturar_por_Deuda__c, Nombre_del_Lote__c, Saldo_a_Cobrar__c,
                    Nro_de_IIBB__c, Numerador__c, Nro_Comprobante_Opp__c, Numero_de_Documento__c, Provincia__r.Name, Razon_Social__c, Remesa__r.Name, Resultado_Validacion_Analista__c,
                    Saldo_Actualizado__c, Subestado__c, Tipo_de_Cambio__c, Tipo_de_Cambio_Actualizado__c, Tipo_de_Cambio_del_Comprobante__c, Tipo_de_Comprobante__c,
                    Tipo_de_Documento__c, Tipo_de_Lote__c, Total_Comprobante__c, Variedades__c, Zona__c, Fecha_Facturacion__c, Factura__r.Neto_Comprobante_ARS__c,
                    Factura__r.Total_Comprobante_ARS__c, Factura__r.Saldo_a_Gestionar__c, Factura__r.Saldo_a_Gestionar_ARS__c, Factura__r.Total_Pagos_Recibidos__c,
                    Factura__r.Pagos_Recibidos__c, Factura__r.Percepciones__c, Factura__r.Saldo_a_Cobrar_ARS__c, Factura__r.Saldo_a_Cobrar_Comprobante__c
                FROM Transaccion__c WHERE Id IN :transaccionesIds];
    }

    public void finish(Database.BatchableContext bc){
        System.debug('Sincronización finalizada');
    }
}