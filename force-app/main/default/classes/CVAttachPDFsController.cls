public with sharing class CVAttachPDFsController{

    public class MyException extends Exception{}
    
    public List<Wrapper> comprobantes {get;set;}
    private String retURL;
    public ApexPages.StandardSetController stdCon {get;set;}
    private Set<String> cvIds;
    public Boolean showBatchJobsStatus {get;set;}
    public String apexClassName {get;set;}
    public Decimal cantidadSeleccionados {get;set;}
    public List<String> cvAttachIds {get;set;}
    public Boolean disableButtons {get;set;}
    public String urlImagenFondo {get;set;}
    
    public CVAttachPDFsController(ApexPages.StandardSetController stdCon){
        this.stdCon = stdCon;
        retURL = ApexPages.currentPage().getParameters().get('retURL');
        init();
    }
    
    public CVAttachPDFsController(ApexPages.StandardController stdCon){
    
    }

    public class Wrapper{
        public String name{get;set;}

        public Wrapper(String name){
            this.name = name;
        }
    }

    private void init(){

        cvIds = new Set<String>();
        cvAttachIds = new List<String>();
        for(ERPvs__Comprobante_Venta__c cv : (List<ERPvs__Comprobante_Venta__c>)stdCon.getSelected()){
            cvIds.add(cv.Id);
        }
        Integer count = 0;
        comprobantes = new List<Wrapper>();
        for(ERPvs__Comprobante_Venta__c cv : [SELECT Id, Name, ERPvs__Empresa_Sucursal__r.ERPvs__Empresa__r.ERPvs__URL_Imagen_Fondo_FE__c FROM ERPvs__Comprobante_Venta__c WHERE Id IN :cvIds]){
            cvAttachIds.add(cv.Id);
            urlImagenFondo = cv.ERPvs__Empresa_Sucursal__r.ERPvs__Empresa__r.ERPvs__URL_Imagen_Fondo_FE__c;
            if(count < 20){
                comprobantes.add(new Wrapper(cv.Name));
            } else if(count == 20){
                comprobantes.add(new Wrapper('...'));
            }
            count++;
        }
        cantidadSeleccionados = count;
        showBatchJobsStatus = false;

        disableButtons = count == 0 ? true : false;
        
    }
    
    public PageReference doCancel(){
        return new PageReference(retURL);
    }

    public PageReference doAttach(){
        
        Database.executeBatch(new BatchApexCVAttachPDFs(cvAttachIds), 1);
        apexClassName = 'BatchApexCVAttachPDFs';
        showBatchJobsStatus = true;
        
        return null;
        
    }

    public PageReference doPrintMassive(){
        
        System.Debug('doPrintMassive()');
        System.Debug('cvAttachIds: ' + cvAttachIds);

        return Page.printAllCVMassive;
        
    }

    
}