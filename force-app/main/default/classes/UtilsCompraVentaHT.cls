public inherited sharing class UtilsCompraVentaHT {

    public static List<Map<String, Object>> getCultivos(){
        List<Map<String, Object>> options = new List<Map<String, Object>>();

        for(Cultivo__c cultivo : [SELECT Id, Name FROM Cultivo__c WHERE Sembra_Evolucion__c = true]){
            options.add(new Map<String, Object>{'label' => cultivo.Name, 'value' => cultivo.Id});
        }

        return options;
    }

    public static Set<Id> getVariedadesSreProductor(String productorId){
        Set<Id> variedadesSreIds = new Set<Id>();
        for(Variedad_SRE_por_Productor__c variedadSreProductor : [SELECT Variedad__c FROM Variedad_SRE_por_Productor__c WHERE Cuenta__c = :productorId]){
            variedadesSreIds.add(variedadSreProductor.Variedad__c);
        }
        return variedadesSreIds;
    }
}