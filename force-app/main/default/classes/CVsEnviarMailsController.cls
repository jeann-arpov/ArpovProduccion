public with sharing class CVsEnviarMailsController{

    public class MyException extends Exception{}
    
    public List<Wrapper> cvs {get;set;}
    private String retURL;
    public ApexPages.StandardSetController stdCon {get;set;}
    private Set<String> cvIds;
    public Boolean showBatchJobsStatus {get;set;}
    public String apexClassName {get;set;}
    public Decimal cantidadSeleccionados {get;set;}
    private Set<String> cvEmailsIds;
    
    public CVsEnviarMailsController(ApexPages.StandardSetController stdCon){
        this.stdCon = stdCon;
        retURL = ApexPages.currentPage().getParameters().get('retURL');
        init();
    }
    
    public CVsEnviarMailsController(ApexPages.StandardController stdCon){
    
    }

    public class Wrapper{
    
        public String name{get;set;}
        private Date fechaEnvioMail;

        public Wrapper(String name, Date fechaEnvioMail){
            this.name = name;
            this.fechaEnvioMail = fechaEnvioMail;
        }
        
        public String getFechaEnvioMail(){
            if(fechaEnvioMail != null){
                return fechaEnvioMail.format();
            }
            return '';
        }
        
    }

    private void init(){

        cvIds = new Set<String>();
        cvEmailsIds = new Set<String>();
        for(ERPvs__Comprobante_Venta__c cv : (List<ERPvs__Comprobante_Venta__c>)stdCon.getSelected()){
            cvIds.add(cv.Id);
        }
        Integer count = 0;
        cvs = new List<Wrapper>();
        for(ERPvs__Comprobante_Venta__c cv : [SELECT Id, Name, Fecha_envio_mail__c FROM ERPvs__Comprobante_Venta__c WHERE Id IN :cvIds AND ERPvs__Contabilizar__c = true]){
            cvEmailsIds.add(cv.Id);
            if(count < 20){
                cvs.add(new Wrapper(cv.Name, cv.Fecha_envio_mail__c));
            } else if(count == 20){
                cvs.add(new Wrapper('...', null));
            }
            count++;
        }
        cantidadSeleccionados = count;
        showBatchJobsStatus = false;

    }
    
    public PageReference doCancel(){
        return new PageReference(retURL);
    }

    public PageReference doEnviarMails(){
        
        Database.executeBatch(new BatchApexCVsEnviarEmails(cvEmailsIds), 1);
        apexClassName = 'BatchApexCVsEnviarEmails';
        showBatchJobsStatus = true;
        
        return null;
        
    }
    
}