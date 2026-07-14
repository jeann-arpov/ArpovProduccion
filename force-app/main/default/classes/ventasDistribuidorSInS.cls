public with sharing class ventasDistribuidorSInS {


    @AuraEnabled(cacheable=true)
    public static List<VentasDistribuidorController.RowWrapper> getDatos(String accountId,Integer fila, Integer columna,String[] whereList){    
        return get(accountId,fila,columna,whereList);
    }

    @AuraEnabled(cacheable=true)
    public static List<VentasDistribuidorController.RowWrapper> getDatos(String accountId,Integer fila, Integer columna,String[] whereList, Boolean sembraEvolucion){
        return get(accountId, fila, columna, whereList, sembraEvolucion);
    }

    @RemoteAction
    @ReadOnly
    public static List<VentasDistribuidorController.RowWrapper> get(String accountId,Integer fila, Integer columna,String[] whereList){
        return ventasDistribuidorConS.get(accountId,fila,columna,whereList);
    }

    @RemoteAction
    @ReadOnly
    public static List<VentasDistribuidorController.RowWrapper> get(String accountId,Integer fila, Integer columna,String[] whereList, Boolean sembraEvolucion){
        return ventasDistribuidorConS.get(accountId,fila,columna,whereList, sembraEvolucion);
    }

    @AuraEnabled(cacheable=true)
    public static Id getAccountIdCommunity(){
        return   (!Test.isRunningTest()) ? [SELECT Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId()].Contact.AccountId : [SELECT Id FROM Account LIMIT 1].Id;
    }
}