public with sharing class CVAgregarDocumentosAfectadosController{

    public class MyException extends Exception{}
    private static String DIF_CAMBIO = 'Diferencia de cambio';
    
    public List<Wrapper> comprobantes {get;set;}
    private String retURL;
    public ApexPages.StandardSetController stdCon {get;set;}
    private Set<String> cvIds;
    private Set<Id> cvIdsToProcess;
    public Boolean showBatchJobsStatus {get;set;}
    public String apexClassName {get;set;}
    public Decimal cantidadSeleccionados {get;set;}
    
    
    public CVAgregarDocumentosAfectadosController(ApexPages.StandardSetController stdCon){
        this.stdCon = stdCon;
        retURL = ApexPages.currentPage().getParameters().get('retURL');
        init();
    }
    
    public CVAgregarDocumentosAfectadosController(ApexPages.StandardController stdCon){
    
    }

    public class Wrapper{
        public String name{get;set;}

        public Wrapper(String name){
            this.name = name;
        }
    }

    private void init(){

        cvIds = new Set<String>();
        cvIdsToProcess = new Set<Id>();
        for(ERPvs__Comprobante_Venta__c cv : (List<ERPvs__Comprobante_Venta__c>)stdCon.getSelected()){
            cvIds.add(cv.Id);
        }
        Integer count = 0;
        comprobantes = new List<Wrapper>();
        for(ERPvs__Comprobante_Venta__c cv : [SELECT Id, Name FROM ERPvs__Comprobante_Venta__c WHERE Id IN :cvIds AND ERPvs__Contabilizar__c = true AND Tipo_Movimiento__c = :DIF_CAMBIO]){
            if(count < 20){
                comprobantes.add(new Wrapper(cv.Name));
            } else if(count == 20){
                comprobantes.add(new Wrapper('...'));
            }
            count++;
            cvIdsToProcess.add(cv.Id);
        }
        cantidadSeleccionados = count;
        showBatchJobsStatus = false;
        
    }
    
    public PageReference doCancel(){
        return new PageReference(retURL);
    }

    public PageReference doAgregar(){

        Database.executeBatch(new BatchApexAgregarDocumentosAfectados(cvIdsToProcess), 1);
        apexClassName = 'BatchApexAgregarDocumentosAfectados';
        showBatchJobsStatus = true;

        return null;
        
    }
    
    
}