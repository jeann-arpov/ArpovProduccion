global with sharing class VentasDistribuidorController{
  

    @AuraEnabled(cacheable=true)
    global static List<RowWrapper> getDatos(String accountId,Integer fila, Integer columna,String[] whereList){    
        return get(accountId,fila,columna,whereList);
    }

    @RemoteAction
    @ReadOnly
    global static List<RowWrapper> get(String accountId,Integer fila, Integer columna,String[] whereList){
        return ventasDistribuidorConS.get(accountId,fila,columna,whereList);

    }

    @AuraEnabled(cacheable=true)
    public static Id getAccountIdCommunity(){
        return   (!Test.isRunningTest()) ? [SELECT Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId()].Contact.AccountId : [SELECT Id FROM Account LIMIT 1].Id;
    }


    global class RowWrapper{
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String campana;
        @AuraEnabled
        public String cultivo;
        @AuraEnabled
        public String obtentor {get; set;}
        @AuraEnabled
        public String variedad {get; set;}
        @AuraEnabled
        public String tipo {get; set;}
        @AuraEnabled
        public String categoria {get; set;}
        @AuraEnabled
        public String um {get; set;}
        @AuraEnabled
        public String cuitOriginante {get; set;}
        @AuraEnabled
        public String tipoVenta {get; set;}
        @AuraEnabled
        public String cuitDestinatario {get; set;}
        @AuraEnabled
        public Double cantidad {get; set;}
        @AuraEnabled
        public String obtentorName {get; set;}
        @AuraEnabled
        public String originanteId {get; set;}
        @AuraEnabled
        public String destinatarioId {get; set;}  
        @AuraEnabled
        public Boolean drilldown {get;set;}
        @AuraEnabled
        public Boolean isClosed {get;set;}
        @AuraEnabled
        public PopOver popOverData {get; set;}
        @AuraEnabled
        public String cssClass {get;set;}

        public RowWrapper() {
            cantidad = 0;
        }
    } 

    global class PopOver{
        @AuraEnabled
        public String ventaName {get; set;}
        @AuraEnabled
        public String ventaId {get; set;}
        @AuraEnabled
        public Date fecha {get; set;}
        @AuraEnabled
        public String campanaId {get; set;}
        @AuraEnabled
        public String campanaName {get; set;}
        @AuraEnabled
        public String cultivoId {get; set;}
        @AuraEnabled
        public String cultivoName {get; set;}
        @AuraEnabled
        public String destinatarioId {get; set;}
        @AuraEnabled
        public String destinatarioName {get; set;}
        @AuraEnabled
        public String originanteId {get; set;}
        @AuraEnabled
        public String originanteName {get; set;}
        @AuraEnabled
        public String tipoDeVenta {get; set;}
    }
    
}