/* Nombre: UtilsContentDocumentLink
* Autor: Rodrigo Lopez
* Proyecto: ArPOV - REQ 5 - Subida de facturas desde el site.
* Descripción: Clase Utils de ContentDocumentLink 
* --------------------------------------------------------------------------
* Versión      Fecha           Autor                      Desripción<p />
* --------------------------------------------------------------------------
* 1.0.0        28/07/2025      Rodrigo Lopez         Creación. Se crea con without sharing para acceder a objetos desde el site.
* 1.0.1        12/08/2025      Rodrigo Lopez         Metodo removeFileFromVenta para ContentDocument
*--------------------------------------------------------------------------
*/
public without sharing class UtilsContentDocumentLink {
    public static Boolean isRunning = false;

    public static void changeEntity(Map<Id, Id> ventaToContentDocumentMap, Set<Id> contentDocumentIds, Set<Id> cdlIds ){
    
        try {
            isRunning = true;
            Map<Id, Id> ventaToOppsMap = getRelatedOpportunities(ventaToContentDocumentMap.keySet());
                
            if (ventaToOppsMap.isEmpty()) {
                System.debug('No se encontraron oportunidades relacionadas a las ventas');
                return;
            }

            List<String> oppsToContentDocuments = getOppsContentDocumentLinks( ventaToOppsMap.values());
            Map<Id, Id> ventaToOpportunityMap = removeOpportunities(ventaToOppsMap, oppsToContentDocuments);
            List<ContentDocumentLink> newContentDocumentLinks = createContentDocumentLinks(ventaToContentDocumentMap,ventaToOpportunityMap);
        
            if (!newContentDocumentLinks.isEmpty()) {
                try {
                    insert newContentDocumentLinks;
                    updateVentas(ventaToContentDocumentMap.keySet());
                    deleteCdls(cdlIds);
                    System.debug('Se crearon ' + newContentDocumentLinks.size() + ' nuevos ContentDocumentLinks y se eliminaron' +cdlIds.size());
                    } catch (DmlException e) {
                        System.debug('Error al insertar y eliminar ContentDocumentLinks: ' + e.getMessage());
                    }
                }
                
            } catch (Exception e) {
                System.debug('Error en UtilsContentDocumentLink: ' + e.getMessage());
            } finally {
                isRunning = false;
            }
        
            Map<Id, Id> ventaToOpportunityMap = getRelatedOpportunities(ventaToContentDocumentMap.keySet());
            
            if (ventaToOpportunityMap.isEmpty()) {
                System.debug('No se encontraron oportunidades relacionadas a las ventas');
                return;
            }
        }    
    
    private static List<String> getOppsContentDocumentLinks(List<Id> opportunityIds) {
        
        List<String> oppsIds = new List<String>();
        
        try {
            List<ContentDocumentLink> existingLinks = [SELECT LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :opportunityIds LIMIT 10000 ];
            
            for (ContentDocumentLink link : existingLinks) {
                String id = String.valueOf(link.LinkedEntityId);
                oppsIds.add(Id);
            }
            
        } catch (QueryException e) {
            System.debug('Error al consultar ContentDocumentLinks existentes: ' + e.getMessage());
        }
        return oppsIds;
    }
    
    private static List<ContentDocumentLink> createContentDocumentLinks(Map<Id, Id> ventaToContentDocumentMap,Map<Id, Id> ventaToOpportunityMap) {
        
        List<ContentDocumentLink> newContentDocumentLinks = new List<ContentDocumentLink>();
        
        for (Id ventaId : ventaToContentDocumentMap.keySet()) {
            Id contentDocumentId = ventaToContentDocumentMap.get(ventaId);
            Id opportunityId = ventaToOpportunityMap.get(ventaId);
            
            if (opportunityId == null) {
                System.debug('No se encontró oportunidad para la venta: ' + ventaId);
                continue;
            }
           
            ContentDocumentLink newLink = new ContentDocumentLink(
                LinkedEntityId = opportunityId,
                ContentDocumentId = contentDocumentId,
                ShareType = 'V', 
                Visibility = 'AllUsers'
            );
            
            newContentDocumentLinks.add(newLink);
        }
        
        return newContentDocumentLinks;
    }
   
    private static Map<Id, Id> getRelatedOpportunities(Set<Id> ventaIds) {
        Map<Id, Id> ventaToOpportunityMap = new Map<Id, Id>();
        
        try {
            List<Venta_HT__c> ventas = [SELECT Id, Compra_HT__r.Oportunidad__c FROM Venta_HT__c WHERE Id IN :ventaIds AND Compra_HT__r.Oportunidad__c  != null LIMIT 10000 ];
            
            for (Venta_HT__c venta : ventas) {
                ventaToOpportunityMap.put(venta.Id, venta.Compra_HT__r.Oportunidad__c);
            }
            
        } catch (QueryException e) {
            System.debug('Error al ejecutar la búsqueda: ' + e.getMessage());
        }
        
        return ventaToOpportunityMap;
    }
   
    public static Map<Id, Id> removeOpportunities(Map<Id, Id> ventaOpps, List<Id> opportunityIdsToRemove) {
        
        if (ventaOpps == null || ventaOpps.isEmpty() || opportunityIdsToRemove == null ||opportunityIdsToRemove.isEmpty()) {
            return ventaOpps;
        }
        
        List<Id> ventaKeysToRemove = new List<Id>();
        
        for (Id ventaId : ventaOpps.keySet()) {
            Id opportunityId = ventaOpps.get(ventaId);
            
            if (opportunityIdsToRemove.contains(opportunityId)) {
                ventaKeysToRemove.add(ventaId);
            }
        }
        
        for (Id vId : ventaKeysToRemove) {
            ventaOpps.remove(vId);
        }
        return ventaOpps;
    }

    public static void updateVentas(Set<Id> ventaIds) {
        List<Venta_HT__c> ventasToUpdate = new List<Venta_HT__c>();
        try {
            List<Venta_HT__c> ventas = [SELECT Id, Compra_HT__r.Oportunidad__c FROM Venta_HT__c WHERE Id IN :ventaIds AND Compra_HT__r.Oportunidad__c  != null LIMIT 10000 ];
            
            for (Venta_HT__c venta : ventas) {
                venta.TieneAdjunto__c = true;
                ventasToUpdate.add(venta);
            }
            
        } catch (QueryException e) {
            System.debug('Error al ejecutar la búsqueda: ' + e.getMessage());
        }
        
        update ventasToUpdate;
    }
    public static void removeFileFromVenta(Set<Id> oppIds) {
        List<Venta_HT__c> ventasToUpdate = new List<Venta_HT__c>();
        try {
            List<Venta_HT__c> ventas = [SELECT Id, TieneAdjunto__c FROM Venta_HT__c WHERE Compra_HT__r.Oportunidad__c IN :oppIds LIMIT 10000 ];
            
            for (Venta_HT__c venta : ventas) {
                venta.TieneAdjunto__c = false;
                ventasToUpdate.add(venta);
            }
            
        } catch (QueryException e) {
            System.debug('Error al ejecutar la búsqueda: ' + e.getMessage());
        }
        
        update ventasToUpdate;
    }

    public static List<Id> getRelatedVentas(Set<Id> cdlIds) {
        List<Id> ventasFromOpps= new List<Id>();
        List<Id> oppsIds= new List<Id>();
        
        try {
            List<ContentDocumentLink> cdlList = [SELECT LinkedEntityId FROM ContentDocumentLink WHERE Id IN :cdlIds LIMIT 10000];

            for (ContentDocumentLink cdl : cdlList) {
                oppsIds.add(cdl.LinkedEntityId);
            }

            List<Opportunity> opps = [SELECT Id, Compra_HT__r.Venta_HT__c FROM Opportunity WHERE Id IN :oppsIds AND Compra_HT__r.Venta_HT__c  != null LIMIT 10000 ];
            
            for (Opportunity op : opps) {
                ventasFromOpps.add(op.Compra_HT__r.Venta_HT__c);
            }
            
        } catch (QueryException e) {
            System.debug('Error al ejecutar la búsqueda: ' + e.getMessage());
        }
        
        return ventasFromOpps;
    }
        
    @future
    public static void deleteCdls(Set<Id> recordIds) {
        List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
        
        for (Id recordId : recordIds) {
            cdls.add(new ContentDocumentLink(Id = recordId));
        }
        
        try {
            delete cdls; 
        } catch (DmlException e) {
            System.debug('Error al eliminar: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getAttachments(String ventaId) {

        try {
            Id validId = Id.valueOf(ventaId);
            List<Venta_HT__c> ventas = [ SELECT Compra_HT__r.Oportunidad__c FROM Venta_HT__c WHERE Id = :ventaId  AND Compra_HT__r.Oportunidad__c != null LIMIT 1];
            if (ventas.isEmpty()) {
                return new List<ContentDocumentLink>();
            }
            
            Id oppId = ventas[0].Compra_HT__r.Oportunidad__c;
            
            List<ContentDocumentLink> documentLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, 
                       ContentDocument.FileExtension, ContentDocument.ContentSize,
                       ContentDocument.CreatedDate
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :oppId 
                AND ContentDocument.FileExtension = 'pdf'
                ORDER BY ContentDocument.CreatedDate DESC
            ];
                       
            return documentLinks;
        } catch (StringException e) {
        throw new AuraHandledException('ID de venta inválido: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener adjuntos: ' + e.getMessage());
        }
    }
}