public with sharing class AnexoLPController{

    public class MyException extends Exception{}
    private String ccId;    
    public ApexPages.StandardSetController stdCon {get;set;}
    private String retURL;
    
    private String qry {get;set;}
    private String qryFilter {get;set;}
    private String qryOrder {get;set;}
    
    public List<Wrapper> pcvs{get;set;}
    private Set<ID> setNoElegidos;
    private Set<String> setCVsShowed;
    
    public final Integer recordsPerPage = 30;
    public Integer currentPageNumber {get;set;}
    public Boolean checkAllActive {get;set;}
    public Boolean showDetail {get;set;}

    public Integer totalRegistros {get;set;}
    public Integer pages {get;set;}
    public Integer currentPageNumber2 {get;set;}
    public Integer totalRegistrosOcultos {get;set;}

    public class Wrapper {
        public Boolean showTotal {get;set;}
        public ERPvs__Productos_Comprobante_de_Venta__c pcv {get;set;}
        
        public Wrapper(Boolean showTotal, ERPvs__Productos_Comprobante_de_Venta__c pcv){
            this.showTotal = showTotal;
            this.pcv = pcv;
        }
        
        private Decimal getProporcion(){
            return (pcv.ERPvs__Subtotal_Sin_IVA__c * 100)/ pcv.ERPvs__Comprobante__r.ERPvs__Subtotal__c;
        }
        
        public String getImportePercepcionIVA(){
            System.Debug(LoggingLevel.WARN,'getImportesPercepciones()');
            System.Debug(LoggingLevel.WARN,'getProporcion(): ' + getProporcion());
            System.Debug(LoggingLevel.WARN,'pcv.ERPvs__Comprobante__r.ERPvs__Percepcion_Iva__c: ' + pcv.ERPvs__Comprobante__r.ERPvs__Percepcion_Iva__c);
            return pcv.ERPvs__Comprobante__r.ERPvs__Percepcion_Iva__c != null && pcv.ERPvs__Comprobante__r.ERPvs__Percepcion_Iva__c > 0 ? Utils.numberFormat((pcv.ERPvs__Comprobante__r.ERPvs__Percepcion_Iva__c * (getProporcion() / 100)).format()) : Utils.numberFormat('0');
        }
        
        public String getOtrosImpuestos(){
            if(!showTotal){
                return '';
            }
            return pcv.ERPvs__Comprobante__r.ERPvs__Percepciones_IB__c != null && pcv.ERPvs__Comprobante__r.ERPvs__Percepciones_IB__c > 0 ? Utils.numberFormat(pcv.ERPvs__Comprobante__r.ERPvs__Percepciones_IB__c.format()) : Utils.numberFormat('0');
        }
        
        public String getImportesPercepciones(){
            System.Debug(LoggingLevel.WARN,'getImportesPercepciones()');
            System.Debug(LoggingLevel.WARN,'getProporcion(): ' + getProporcion());
            System.Debug(LoggingLevel.WARN,'pcv.ERPvs__Comprobante__r.ERPvs__Percepciones_IB__c: ' + pcv.ERPvs__Comprobante__r.ERPvs__Percepciones_IB__c);
            if(!showTotal){
                return '';
            }
            return pcv.ERPvs__Comprobante__r.ERPvs__Percepciones_IB__c != null && pcv.ERPvs__Comprobante__r.ERPvs__Percepciones_IB__c > 0 ? Utils.numberFormat(pcv.ERPvs__Comprobante__r.ERPvs__Percepciones_IB__c.format()) : Utils.numberFormat('0');
        }
        
    }

    public AnexoLPController(ApexPages.StandardController stdCon){
        
        System.Debug(LoggingLevel.WARN,'AnexoLPController(ApexPages.StandardSetController stdCon)');
        ccId = stdCon.getRecord().Id;
        init();
        
    }
    
    public AnexoLPController(){
        
        System.Debug(LoggingLevel.WARN,'AnexoLPController()');
        
        init();
        
    }
    
    private void init(){
        
        qry = 'SELECT Id, Name, ERPvs__Comprobante__r.ERPvs__Razon_Social_1__c, ERPvs__Comprobante__r.ERPvs__Identificacion_tributaria_1__c, ERPvs__Comprobante__r.ERPvs__Fecha__c, ERPvs__Comprobante__r.ERPvs__Tipo_comp__c, ERPvs__Comprobante__r.ERPvs__Numero_Comprobante__c, ERPvs__Precio_unitario__c, ERPvs__Cantidad__c, ';
        qry += 'ERPvs__Subtotal__c, ERPvs__Subtotal_Sin_IVA__c, ERPvs__Porcentaje_de_IVA__c, ERPvs__Importe_de_IVA__c, ERPvs__Comprobante__r.ERPvs__tc__c, ERPvs__Producto__r.CRM_Producto__r.Cultivo__r.Name, ERPvs__Producto__r.CRM_Producto__r.Variedad__c, ';
        qry += 'ERPvs__Producto__r.ERPvs__Descripcion_facturacion__c, ERPvs__Observaciones__c, ERPvs__Comprobante__r.Transaccion__r.RecordType.Name, ERPvs__Comprobante__r.Transaccion__r.Name, ERPvs__Comprobante__r.ERPvs__Percepcion_Iva__c, ERPvs__Comprobante__r.ERPvs__Subtotal__c, ';
        qry += 'ERPvs__Comprobante__r.ERPvs__Percepciones_IB__c ';
        qry += 'FROM ERPvs__Productos_Comprobante_de_Venta__c ';
        qryOrder = ' ORDER BY ERPvs__Comprobante__r.ERPvs__Fecha__c ASC';

        createQryFilter();
    
        System.Debug(LoggingLevel.WARN,'Qry: '+qry+qryFilter+qryOrder);
        
        stdCon = new ApexPages.StandardSetController(Database.getQueryLocator(qry+qryFilter+qryOrder));
        stdCon.setPageSize(recordsPerPage);
        
        retURL = ApexPages.currentPage().getParameters().get('retURL');

        doSearch();
        
    }
    
    public PageReference doSearch(){
        System.Debug('doSearch');
        try{
            
            pages = Integer.valueOf(getTotalPages());
            
            currentPageNumber = stdCon.getPageNumber();
            currentPageNumber2 = currentPageNumber;
            setNoElegidos = new Set<ID>();
            checkAllActive = false;
            getComprobantes();
            showDetail = true;
            totalRegistros = stdCon.getResultSize();
            
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        
        return null;
    }
    
    private void createQryFilter(){
    
        qryFilter = ' WHERE ERPvs__Comprobante__r.ERPvs__Liquido_producto__c = \'' + ccId + '\'';
    
    }
    
    public void getComprobantes(){
        System.Debug('getComprobantes');
        pcvs = new List<Wrapper>();
        setCVsShowed = new Set<String>();
        Boolean showTotal;
        
        if(stdCon != null){
            List<ERPvs__Productos_Comprobante_de_Venta__c> pcvsPaginados = (List<ERPvs__Productos_Comprobante_de_Venta__c>)stdCon.getRecords();
            System.Debug('pcvsPaginados:' + pcvsPaginados);
            for(ERPvs__Productos_Comprobante_de_Venta__c pcv: pcvsPaginados){
                if(setCVsShowed.contains(pcv.id)){
                    showTotal = false;
                } else {
                    showTotal = true;
                    setCVsShowed.add(pcv.ERPvs__Comprobante__c);
                }
                pcvs.add(new Wrapper(showTotal, pcv));
            }
        }
        
    }
    
    public PageReference doCancel(){
        return new PageReference(retURL != null ? retURL : '/home/home.jsp');
    }
    
    public Boolean getHasNext(){
        System.Debug('getHasNext');
        if(stdCon != null){
            return stdCon.getHasNext();
        }else{
            return false;
        }
    }
    
    public Boolean getHasPrevious(){
        System.Debug('getHasPrevious');
        if(stdCon != null){
            return stdCon.getHasPrevious();
        }else{
            return false;
        }   
    }
    
    private void controlaCheckeados(){
        System.Debug('controlaCheckeados');
        /**
        for(Wrapper w: pcvs){
            if(w.isChecked == true){
                setNoElegidos.remove(w.pcv.Id);
            }else{
                setNoElegidos.add(w.pcv.Id);
            }    
        }
        checkAllActive = false;
        **/
    }
        
    
    public PageReference next(){
        System.Debug('next');
        try{
            if(stdCon != null){
                if(stdCon.getHasNext()){
                    controlaCheckeados();
                    stdCon.next();
                    currentPageNumber++;
                    currentPageNumber2 = currentPageNumber;
                    getComprobantes();
                }
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        return null;
    }
    
    public PageReference previous(){
        System.Debug('previous');
        try{
            if(stdCon != null){
                if(stdCon.getHasPrevious()){
                    controlaCheckeados();
                    stdCon.previous();
                    currentPageNumber--;
                    currentPageNumber2 = currentPageNumber;
                    getComprobantes();
                }
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        return null;
    }
    
    public void doFirst(){
        System.Debug('doFirst');
        try{
            if(stdCon != null){
                controlaCheckeados();
                currentPageNumber = 1;
                currentPageNumber2 = 1;
                stdCon.setpageNumber(1);
                getComprobantes();
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
    }
    
    public void doLast(){
        System.Debug('doLast');
        try{
            if(stdCon != null){
                controlaCheckeados();
                currentPageNumber = pages;
                currentPageNumber2 = pages;
                stdCon.setpageNumber(pages);
                getComprobantes();
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
    }
    
    
    public PageReference goToPage(){
        System.Debug('goToPage');
        try{
            if(stdCon != null){
                controlaCheckeados();
                if(currentPageNumber < 1)
                    currentPageNumber = 1;
                if(currentPageNumber > pages)
                    currentPageNumber = pages;
                currentPageNumber2 = currentPageNumber;
                stdCon.setPageNumber(currentPageNumber);
                getComprobantes();
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        return null;
    }
    
    public PageReference goToPage2(){
        System.Debug('goToPage2');
        try{
            if(stdCon != null){
                controlaCheckeados();
                if(currentPageNumber2 < 1)
                    currentPageNumber2 = 1;
                if(currentPageNumber2 > pages)
                    currentPageNumber2 = pages;
                currentPageNumber = currentPageNumber2;
                stdCon.setPageNumber(currentPageNumber2);
                getComprobantes();
            }
        }catch(Exception e){
            ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.Error, e.getMessage()));
        }
        return null;
    }
    
    public boolean getHasResults(){
        System.Debug('getHasResults');
        return (stdCon != null);
    }
    
    public String getPageNumber(){
        System.Debug('getPageNumber');
        String result = '';
        if(stdCon != null){
             result = stdCon.getPageNumber() + ' / ' + getTotalPages();
        }
        return result;
    }
    
    public String getTotalPages(){
        System.Debug('getTotalPages');
        if(stdCon != null){
            return String.valueOf(Integer.valueOf(Decimal.valueOf(stdCon.getResultSize()).divide(recordsPerPage, 0, System.RoundingMode.UP)));          
        }else{
            return '';
        }
    }
    
    public Integer getRecordViewFrom(){
        System.Debug('getRecordViewFrom');
        return totalRegistros > 0 ? 1 + (recordsPerPage * (currentPageNumber - 1)) : 0;
    }
    
    public Integer getRecordViewTo(){
        System.Debug('getRecordViewTo');
        Integer records = recordsPerPage + (recordsPerPage * (currentPageNumber - 1));
        return totalRegistros < records ? totalRegistros : records;
    }
    
    public PageReference doGenerateExcel(){
    
        Boolean exists;
        
        doSearch();
        while(stdCon.getHasNext()){
            stdCon.next();
            List<ERPvs__Productos_Comprobante_de_Venta__c> pcvsPaginados = (List<ERPvs__Productos_Comprobante_de_Venta__c>)stdCon.getRecords();
            System.Debug('pcvsPaginados:' + pcvsPaginados);
            for(ERPvs__Productos_Comprobante_de_Venta__c pcv: pcvsPaginados){
                if(setNoElegidos.contains(pcv.id)){
                    exists = false;
                } else {
                    exists = true;
                }
                pcvs.add(new Wrapper(exists, pcv));
            }
        }
        
        return Page.anexoLPExcel;
    }

    
}