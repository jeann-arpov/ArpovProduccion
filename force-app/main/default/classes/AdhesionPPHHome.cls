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
        for(Plan_de_Siembra__c plan : [SELECT Id, Name, Parametro_PPH__c, Estado__c, Version__c, Terminos_y_Condiciones__c FROM Plan_de_Siembra__c WHERE Parametro_PPH__c IN :parametrosIds AND Estado__c NOT IN ('Cancelado') AND Productor__c = :CrearCompraController.getAccount().Id]){
            mapParamPlanSiembra.put(plan.Parametro_PPH__c, plan);
        }

        Map<Id, List<String>> planEstablecimientoNames = new Map<Id, List<String>>();
        Set<Id> planIds = new Set<Id>();
        for (Plan_de_Siembra__c plan : mapParamPlanSiembra.values()) {
            planIds.add(plan.Id);
        }
        for (Establecimiento_PPH__c estPph : [
            SELECT Plan_de_Siembra__c, Establecimiento__r.Name
            FROM Establecimiento_PPH__c
            WHERE Plan_de_Siembra__c IN :planIds
            ORDER BY CreatedDate ASC
        ]) {
            if (!planEstablecimientoNames.containsKey(estPph.Plan_de_Siembra__c)) {
                planEstablecimientoNames.put(estPph.Plan_de_Siembra__c, new List<String>());
            }
            if (estPph.Establecimiento__r?.Name != null) {
                planEstablecimientoNames.get(estPph.Plan_de_Siembra__c).add(estPph.Establecimiento__r.Name);
            }
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
                    parametros.add(new Parametro(
                        param,
                        mapParamPlanSiembra.get(param.Id),
                        mapFileTitleToPublicUrl.get(documentName),
                        mapTitleToContentDocumentId.get(documentName),
                        planEstablecimientoNames
                    ));
                }

                cultivosParams.add(new CultivoParametro(cultivosSE.get(cultivoId), parametros));
            }
        }

        return cultivosParams;
    }

    @AuraEnabled(cacheable=true)
    public static AccountContext getContext() {
        Account acc = CrearCompraController.getAccount();
        return new AccountContext(acc.Id, acc.N_CUIT__c, acc.Name);
    }

    public class AccountContext {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String cuit;
        @AuraEnabled public String name;

        public AccountContext(Id accountId, String cuit, String name) {
            this.accountId = accountId;
            this.cuit = cuit;
            this.name = name;
        }
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
        @AuraEnabled public String establecimientoLabel;
        @AuraEnabled public String mobileExtraLabel;
        @AuraEnabled public String mobileExtraValue;

        public Parametro(
            Parametro_PPH__c param,
            Plan_de_Siembra__c plan,
            String tycUrl,
            String contentDocumentId,
            Map<Id, List<String>> planEstablecimientoNames
        ){
            parametro = param;
            planSiembra = plan;
            this.tycUrl = tycUrl;
            this.contentDocumentId = contentDocumentId;
            establecimientoLabel = '—';
            mobileExtraLabel = '';
            mobileExtraValue = '';

            if (plan == null) {
                return;
            }

            List<String> names = planEstablecimientoNames.get(plan.Id);
            if (names != null && !names.isEmpty()) {
                establecimientoLabel = names.size() == 1
                    ? names[0]
                    : names[0] + ' +' + String.valueOf(names.size() - 1);
            }

            if (plan.Estado__c == 'En Preparación' || plan.Estado__c == 'Rectificado') {
                mobileExtraLabel = 'Paso';
                if (plan.Estado__c == 'Rectificado') {
                    mobileExtraValue = 'En rectificación';
                } else if (plan.Terminos_y_Condiciones__c == true) {
                    mobileExtraValue = '3 de 3';
                } else {
                    mobileExtraValue = '1 de 3';
                }
            } else if (plan.Estado__c == 'Adherido' || plan.Estado__c == 'Vencido') {
                mobileExtraLabel = 'Certificado';
                mobileExtraValue = plan.Name;
            }
        }
    }
}