public without sharing class VariedadesSREProductor {
    
    @AuraEnabled
    public static List<Variedad__c> getVariedadesSRE(){
        Id parentObtentorId = CrearCompraController.getAccount().Id;
        return [SELECT Id, Name FROM Variedad__c WHERE Obtentor_Comercializa__c = :parentObtentorId AND Sembra_Evolucion__c = false];
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupSearchResult> searchAccounts(String searchTerm, List<String> selectedIds) {
        return CrearVentaController.accountsToLookup([SELECT Id, Name, RecordType.DeveloperName, N_CUIT__c FROM Account WHERE (Name LIKE: '%'+ searchTerm +'%' OR N_CUIT__c LIKE: '%'+ searchTerm +'%') AND RecordType.DeveloperName IN ('Productor', 'Comercio', 'Distribuidor') LIMIT 5]);
    }

    @AuraEnabled
    public static List<Variedad_SRE_por_Productor__c> getVariedadesSREProductor(String productorId){
        Id parentObtentorId = CrearCompraController.getAccount().Id;
        return [SELECT Id, Name, Variedad__c, Variedad__r.Name, Cuenta__c FROM Variedad_SRE_por_Productor__c WHERE Cuenta__c = :productorId AND Variedad__r.Obtentor_Comercializa__c = :parentObtentorId];
    }

    @AuraEnabled 
    public static void doSave(String productorId, List<Id> variedadesIds){
        Id parentObtentorId = CrearCompraController.getAccount().Id;
        
        Map<Id, Variedad__c> mapVariedades = new Map<Id, Variedad__c>([SELECT Id, Obtentor_Comercializa__c FROM Variedad__c WHERE Id IN :variedadesIds]);

        Map<Id, Variedad_SRE_por_Productor__c> mapVariedadesProductor = new Map<Id, Variedad_SRE_por_Productor__c>();
        for(Variedad_SRE_por_Productor__c varProductor : getVariedadesSREProductor(productorId)){
            mapVariedadesProductor.put(varProductor.Variedad__c, varProductor);
        }
        
        List<Variedad_SRE_por_Productor__c> toInsert = new List<Variedad_SRE_por_Productor__c>();
        for(Id variedadId : variedadesIds){
            if(!mapVariedadesProductor.containsKey(variedadId)){
                toInsert.add(new Variedad_SRE_por_Productor__c(
                    Cuenta__c = productorId,
                    Marca__c = mapVariedades.get(variedadId).Obtentor_Comercializa__c,
                    Variedad__c = variedadId
                ));
            }
        }
            
        insert toInsert;

        List<Variedad_SRE_por_Productor__c> toDelete = new List<Variedad_SRE_por_Productor__c>();
        for(Id variedadId : mapVariedadesProductor.keySet()){
            if(!variedadesIds.contains(variedadId)){
                toDelete.add(mapVariedadesProductor.get(variedadId));
            }
        }
        
        delete toDelete;
    }
}