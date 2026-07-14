public without sharing class AdhesionPPHHome {
    
    @AuraEnabled
    public static List<CultivoParametro> getLoadData(){
        
        Map<Id, Cultivo__c> cultivosSE = new Map<Id, Cultivo__c>([SELECT Id, Name FROM Cultivo__c WHERE Sembra_Evolucion__c = true]);

        Map<Id, List<Parametro_PPH__c>> mapCultivoParametros = new Map<Id, List<Parametro_PPH__c>>();
        Set<Id> parametrosIds = new Set<Id>();
        for(Parametro_PPH__c parametro : [
                SELECT Id,
                    Name,
                    Cultivo__c,
                    Fecha_Inicio_Adhesion_PPH__c, 
                    Fecha_Fin_Adhesion_PPH__c,
                    Fecha_Inicio_Rectificacion_1__c, 
                    Fecha_Inicio_Rectificacion_2__c, 
                    Fecha_Fin_Rectificacion_1__c,
                    Fecha_Fin_Rectificacion_2__c
                FROM Parametro_PPH__c
                WHERE Cultivo__c IN :cultivosSE.keySet()
                ORDER BY CreatedDate desc]){

            if(!mapCultivoParametros.containsKey(parametro.Cultivo__c)){
                mapCultivoParametros.put(parametro.Cultivo__c, new List<Parametro_PPH__c>());
            }
            if(mapCultivoParametros.get(parametro.Cultivo__c).size() < 2){
                mapCultivoParametros.get(parametro.Cultivo__c).add(parametro);
                parametrosIds.add(parametro.Id);
            }
        }

        Map<Id, Plan_de_Siembra__c> mapParamPlanSiembra = new Map<Id, Plan_de_Siembra__c>();
        for(Plan_de_Siembra__c plan : [SELECT Id, Name, Parametro_PPH__c, Estado__c, Version__c FROM Plan_de_Siembra__c WHERE Parametro_PPH__c IN :parametrosIds AND Estado__c NOT IN ('Cancelado') AND Productor__c = :CrearCompraController.getAccount().Id]){
            mapParamPlanSiembra.put(plan.Parametro_PPH__c, plan);
        }

        Map<String, Id> mapTitleToContentDocumentId = new Map<String, Id>();
        for(ContentDocumentLink link : [SELECT LinkedEntityId, ContentDocumentId, ContentDocument.Title FROM ContentDocumentLink WHERE LinkedEntityId IN :parametrosIds AND ContentDocument.Title LIKE 'TyC%']){
            mapTitleToContentDocumentId.put(link.ContentDocument.Title, link.ContentDocumentId);
        }

        System.debug('mapTitleToContentDocumentId.values(): ' + mapTitleToContentDocumentId.values());

        Map<Id, ContentVersion> mapContentVersions = new Map<Id, ContentVersion>([select id from contentversion where contentdocumentid in :mapTitleToContentDocumentId.values()]);

        Map<String, String> mapFileTitleToPublicUrl = new Map<String, String>();
        for(ContentDistribution cd : [SELECT Id, DistributionPublicUrl, ContentVersion.Title FROM ContentDistribution WHERE ContentVersionId IN :mapContentVersions.keySet()]){
            mapFileTitleToPublicUrl.put(cd.ContentVersion.Title, cd.DistributionPublicUrl);
        }

        System.debug('mapFileTitleToPublicUrl: ' + mapFileTitleToPublicUrl);
        
        List<CultivoParametro> cultivosParams = new List<CultivoParametro>();
        Boolean isGrandesCuentas = !Test.isRunningTest() ? CrearCompraController.getAccount().Grandes_Cuentas__c : false;
        
        for(Id cultivoId : cultivosSE.keySet()){
            if(mapCultivoParametros.containsKey(cultivoId)) {
                List<Parametro_PPH__c> parametrosSf = mapCultivoParametros.get(cultivoId);  
                List<Parametro> parametros = new List<Parametro>();
                for(Parametro_PPH__c param : parametrosSf){
                    String documentName = 'TyC' + (isGrandesCuentas ? ' - GC - ' : ' - ') + param.Name.remove('/');
                    parametros.add(new Parametro(param, mapParamPlanSiembra.get(param.Id), mapFileTitleToPublicUrl.get(documentName), mapTitleToContentDocumentId.get(documentName)));
                }

                cultivosParams.add(new CultivoParametro(cultivosSE.get(cultivoId), parametros));
            }
        }

        return cultivosParams;
    }

    public class CultivoParametro {
        @AuraEnabled public Cultivo__c cultivo;
        @AuraEnabled public List<Parametro> parametros;

        public CultivoParametro(Cultivo__c cultivo, List<Parametro> params){
            this.cultivo = cultivo;
            parametros = params;
        }
    }

    public class Parametro {
        @AuraEnabled public Parametro_PPH__c parametro;
        @AuraEnabled public Plan_de_Siembra__c planSiembra;
        @AuraEnabled public String tycUrl;
        @AuraEnabled public String contentDocumentId;

        public Parametro(Parametro_PPH__c param, Plan_de_Siembra__c plan, String tycUrl, String contentDocumentId){
            parametro = param;
            planSiembra = plan;
            this.tycUrl = tycUrl;
            this.contentDocumentId = contentDocumentId;
        }
    }
}