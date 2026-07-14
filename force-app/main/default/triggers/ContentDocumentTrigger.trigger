/* Nombre: ContentDocumentTrigger
* Autor: Rodrigo Lopez
* Proyecto: ArPOV 
* Descripción: trigger de ContentDocument - REQ 5 - Subida de facturas desde el site.
* --------------------------------------------------------------------------
* Versión      Fecha           Autor                      Desripción<p />
* --------------------------------------------------------------------------
* 1.0.0        12/08/2025      Rodrigo Lopez            Creación. 
*--------------------------------------------------------------------------
*/
trigger ContentDocumentTrigger on ContentDocument (before delete) {
   
    Set<Id> contentDocIds = new Set<Id>();
    for (ContentDocument cd : Trigger.old) {
        contentDocIds.add(cd.Id);
    }
    
    List<ContentDocumentLink> links = [SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE ContentDocumentId IN :contentDocIds];
    
    System.debug('ContentDocumentLinks que serán eliminados: ' + links.size());
    
    Set<Id> oppIds = new Set<Id>();
    
    for (ContentDocumentLink cdl : links) {
                
        if(cdl.LinkedEntityId.getSObjectType() == Schema.Opportunity.SObjectType){
            oppIds.add(cdl.LinkedEntityId);
            System.debug('Oportunidad agregada: ' + cdl.LinkedEntityId);
        }
    }
    
    System.debug('Total oportunidades: ' + oppIds.size());
    
    if (!oppIds.isEmpty()) {
        UtilsContentDocumentLink.removeFileFromVenta(oppIds);
    }
}