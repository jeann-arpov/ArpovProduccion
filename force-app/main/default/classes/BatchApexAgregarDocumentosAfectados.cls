/**
* @author Facundo Luna
* @date 22/07/2016
* @description Clase Batcheable que se encarga de agregar documentos afectados a un CV
*/
global class BatchApexAgregarDocumentosAfectados implements Database.Batchable<sObject>, Database.Stateful {
    
    /**
    * @description Variable estatica indica el tamaño del lote
    */  
    public static Integer BATCH_SIZE = 200;
    public static String DIF_CAMBIO = 'Diferencia de cambio';

    public Date batchDate {get; set;}

    public Set<Id> idsCVs = new Set<Id>();

    global BatchApexAgregarDocumentosAfectados() {
        
    }

    global BatchApexAgregarDocumentosAfectados(Set<Id> ids) {
        idsCVs = ids;
    }    
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        
        String query = 'SELECT Id, ERPvs__Total__c, ERPvs__Comprobante_Relacionado__c, ERPvs__Signo__c';
        query += ' FROM ERPvs__Comprobante_Venta__c';
        query += ' WHERE ERPvs__Contabilizar__c = true AND Tipo_Movimiento__c = :DIF_CAMBIO';
        
        if(idsCVs != null && !idsCVs.isEmpty()){

            query += ' AND Id IN :idsCVs';

        }

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<ERPvs__Comprobante_Venta__c> scope) {
    
        List<ERPvs__Documento_Afectado__c> dAfectadosToInsert = new List<ERPvs__Documento_Afectado__c>();
        Set<String> cvIds = new Set<String>();
        Set<String> cvRelacionadoIds = new Set<String>();
        
        for(ERPvs__Comprobante_Venta__c cv : scope){
        
            cvIds.add(cv.Id);
            cvRelacionadoIds.add(cv.ERPvs__Comprobante_Relacionado__c);
            
        }
        
        //Busco los vencimientos para posteriormente armar los docuemntos afectados
        String key;
        Map<String, ERPvs__Vencimientos__c> mapVencimientos = new Map<String, ERPvs__Vencimientos__c>();
        for(ERPvs__Vencimientos__c v : [SELECT Id, ERPvs__Cuenta__c, ERPvs__A_cuenta_y_orden_de__c, ERPvs__Serie_Documento__c, ERPvs__Sucursal_Documento__c, ERPvs__Numero_Documento__c, ERPvs__Importe_MO__c, ERPvs__Importe_MN__c, ERPvs__Signo__c, ERPvs__Comprobante_Venta__c FROM ERPvs__Vencimientos__c 
                                                                                                                                                                                        WHERE ERPvs__Comprobante_Venta__c IN :cvIds]){

            key = '' + v.ERPvs__Comprobante_Venta__c;
            mapVencimientos.put(key, v);
        }
        
        Map<String, ERPvs__Documento_Afectado__c> mapDocumentosAfectados = new Map<String, ERPvs__Documento_Afectado__c>();
        for(ERPvs__Documento_Afectado__c da : [SELECT Id, ERPvs__Movimiento_de_Fondo__c, ERPvs__Vencimientos__c, ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__c, ERPvs__Vencimientos__r.ERPvs__Importe_MO__c, ERPvs__Vencimientos__r.ERPvs__Importe_MN__c, ERPvs__Vencimientos__r.ERPvs__Signo__c,
                                                      ERPvs__Importe_MO__c, ERPvs__Importe_MN__c, ERPvs__Signo__c, ERPvs__Importe_Afectado__c, ERPvs__Movimiento_de_Fondo__r.ERPvs__Total_Cobranza__c, ERPvs__Movimiento_de_Fondo__r.Suma_Documentos_Afectados_ARS__c
                                               FROM ERPvs__Documento_Afectado__c 
                                               WHERE ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__c IN :cvRelacionadoIds AND ERPvs__Movimiento_de_Fondo__r.ERPvs__Contabilizar__c = false]){
        
            mapDocumentosAfectados.put(da.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__c, da);
        }
        
        //Recorro los CV para armar los documentos afectados
        ERPvs__Vencimientos__c v;
        ERPvs__Documento_Afectado__c daCVRelacionado;
        ERPvs__Documento_Afectado__c dAfectado;
        Decimal importeAfectado;
        for(ERPvs__Comprobante_Venta__c cv : scope){
            importeAfectado = Math.abs(cv.ERPvs__Total__c);
            v = mapVencimientos.get(cv.Id);
            daCVRelacionado = mapDocumentosAfectados.get(cv.ERPvs__Comprobante_Relacionado__c);
            if(v != null && daCVRelacionado != null){
                Decimal diferencia;
                if(cv.ERPvs__Signo__c == 1){
                    diferencia = daCVRelacionado.ERPvs__Movimiento_de_Fondo__r.ERPvs__Total_Cobranza__c - daCVRelacionado.ERPvs__Movimiento_de_Fondo__r.Suma_Documentos_Afectados_ARS__c;
                    if(importeAfectado > diferencia){
                        importeAfectado = diferencia;
                    }
                } else {
                    diferencia = daCVRelacionado.ERPvs__Movimiento_de_Fondo__r.Suma_Documentos_Afectados_ARS__c - daCVRelacionado.ERPvs__Movimiento_de_Fondo__r.ERPvs__Total_Cobranza__c;
                    if(importeAfectado > diferencia){
                        importeAfectado = diferencia;
                    }
                }
            
                dAfectado = new ERPvs__Documento_Afectado__c();
                dAfectado.ERPvs__Vencimientos__c = v.Id;
                dAfectado.ERPvs__Movimiento_de_Fondo__c = daCVRelacionado.ERPvs__Movimiento_de_Fondo__c;
                dAfectado.ERPvs__Importe_MO__c = v.ERPvs__Importe_MO__c;
                dAfectado.ERPvs__Importe_MN__c = v.ERPvs__Importe_MN__c;
                dAfectado.ERPvs__Signo__c = v.ERPvs__Signo__c;
                dAfectado.ERPvs__Importe_Afectado__c = importeAfectado;
                
                dAfectadosToInsert.add(dAfectado);
                
            }

        }
        
        if(!dAfectadosToInsert.isEmpty()){
            insert dAfectadosToInsert;
        }
        
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }
    
}