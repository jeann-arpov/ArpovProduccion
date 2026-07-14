public with sharing class BatchApexSyncItemsDupHzpc implements Database.Batchable<sObject>, Database.AllowsCallouts{
    public static final Integer BATCH_SIZE = 200;

    public Set<Id> itemsDupIds;
    public TriggerOperation context;

    public BatchApexSyncItemsDupHzpc(Set<Id> itemsDupIds, TriggerOperation context) {
        this.itemsDupIds = itemsDupIds;
        this.context = context;
    }

    public List<Item_de_DUP__c> start(Database.BatchableContext bc){
        Id thisJobId = bc.getJobId();

        List<AsyncApexJob> lstJobs = [SELECT Id FROM AsyncApexJob WHERE status IN ('Pending', 'Processing') AND ApexClass.Name = 'BatchApexSyncItemsDupHzpc' AND id != :thisJobId];
        if(lstJobs.isEmpty() == false){
            return new List<Item_de_DUP__c>();
        }

        return getItemsToSync(itemsDupIds);
    }
    
    public void execute(Database.BatchableContext bc, List<Item_de_DUP__c> scope){
        try {
            HzpcSync.doSyncItemsDup(scope, context);
        } catch (Exception e) {
            System.debug(e.getStackTraceString());
            System.debug(e.getMessage());
        }
    }

    public static List<Item_de_DUP__c> getItemsToSync(Set<Id> itemsDupIds){
        return [SELECT Id, Name, HZPCId__c, Activo__c, Descuento__c, Anulacion__c, Campana_Ano__c, Campana_Calculada__c, Cantidad_Bolsas_40__c, Cantidad_Facturacion_En_Bolsas_50__c,
                        Cantidad_de_Facturacion__c, Cantidad_Declarada__c, Cantidad_Entregada__c, Cantidad_Ingresada__c, Conversion__c, N_CUIT__c, Densidad_de_Siembra__c,
                        Descuento_Producto__c, Establecimientos__c, Estado__c, Estado_de_Aprobaci_n__c, Hectareas_Declaradas__c, Hectareas_Calculadas__c,
                        Importe_Descuento__c, Importe_Descuento_Producto__c, Kilos_Totales__c, Lugar_de_Siembra__r.Name, Lugar_de_Siembra_Default__c, No_Facturar__c,
                        No_Facturar_por_Deuda__c, Nombre_Producto__c, Unidades_a_Cobrar__c, Precio_Unitario_Producto__c, Tipo_de_Producto__c, Total_a_Facturar__c,
                        Producto__r.Name, Siembra_de_Segunda__c, Sin_Regalia_Extendida__c, Tiene_Aplicaciones__c, Tipo_de_Cambio__c, Total_Bruto__c, Variedad__c,
                        Transaccion__r.HZPCId__c, Z9_Unidad_de_Medida_de_Facturacion__c, Unidad_de_Medida_de_Facturacion_TXT__c, Unidad_de_Medida_Declarada__c
                FROM Item_de_DUP__c WHERE Id IN :itemsDupIds];
    }

    public void finish(Database.BatchableContext bc){
        System.debug('Sincronización finalizada');
    }
}