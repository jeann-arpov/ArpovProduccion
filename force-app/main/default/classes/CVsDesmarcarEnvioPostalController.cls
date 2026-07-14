public with sharing class CVsDesmarcarEnvioPostalController{

    public class MyException extends Exception{}
    
    public List<Wrapper> cvs {get;set;}
    private String retURL;
    public ApexPages.StandardSetController stdCon {get;set;}
    private Set<String> cvIds;
    public Decimal cantidadSeleccionados {get;set;}
    private Set<String> cvEmailsIds;
    
    public CVsDesmarcarEnvioPostalController(ApexPages.StandardSetController stdCon){
        this.stdCon = stdCon;
        retURL = ApexPages.currentPage().getParameters().get('retURL');
        init();
    }
    
    public CVsDesmarcarEnvioPostalController(ApexPages.StandardController stdCon){
    
    }

    public class Wrapper{
    
        public String name{get;set;}
        private Date fechaEnvioCorreoPostal;

        public Wrapper(String name, Date fechaEnvioCorreoPostal){
            this.name = name;
            this.fechaEnvioCorreoPostal = fechaEnvioCorreoPostal;
        }
        
        public String getFechaEnvioCorreoPostal(){
            if(fechaEnvioCorreoPostal != null){
                return fechaEnvioCorreoPostal.format();
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
        for(ERPvs__Comprobante_Venta__c cv : [SELECT Id, Name, Fecha_Envio_Correo_Postal__c FROM ERPvs__Comprobante_Venta__c WHERE Id IN :cvIds AND ERPvs__Contabilizar__c = true AND Enviado_Correo_postal__c = true]){
            cvEmailsIds.add(cv.Id);
            if(count < 20){
                cvs.add(new Wrapper(cv.Name, cv.Fecha_Envio_Correo_Postal__c));
            } else if(count == 20){
                cvs.add(new Wrapper('...', null));
            }
            count++;
        }
        cantidadSeleccionados = count;
    
    }
    
    public PageReference doCancel(){
        return new PageReference(retURL);
    }

    public PageReference doDesmarcarCorreoPostal(){
        
        List<ERPvs__Comprobante_Venta__c> cvs = [SELECT Id, Name, Fecha_Envio_Correo_Postal__c FROM ERPvs__Comprobante_Venta__c WHERE Id IN :cvIds AND ERPvs__Contabilizar__c = true AND Enviado_Correo_postal__c = true];
        
        for(ERPvs__Comprobante_Venta__c cv : cvs){
            cv.Fecha_Envio_Correo_Postal__c = null;
            cv.Enviado_Correo_postal__c = false;
            cv.ERPvs__No_controlar__c = true;
        }
        
        update cvs;
        
        for(ERPvs__Comprobante_Venta__c cv : cvs){
            cv.ERPvs__No_controlar__c = false;
        }
        
        update cvs;
        
        return doCancel();
        
    }
    
}