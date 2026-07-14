public with sharing class ComprobantesVentaDownloadController{

    public class MyException extends Exception{}
    
    public List<ERPvs__Comprobante_Venta__c> comprobantes {get;set;}
    private String retURL;
    public ApexPages.StandardSetController stdCon {get;set;}
    
    public ComprobantesVentaDownloadController(ApexPages.StandardSetController stdCon){
        this.stdCon = stdCon;
        retURL = ApexPages.currentPage().getParameters().get('retURL');
        init();
    }
    
    public ComprobantesVentaDownloadController(ApexPages.StandardController stdCon){
    
    }

    private void init(){

        Set<String> cvIds = new Set<String>();
        for(ERPvs__Comprobante_Venta__c cv : (List<ERPvs__Comprobante_Venta__c>)stdCon.getSelected()){
            cvIds.add(cv.Id);
        }
        comprobantes = [SELECT Id, Name, ERPvs__No_controlar__c, Descargar_FE__c FROM ERPvs__Comprobante_Venta__c WHERE Id IN :cvIds AND ERPvs__Contabilizar__c = true AND ERPvs__CAE__c != null];

    }
    
    public PageReference doCancel(){
        return new PageReference(retURL);
    }

    public PageReference doDownload(){

        Set<String> cvIds = new Set<String>();
        try{
            //Marco los CV para descarga
            for(ERPvs__Comprobante_Venta__c cv : comprobantes){
                cvIds.add(cv.Id);
                cv.ERPvs__No_controlar__c = true;
                cv.Descargar_FE__c = true;
            }
            update comprobantes;
            
            activateNoControlar(cvIds);
            
        } catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
            return null;
        }

        return new PageReference(retURL);
        
    }
    
    @future
    public static void activateNoControlar(Set<String> cvsIds){   
        //Activo el flag de los CV de controlar
        List<ERPvs__Comprobante_Venta__c> comprobantes = [SELECT Id, ERPvs__No_controlar__c, Descargar_FE__c FROM ERPvs__Comprobante_Venta__c WHERE ID IN :cvsIds];
        for(ERPvs__Comprobante_Venta__c cv : comprobantes){
            cv.ERPvs__No_controlar__c = false;
            cv.Descargar_FE__c = false;
        }  
        
        update comprobantes;
    }
    
}