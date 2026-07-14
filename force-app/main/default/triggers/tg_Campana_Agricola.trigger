trigger tg_Campana_Agricola on Campana_Agricola__c (after insert, after update) {
	
    if(Trigger.isAfter){
        
        //Lista que contendra las campañas agricolas activas
        List<Campana_Agricola__c> caActivas = new List<Campana_Agricola__c>();
        
        if(Trigger.isInsert){
        	
            for(Campana_Agricola__c ca : Trigger.new){
                
                if(ca.Estado__c == 'Activa' && ca.Nombre_de_Campana_Anterior__c != null){
                    
                    caActivas.add(ca);
                    
                }
                
            }
            
        }
        
        if(Trigger.isUpdate){
            
            for(Campana_Agricola__c ca : Trigger.new){
                
                if(ca.Estado__c == 'Activa' && ca.Nombre_de_Campana_Anterior__c != null && Trigger.oldMap.get(ca.Id).Estado__c != 'Activa'){
                    
                    caActivas.add(ca);
                    
                }
                
            }
        }
        
        //Si hay campañas activas cerramos sus campañas anteriores
        if(caActivas.size() > 0){
            
            UtilsCampanaAgricola.setearCampanaAnteriorACompleta(caActivas);
            
        }
        
    }
    
}