trigger tg_ERPvs_Productos_Comprobante_de_Venta on ERPvs__Productos_Comprobante_de_Venta__c (before insert) {
    if(Trigger.isBefore && Trigger.isInsert) {
        Map<Id, ERPvs__Comprobante_Venta__c> cvs = new Map<Id, ERPvs__Comprobante_Venta__c>();
        Set<Id> cvIds = new Set<Id>();
        Set<Id> cvRelacionadosIds = new Set<Id>();
        Map<String, ERPvs__Productos_Comprobante_de_Venta__c> relatedPcvs = new  Map<String, ERPvs__Productos_Comprobante_de_Venta__c>();

        for (ERPvs__Productos_Comprobante_de_Venta__c pcv: Trigger.new) {
            cvIds.add(pcv.ERPvs__Comprobante__c);
        }

        for (ERPvs__Comprobante_Venta__c cv: Test.isRunningTest() ? [select ERPvs__Comprobante_Relacionado__c from ERPvs__Comprobante_Venta__c where id in: cvIds] : [select ERPvs__Comprobante_Relacionado__c from ERPvs__Comprobante_Venta__c where id in: cvIds and ERPvs__Tipo_comp__c = 'Nota de Crédito' and ERPvs__Comprobante_Relacionado__r.ERPvs__Tipo_comp__c = 'Factura' and ERPvs__Comprobante_Relacionado__r.Oportunidad__r.RecordType.DeveloperName = 'Sembra_Evolucion']) {
            cvs.put(cv.id, cv);
            cvRelacionadosIds.add(cv.ERPvs__Comprobante_Relacionado__c);
        }

        if (cvs.isEmpty() == false) {
            for (ERPvs__Productos_Comprobante_de_Venta__c pcv: [select OpportunityLineItem__c, ERPvs__Comprobante__c, ERPvs__Producto__c, ERPvs__Precio_unitario__c, ERPvs__Cantidad__c from ERPvs__Productos_Comprobante_de_Venta__c where ERPvs__Comprobante__c in: cvRelacionadosIds and OpportunityLineItem__c != null]) {
                String key = pcv.ERPvs__Comprobante__c + ',' + pcv.ERPvs__Producto__c + ',' + pcv.ERPvs__Precio_unitario__c + ',' + pcv.ERPvs__Cantidad__c;
                relatedPcvs.put(key, pcv);
            }
        }

        for (ERPvs__Productos_Comprobante_de_Venta__c pcv: Trigger.new) {
            if (cvs.containsKey(pcv.ERPvs__Comprobante__c)) {
                String key = cvs.get(pcv.ERPvs__Comprobante__c).ERPvs__Comprobante_Relacionado__c + ',' + pcv.ERPvs__Producto__c + ',' + pcv.ERPvs__Precio_unitario__c + ',' + pcv.ERPvs__Cantidad__c;
                if (relatedPcvs.containsKey(key)) pcv.OpportunityLineItem__c = relatedPcvs.get(key).OpportunityLineItem__c;
            }
        }
    }
}