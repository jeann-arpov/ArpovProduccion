/**
* @author Facundo Luna
* @date 12/06/2018
* @description Clase con metodos utilitarios para el objeto Aplicacion__c
*/
public with sharing class UtilsAplicacion {

    public static void clearLPs(Set<String> lpIds){
        
        for(List<Aplicacion__c> aplicaciones : [SELECT Id, Liquido_Producto__c FROM Aplicacion__c WHERE Liquido_Producto__c IN :lpIds]){
            for(Aplicacion__c ap : aplicaciones ){
                ap.Liquido_Producto__c  = null;
            }
            update aplicaciones;
        }
    }

    public static void updateLPs(Map<String, ERPvs__Comprobante_Venta__c> mapComprobantes){
        
        System.debug('>> >> updateLPs');
        System.debug('>> >> mapComprobantes:' + mapComprobantes);

        for(List<Aplicacion__c> aplicaciones : [SELECT Id, Comprobante__c, Liquido_Producto__c FROM Aplicacion__c WHERE Comprobante__c IN :mapComprobantes.keySet() AND Comprobante_de_Pago__r.Estado_ERP__c = 'PROCESADO']){
            System.debug('>> >> aplicaciones:' + aplicaciones);
            for(Aplicacion__c ap : aplicaciones ){
                System.debug('>> >> ap:' + ap);
            	if(ap.Liquido_Producto__c != null){
                	ap.Liquido_Producto__c = null;
            	} else {
            		if(mapComprobantes.get(ap.Comprobante__c) != null)
            			ap.Liquido_Producto__c = mapComprobantes.get(ap.Comprobante__c).ERPvs__Liquido_producto__c;
            	}
            }
            update aplicaciones;
        }
    }
}