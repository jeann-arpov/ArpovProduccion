/**
* @author Maximo Martinez
* @date 25/11/2015
* @description Clase Batcheable que se encarga de generar objetos ERPvs__Comprobante_Venta__c a partir de 
* @description objetos Transaccion__c y objetos ERPvs__Productos_Comprobante_de_Venta__c a partir de 
* @description objetos Item_de_DUP__c y Item_Auditoria__c
*/
global class BatchApexGeneracionComprobantesVentas implements Database.Batchable<sObject>, Database.Stateful {
    //Test_BatchApexGeneracionComprobVentas
    /**
    * @description Variable estatica indica el tamaño del lote
    */  
    public static Integer BATCH_SIZE = 50;

    public Date batchDate {get; set;}

    public Set<Id> idsTransacciones = new Set<Id>();

    public List<String> errors;

    global BatchApexGeneracionComprobantesVentas(Date batchDate) {
        this(new Set<Id>(), batchDate);
    }

    global BatchApexGeneracionComprobantesVentas() {
        this(Date.today());
    }

    global BatchApexGeneracionComprobantesVentas(Set<Id> ids) {
        this(ids, Date.today());
    }    

    BatchApexGeneracionComprobantesVentas(Set<Id> ids, Date batchDate) {
        this.idsTransacciones = ids;
        this.batchDate = batchDate;
        this.errors = new List<String>();
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        
        String proceccesDay = UtilsAccount.getExclusionDay(batchDate);
        
        //String query = 'SELECT Id, RecordType.DeveloperName, (SELECT Id FROM Oportunidades__r), (SELECT Id FROM Items_Auditorias__r WHERE Resultado__c = \'Irregular\'  AND Cantidad_de_Facturacion__c != null AND Cantidad_de_Facturacion__c != 0 AND No_Facturar__c = false), (SELECT Id, Producto__r.ERPvs_Producto__c FROM Item_de_DUP__r WHERE Estado__c != \'Consumo\' AND Cantidad_de_Facturacion__c != null AND Cantidad_de_Facturacion__c != 0 AND No_Facturar__c = false), (SELECT Id FROM Comprobantes_Venta__r) FROM Transaccion__c WHERE ((RecordType.DeveloperName = \'Auditorias\' AND Z9_Items_Auditoria_Facturar__c > 0 AND Estado__c = \'Completa\') OR (RecordType.DeveloperName = \'DUP\' AND Z9_Items_Dup_Facturar__c > 0 AND ((Estado__c = \'Respondida\' OR Estado__c = \'Respondida Parcialmente\') AND (Respondida_via_Minisitio__c = false OR (Respondida_via_Minisitio__c = true AND Resultado_Validacion_Analista__c = \'Positiva\') ) ) ) ) AND Z9_Cambio__c = true AND Obtentor__r.Dias_de_Exclusion_de_Facturacion__c EXCLUDES(:proceccesDay) AND Obtentor__r.Factura_por_Cuenta_y_Orden__c = true AND Nombre_de_la_cuenta__r.Estado__c = \'Activo\' AND Tiene_CV__c = false AND No_Facturar__c = false AND Nombre_de_la_cuenta__r.ERPvs__Activa__c = true AND Subestado__c IN (\'POSITIVA\',\'NEGATIVA\')';
        String query = 'SELECT Id, Name, Nombre_de_la_cuenta__r.Name, Nombre_de_la_cuenta__r.ERPvs__Activa__c, RecordType.DeveloperName, (SELECT Id FROM Oportunidades__r), (SELECT Id, Producto__r.Name, Producto__r.ERPvs_Producto__c FROM Items_Auditorias__r WHERE Resultado__c = \'Irregular\'  AND Cantidad_de_Facturacion__c != null AND Cantidad_de_Facturacion__c != 0 AND No_Facturar__c = false), (SELECT Id, Producto__r.Name, Producto__r.ERPvs_Producto__c FROM Item_de_DUP__r WHERE Estado__c != \'Consumo\' AND Cantidad_de_Facturacion__c != null AND Cantidad_de_Facturacion__c != 0 AND No_Facturar__c = false), (SELECT Id FROM Comprobantes_Venta__r) FROM Transaccion__c WHERE ((RecordType.DeveloperName = \'Auditorias\' AND Z9_Items_Auditoria_Facturar__c > 0 AND Estado__c = \'Completa\') OR (RecordType.DeveloperName = \'DUP\' AND Z9_Items_Dup_Facturar__c > 0 AND ((Estado__c = \'Respondida\' OR Estado__c = \'Respondida Parcialmente\') AND (Respondida_via_Minisitio__c = false OR (Respondida_via_Minisitio__c = true AND Resultado_Validacion_Analista__c = \'Positiva\') ) ) ) ) AND Z9_Cambio__c = true AND Obtentor__r.Dias_de_Exclusion_de_Facturacion__c EXCLUDES(:proceccesDay) AND Obtentor__r.Factura_por_Cuenta_y_Orden__c = true AND Nombre_de_la_cuenta__r.Estado__c = \'Activo\' AND Tiene_CV__c = false AND No_Facturar__c = false AND Subestado__c IN (\'POSITIVA\',\'NEGATIVA\') AND Factura__c != null';
        
        if(idsTransacciones != null && !idsTransacciones.isEmpty()){

            query += ' AND Id IN :idsTransacciones';

        }

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Transaccion__c> scope) {
        //Procesamos cada lote de Transacciones Completas, separando en dos Sets aquellas transacciones
        //de tipo Auditoria de aquellas de tipo DUP
        
        //Set para coleccionar los Ids de las Transacciones de tipo Auditoria
        Set<Id> auditorias = new Set<Id>();
        
        //Set para coleccionar los Ids de las Transacciones de tipo DUP
        Set<Id> dups = new Set<Id>();
        
        for(Transaccion__c transaccion : scope){
        
            if(transaccion.RecordType.DeveloperName == 'DUP'){

                //FL 2019-02-01 Control de cuenta activa. Antes se filtraba en la query pero quieren enviar un mail con el problema.
                if(!transaccion.Nombre_de_la_cuenta__r.ERPvs__Activa__c){
                    errors.add('Transaccion ' + transaccion.Name + ': La cuenta ' + transaccion.Nombre_de_la_cuenta__r.Name + ' no está activa' + '\n');
                    continue;
                }

                if (transaccion.Item_de_DUP__r.isEmpty() || transaccion.Oportunidades__r.isEmpty()) continue;

                Boolean errorProducto = false;
                for(Item_de_DUP__c item : transaccion.Item_de_DUP__r) {
                    errorProducto = checkError(transaccion, item.Producto__r) || errorProducto;
                }

                if (!errorProducto) dups.add(transaccion.Id);
            }else if(transaccion.RecordType.DeveloperName == 'Auditorias' || transaccion.Oportunidades__r.isEmpty()){
                Boolean errorProducto = false;
                for(Item_Auditoria__c item : transaccion.Items_Auditorias__r){
                    errorProducto = checkError(transaccion, item.Producto__r) || errorProducto;
                }
                // si tiene items y no dio error
                if (!errorProducto && !transaccion.Items_Auditorias__r.isEmpty()) auditorias.add(transaccion.Id);       
            }
        }
        
        //Procesamos las Transacciones DUPS (si hubiera)
        if(dups.size() > 0){
            //llamamos al metodo createDups que procesara las transacciones DUP
            errors.addAll(UtilsComprobanteVenta.createComprobantesVentaFromDups(dups,batchDate));
        }
        
        //Procesamos las Transacciones Auditorias (si hubiera)
        if(auditorias.size() > 0){
            //llamamos al metodo createAuds que procesara las transacciones Auditorias
            errors.addAll(UtilsComprobanteVenta.createComprobantesVentaFromAuditorias(auditorias,batchDate));
        }
    }

    private Boolean checkError(Transaccion__c transaccion, Product2 prod) {
        if(prod.ERPvs_Producto__c == null){
            //FL 2019-02-01 Genero error para que salga por mail
            errors.add('Transaccion ' + transaccion.Name + ': El producto ' + prod.Name + ' no tiene producto asociado en el ERP.\n');
            return true;
        }

        return false;
    }
    
    global void finish(Database.BatchableContext BC) {
        BatchErrorHelper.sendEmail(BC.getJobId(), errors, 'Errores en BatchApexGeneracionComprobantesVentas');
    }
    
}