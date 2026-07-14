/**
* @author Facundo Luna
* @date 19/07/2016
* @description Clase Batcheable que se encarga de generar Movimientos desde un CV
*/
global class BatchApexGeneracionMovimientos implements Database.Batchable<sObject>, Database.Stateful {
    
    /**
    * @description Variable estatica indica el tamaño del lote
    */  
    public static Integer BATCH_SIZE = 200;
    public static String FACTURA = 'Factura';
    public static String NOTA_DEBITO = 'Nota de Débito';
    public static String NOTA_CREDITO = 'Nota de Crédito';

    public Date batchDate {get; set;}

    public Set<Id> idsCVs = new Set<Id>();

    private Date fechaDesde;
    private Date fechaHasta;

    global BatchApexGeneracionMovimientos() {
        
    }

    global BatchApexGeneracionMovimientos(Set<Id> ids) {
        idsCVs = ids;
    }   

    global BatchApexGeneracionMovimientos(Date fechaDesde, Date fechaHasta) {
        this.fechaDesde = fechaDesde;
        this.fechaHasta = fechaHasta;
    }   
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        
        Set<String> movimientosExistentes = new Set<String>();
        if(fechaDesde == null){
            for(Movimientos__c m : [SELECT Comprobante_Venta__c FROM Movimientos__c]){
                if(m.Comprobante_Venta__c != null){
                    movimientosExistentes.add(m.Comprobante_Venta__c);
                }
            }
        } else {
            for(Movimientos__c m : [SELECT Comprobante_Venta__c FROM Movimientos__c WHERE Fecha__c >= :fechaDesde AND Fecha__c <= :fechaHasta]){
                if(m.Comprobante_Venta__c != null){
                    movimientosExistentes.add(m.Comprobante_Venta__c);
                }
            }
        }
        
        String query = 'SELECT Id, Nro_Comprobante__c, ERPvs__Cliente__c, ERPvs__Fecha__c, ERPvs__Total__c, ERPvs__Moneda__r.ERPvs__Simbolo__c, Oportunidad__c, ERPvs__Tc__c, ERPvs__Tipo_comp__c';
        query += ' FROM ERPvs__Comprobante_Venta__c';
        query += ' WHERE ERPvs__Fecha__c >= 2016-01-01 AND ERPvs__Contabilizar__c = true AND ERPvs__A_cuenta_y_orden_de__c != null AND Oportunidad__c != null';
        
        if(!movimientosExistentes.isEmpty()){

            query += ' AND Id NOT IN :movimientosExistentes';

        }
        
        if(idsCVs != null && !idsCVs.isEmpty()){

            query += ' AND Id IN :idsCVs';

        }

        if(fechaDesde != null){
            query += ' AND ERPvs__Fecha__c >= :fechaDesde';
        }

        if(fechaHasta != null){
            query += ' AND ERPvs__Fecha__c <= :fechaHasta';
        }

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<ERPvs__Comprobante_Venta__c> scope) {
    
        List<Movimientos__c> movimientos = new List<Movimientos__c>();
        Movimientos__c m;
        
        for(ERPvs__Comprobante_Venta__c cv : scope){
        
            m = new Movimientos__c();
            m.Comprobante__c = cv.Nro_Comprobante__c;
            m.Cuenta__c = cv.ERPvs__Cliente__c;
            m.Fecha__c = cv.ERPvs__Fecha__c;
            m.Importe__c = cv.ERPvs__Total__c;
            m.Moneda__c = cv.ERPvs__Moneda__r.ERPvs__Simbolo__c;
            m.Oportunidad__c = cv.Oportunidad__c;
            m.Tipo_de_Cambio__c = cv.ERPvs__Tc__c;
            m.Comprobante_Venta__c = cv.Id;
            if(cv.ERPvs__Tipo_comp__c.equals(FACTURA)){
                m.Tipo_de_Movimiento__c = 'FC';
            } else if(cv.ERPvs__Tipo_comp__c.equals(NOTA_DEBITO)){
                m.Tipo_de_Movimiento__c = 'ND';
            } else {
                m.Tipo_de_Movimiento__c = 'NC';
            }
            
            movimientos.add(m);
            
        }
        
        insert movimientos;
        
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }
    
}