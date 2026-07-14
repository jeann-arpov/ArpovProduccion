trigger tg_MovimientoFondo on ERPvs__Movimiento_Fondo__c (before delete) {

    if(Trigger.isBefore){
        
        if(Trigger.isDelete){
        
            Set<String> ids = new Set<String>();
            
            for(ERPvs__Movimiento_Fondo__c mf : Trigger.old){
                ids.add(mf.Comprobante_de_Pago__c);
            }

            List<Comprobante_de_Pago__c> cps = [SELECT Id, Estado_ERP__c FROM Comprobante_de_Pago__c WHERE Id IN :ids];
            for(Comprobante_de_Pago__c cp : cps){
                cp.Estado_ERP__c = 'SIN PROCESAR';
            }
            
            update cps;

        }
    
    }
}