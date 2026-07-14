/**
* @author Joaquin Iudica
* @date 26/04/2022
* @description Controlador de la la Visual Force OppParaFacturar
*/
public with sharing class OppParaFacturarController {

    private final static Integer PAGE_SIZE = 50;

    //pagination info
    public Integer page{get;set;}
    public Integer totalRecords{get;set;}
    public Integer totalPages{get;set;}
    public Integer startIdx{get;set;}
    public Integer endIdx{get;set;}

    private Set<Id> selectedOppLineItemsIds {get; set;} 
    private Map<Id, LineaOportunidad> mapSelectedOpplis {get;set;}
  
    private Set<Id> inBatchTransaction {get; set;}
  
    private String baseQuery {get; set;}
  
    public List<SelectOption> obtentores {get;set;}
    public String selectedObtentor {get; set;}
  
    public List<SelectOption> razonesSociales {get;set;}
    public String selectedRazon {get; set;}

    public String nameApexClass {get; set;}

    private Date selectedDate;

    private Date today;

    public Map<ID, Opportunity> mapOportunidades {get;set;} //para poder acceder a la data de oportunidad desde lineaOportunidad

    public List<OpportunityLineItem> lineasOportunidades {get;set;} //todos los registros
    public List<LineaOportunidad> tRecords{get;set;} //registros x pagina
  
    private transient BatchGenerarCvsDesdeOportunidad b; 
  
    public Integer countCheckedIds {get; set;}
  
    public OppParaFacturarController(){
        selectedOppLineItemsIds = new Set<Id>();
        mapSelectedOpplis = new Map<Id, lineaOportunidad>();
        countCheckedIds = 0;
        inBatchTransaction = new Set<Id>();
        nameApexClass = 'BatchGenerarCvsDesdeOportunidad';
        today = Date.today();
        tRecords = new List<LineaOportunidad>();
        query();
    }
  
    public void query(){
        //reiniciamos paginacion
        resetPaging();

        makeQuery();

        System.debug('query ===> ' + baseQuery);

        List<Opportunity> opps = Database.query(baseQuery);
        //System.debug('opps ===> ' + opps[0].OpportunityLineItems);

        if(opps.size() > 0){
            
            System.debug(LoggingLevel.DEBUG, opps.size());

            lineasOportunidades = processRecords(opps);

            getRecords();
        }
    }

    public List<OpportunityLineItem> processRecords(List<Opportunity> opps){
        mapOportunidades = new Map<ID, Opportunity>();
        Set<Id> obtentoresIds = new Set<Id>();
        Set<Id> razonesIds = new Set<Id>();
        List<SelectOption> obtentoresAux = new List<SelectOption>{new SelectOption('', '--Ninguno--')};
        List<SelectOption> razonesSocialesAux = new List<SelectOption>{new SelectOption('', '--Ninguno--')};
        List<OpportunityLineItem> opplis = new List<OpportunityLineItem>();
        for(Opportunity opp : opps){
            mapOportunidades.put(opp.Id, opp);
            for(OpportunityLineItem oli : opp.OpportunityLineItems){
                if(!obtentoresIds.contains(oli.Product2.Variedad2__r.Obtentor_Comercializa__c)){
                    obtentoresIds.add(oli.Product2.Variedad2__r.Obtentor_Comercializa__c);
                    obtentoresAux.add(new SelectOption(oli.Product2.Variedad2__r.Obtentor_Comercializa__c, oli.Product2.Variedad2__r.Obtentor_Comercializa__r.Name));
                }
                opplis.add(oli);
            }
            if(!razonesIds.contains(opp.Account.Id)){
                //System.debug(LoggingLevel.DEBUG, opp.Account.Id);
                razonesIds.add(opp.Account.Id);
                razonesSocialesAux.add(new SelectOption(opp.Account.Id, opp.Account.Name));
            }
        }

        obtentores = obtentoresAux;
        razonesSociales = razonesSocialesAux;

        return opplis;
    }

    public Boolean getShowBatchJobsStatus(){
        return 0 < [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = :nameApexClass AND DAY_ONLY(CreatedDate) = :today ];
    }
  
  
    public PageReference applyFilter(){

        // Limpiamos los set que contienen los datos seleccionados
        selectedOppLineItemsIds = new Set<Id>();

        lineasOportunidades = null;

        tRecords.clear();

        query();

        return null;
    }

    private void resetPaging(){
        page = 1;
        startIdx = 0;
        endIdx = page * PAGE_SIZE;
        totalRecords = 0;
        totalPages = 0;
    }
  
    private void setSelected(){

        if(tRecords != null){

            System.debug('tRecords.size: ' + tRecords.size());

            for(LineaOportunidad lo : tRecords){

                System.debug('lo: ' + lo);
                System.debug('lo.isSelected: ' + lo.isSelected);

                if(lo.isSelected){
                    selectedOppLineItemsIds.add(lo.lineaOportunidad.Id);
                    mapSelectedOpplis.put(lo.lineaOportunidad.Id, lo);
                }else{
                    selectedOppLineItemsIds.remove(lo.lineaOportunidad.Id);
                    mapSelectedOpplis.remove(lo.lineaOportunidad.Id);
                }
            }
        }

        countCheckedIds = selectedOppLineItemsIds.size();
    }

    //return current page of records
    public void getRecords(){
        
        //calculate range of records for capture
        startIdx = (page-1)*PAGE_SIZE;

        endIdx = page*PAGE_SIZE;

        totalRecords = 0;
        
        //clear container for records displayed
        tRecords.clear();
                
        
        for(OpportunityLineItem oppli : lineasOportunidades){
            //capture records within the target range
            if(totalRecords >= startIdx && totalRecords < endIdx){ 

                //System.debug('subtotal: ' + oppli.subtotal);
                
                LineaOportunidad lo = new LineaOportunidad();
            
                lo.lineaOportunidad = oppli;
                
                lo.isSelected = selectedOppLineItemsIds.contains(lo.lineaOportunidad.Id);
                
                //lo.isProcessing = false;

                lo.oportunidad = mapOportunidades.get(oppli.opportunityId);
           
                tRecords.add(lo);
            }
            
            //count the total number of records
            totalRecords++;
        }
        
        
        //calculate total pages
        Decimal pages = Decimal.valueOf(this.totalRecords);
        System.debug('@@@pages'+ pages);

        pages = pages.divide(Decimal.valueOf(PAGE_SIZE), 2);
        System.debug('@@@pages'+ pages);

        totalPages = (Integer)pages.round(System.RoundingMode.CEILING);
        System.debug('@@@totalpages'+ totalPages);
        
        //adjust start index e.g. 1, 11, 21, 31
        startIdx++;
        
        
        //adjust end index
        if(endIdx > totalRecords){
            endIdx = totalRecords;
        }
     
        
        //display resource usage
        System.Debug(LoggingLevel.WARN,'@@@ LIMIT query rows: '+Limits.getQueryRows()+' / '+Limits.getLimitQueryRows());
        System.Debug(LoggingLevel.WARN,'@@@ LIMIT heap size: '+Limits.getHeapSize()+' / '+Limits.getLimitHeapSize());
        System.Debug(LoggingLevel.WARN,'@@@ LIMIT cpu time: '+Limits.getCpuTime()+' / '+Limits.getLimitCpuTime());        
    }

    public class LineaOportunidad {

        public Boolean isSelected {get;set;}

        //public Boolean isProcessing {get;set;}

        public Opportunity oportunidad {get;set;}

        public OpportunityLineItem lineaOportunidad {get;set;}

        public Boolean getHasError(){
            Boolean result = false;

            return result;
        }
  
        public String getError(){
            String result = '';

            return result;
        }

        public String getObtentor(){
            return this.lineaOportunidad.Product2.Variedad2__r.Obtentor_Comercializa__c;
        }

        public String getObtentorName(){
            return this.lineaOportunidad.Product2.Variedad2__r.Obtentor_Comercializa__r.Name;
        }

        public String getVariedad(){
            return this.lineaOportunidad.Product2.Variedad2__c;
        }

        public String getVariedadName(){
            return this.lineaOportunidad.Product2.Variedad2__r.Name;
        }

        public String getProducto(){
            return this.lineaOportunidad.Product2.Id;
        }

        public String getProductoName(){
            return this.lineaOportunidad.Product2.Name;
        }

        public String getCliente(){
            return this.oportunidad.Account.Id;
        }

        public String getClienteName(){
            return this.oportunidad.Account.Name;
        }

        public Decimal getSubtotal(){
            return this.lineaOportunidad.subtotal;
        }
    }

    public void doFirstPage(){
        setSelected();
        page = 1;
        getRecords();
    }

    public void doLastPage(){
        setSelected();
        page = totalPages;
        getRecords();
    }
  
    //advance to next page
    public void doNext(){
        setSelected();
        this.page++;
        getRecords();
    }
    
    //advance to previous page
    public void doPrevious(){
        setSelected();
        this.page--;
        getRecords();
    }
    
    //returns whether the previous page exists
    public Boolean getHasPrevious(){
        if(this.page > 1){
            return true;
        }
        else{
            return false;
        }
    }
    
    //returns whether the next page exists
    public Boolean getHasNext(){
        if(this.page < this.totalPages){
            return true;
        }
        else{
            return false;
        }
    }
  
    /**
     * @description Metodo encargado de generar la Query que usa el paginador
    */
    private void makeQuery(){
        
        baseQuery = 'SELECT Id, Name, Estado__c, Account.Id, Account.Name, Account.Direccion_de_Correo_electronico_del_CUIT__c, Tipo_de_Comprobante__c, ';
        baseQuery += '(SELECT OpportunityId, Estado__c, Product2.Name, Product2.Variedad2__r.Obtentor_Comercializa__c, Product2.ERPvs_Producto__c, Product2.ERPvs_Producto__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c, ';
        baseQuery += 'Quantity, Product2.Variedad2__r.Obtentor_Comercializa__r.Condicion_Comercial_SE__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Tipo_comprobante_venta_SE__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Name, ';
        baseQuery += 'Product2.Variedad2__r.Name, Product2.Variedad2__r.Obtentor_Comercializa__r.Tipo_comprobante_venta_NC_SE__c, ListPrice, Subtotal FROM OpportunityLineItems WHERE Estado__c = \'Facturable\' ';
        baseQuery += 'AND Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c = true AND id not in (select OpportunityLineItem__c from ERPvs__Productos_Comprobante_de_Venta__c) ';
        
        String filtroQueryObtentor = '';
        if(String.isNotBlank(selectedObtentor)){
            filtroQueryObtentor += ' AND Product2.Variedad2__r.Obtentor_Comercializa__c = :selectedObtentor';
        }
        
        baseQuery += filtroQueryObtentor + ') ';
        
        baseQuery += 'FROM Opportunity WHERE StageName = \'Pendiente de Facturación\' AND Opportunity.RecordType.DeveloperName = \'Sembra_Evolucion\' and Compra_HT__r.Resultado_Validacion_Analista__c = \'Positiva\'';

        if(String.isNotEmpty(selectedRazon)){
            baseQuery += ' AND AccountId = :selectedRazon';
        }

        baseQuery += ' AND Id NOT IN :inBatchTransaction';

        baseQuery += ' LIMIT 10000';
    }
  
    public PageReference facturar(){
        
        setSelected();

        try{

            // Si no hay elementos seleccionados indicamos esto
            if(selectedOppLineItemsIds.isEmpty()){
                
                Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'No hay elementos seleccionados.'));
                
                return null;
            }

            System.debug('selectedOppLineItemsIds: ' + selectedOppLineItemsIds);

            Set<Id> oportunidadesAFacturar = new Set<Id>();
            for(Id oppliId : selectedOppLineItemsIds){
                oportunidadesAFacturar.add(mapSelectedOpplis.get(oppliId).lineaOportunidad.opportunityId);
            }

            System.debug('ids de oportunidades a facturar: ' + oportunidadesAFacturar);
            

            // Enviamos a procesar por el batch

            BatchGenerarCvsDesdeOportunidad b = new BatchGenerarCvsDesdeOportunidad(new List<Id>(oportunidadesAFacturar));

            Database.executebatch(b, BatchGenerarCvsDesdeOportunidad.BATCH_SIZE);

            inBatchTransaction.addAll(oportunidadesAFacturar);

            selectedOppLineItemsIds = new Set<Id>();
            mapSelectedOpplis = new Map<Id, LineaOportunidad>();

            countCheckedIds = 0;

            query();

            //ApexPages.addmessages(e);
            Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM,'Operación Exitosa'));

        }catch(Exception e){

            //ApexPages.addmessages(e);
            Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, e.getMessage()));
        }

        return null;
    }
  
      public PageReference cancel(){
        //Obtenemos Describe Result del objeto oportunidad
          Schema.DescribeSObjectResult dsr = Opportunity.SObjectType.getDescribe();
          //Seteamos la URL de la Tab de oportunidad
          PageReference prRef = new PageReference('/' + dsr.getKeyPrefix());
          prRef.setRedirect(true);
          //Redirigimos a la tab de oportunidad
          return prRef;
      }
  
  }