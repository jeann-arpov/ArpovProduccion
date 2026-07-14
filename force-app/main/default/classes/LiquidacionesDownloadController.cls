/**
* @author Maximo Martinez
* @date 10/02/2016
* @description Clase controladora de la vista liquidacionesDownload
*/
public with sharing class LiquidacionesDownloadController {
	
	private String retURL;
    public List<Opportunity> opportunities {get; set;}	
    public ApexPages.StandardSetController stdCon {get;set;}
    
    public LiquidacionesDownloadController(ApexPages.StandardSetController stdCon){
        this.stdCon = stdCon;
        retURL = ApexPages.currentPage().getParameters().get('retURL');
        init();
    }

    private void init(){

    	Set<String> oppsIds = new Set<String>();
        
        for(Opportunity opp : (List<Opportunity>)stdCon.getSelected()){
            oppsIds.add(opp.Id);
        }
        
        opportunities = [SELECT Id, Name, Descargar_FE__c FROM Opportunity WHERE Id IN :oppsIds];

    }

    public PageReference doCancel(){
        return new PageReference(retURL);
    }

    public PageReference doDownload(){

        Set<String> oppsIds = new Set<String>();

        try{

            //Marco las opportunities para descarga
            for(Opportunity opp : opportunities){
                oppsIds.add(opp.Id);
                opp.Descargar_FE__c = true;
            }
            
            Utils.updateList(opportunities, true);
            setDescargarFalse(oppsIds);
            
        } catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
            return null;
        }

        return new PageReference(retURL);
        
    }

    @future
    public static void setDescargarFalse(Set<String> oppsIds){   
        //Activo el flag de los CV de controlar
        List<Opportunity> liquidaciones = [SELECT Id, Name, Descargar_FE__c FROM Opportunity WHERE Id IN :oppsIds];
        for(Opportunity opp : liquidaciones){
            opp.Descargar_FE__c = false;
        }  
        
        Utils.updateList(liquidaciones, true);
    }

}