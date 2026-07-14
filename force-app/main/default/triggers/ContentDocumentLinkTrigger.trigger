trigger ContentDocumentLinkTrigger on ContentDocumentLink (before insert,before delete, after insert, after update, after delete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {

        Set<id> AllDocids = new set<id>();
        Set<id> EligibleDocIds = new set<id>();
        Map<Id, Id> oppToContentDocumentId = new Map<Id, Id>();

        for (ContentDocumentLink cdl : Trigger.new) {
            
            if(cdl.LinkedEntityId.getSObjectType() == Schema.Opportunity.SObjectType){
                oppToContentDocumentId.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
                AllDocids.add(cdl.ContentDocumentId);
            }
        }

        if (oppToContentDocumentId.size() > 0) {
            
            for(ContentDocument CD: [Select id from ContentDocument where id in: AllDocids and Title like 'Condiciones_Comerciales_%' and FileType = 'pdf']){
            EligibleDocIds.add(CD.Id);
            }

            for(ContentDocument CD: [Select id from ContentDocument where id in: AllDocids and Title like 'TyC%' and FileType = 'pdf']){
                EligibleDocIds.add(CD.Id);
            }

            Map<Id, String> fileNames = new Map<Id, String>();
            for(Opportunity opp : [select Tipo_de_Comprobante__c, N_de_Comprobante__c from Opportunity where id in :oppToContentDocumentId.keySet()]){
                fileNames.put(opp.Id, opp.Tipo_de_Comprobante__c + opp.N_de_Comprobante__c);  
            }

            for(ContentDocument cd : [select Id from ContentDocument where Id IN :oppToContentDocumentId.values() and Title IN :fileNames.values()]){
                EligibleDocIds.add(cd.Id);
            }
            
            for (ContentDocumentLink cdl : Trigger.new) {
                if(EligibleDocIds.contains(cdl.ContentDocumentId)) {
                    cdl.Visibility = 'AllUsers';
                }       
            }
        }
    }
    if (Trigger.isAfter && Trigger.isInsert)  {
       
        

        Map<Id, Id> ventaHToContentDocumentId = new Map<Id, Id>();
        Set<id> ventaDocIds = new set<id>();
        Set<id> cdlIds = new set<id>();
        Set<Id> cdlIdFromOpps = new Set<Id>();
        Set<Id> ventasToUpdateSet = new Set<Id>();
        
        for (ContentDocumentLink cdl : Trigger.new) {
            
            if(cdl.LinkedEntityId.getSObjectType() == Schema.Opportunity.SObjectType){
                cdlIdFromOpps.add(cdl.Id);
            }
            if(cdl.LinkedEntityId.getSObjectType() == Schema.Venta_HT__c.SObjectType){
                ventaHToContentDocumentId.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
                ventaDocIds.add(cdl.ContentDocumentId);
                cdlIds.add(cdl.Id);
            }
        }

        if (!cdlIdFromOpps.isEmpty()) {
            ventasToUpdateSet.addAll(UtilsContentDocumentLink.getRelatedVentas(cdlIdFromOpps));
            UtilsContentDocumentLink.updateVentas(ventasToUpdateSet);
        }

        if (!ventaHToContentDocumentId.isEmpty()) {
            UtilsContentDocumentLink.changeEntity(ventaHToContentDocumentId, ventaDocIds, cdlIds);
        }
    }
}