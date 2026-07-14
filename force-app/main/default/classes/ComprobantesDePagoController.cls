/**
* @author Maximo Martinez
* @date 29/12/2015
* @description Controlador de la la Visual Force comprobantesDePago
* @description FL 2016-04-11 Agregado de filtros y ajustes de manejo de checks
*/
public with sharing class ComprobantesDePagoController {
    
    private final static Integer PAGE_SIZE = 200;

    private Set<Id> selectedComprobantesIds {get; set;}
    private Set<Id> processingComprobantesIds {get; set;}

    private String sortDirection = 'ASC';
    
    private String sortExp = 'Name';

    private String baseQuery {get; set;}

    private Date today;
    
    public Comprobante_de_Pago__c cpFilter {get; set;}
    
    private Date fechaRecepcionPago;

    private Date fechaCreacionPago;
    private DateTime fechaCreacionDesde;
    private DateTime fechaCreacionHasta;
    
    public List<ComprobanteDePago> comprobantes {get; set;}
    
    public ApexPages.StandardSetController stdCtrl {get; set;}
    public Boolean showBatchJobsStatus {get;set;}
    public String apexClassName {get;set;}

    //FL 2016-08-18 Dias de exclusion
    private String proceccesDay;

    //FL 2018-01-26 Agregado de filtro de obtentor
    public String selectedObtentor {get;set;}

    
    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Constructor
    */
    public ComprobantesDePagoController(){
        selectedComprobantesIds = new Set<Id>();
        processingComprobantesIds = new Set<Id>();
        today = Date.today();
        cpFilter = new Comprobante_de_Pago__c();
        stdCtrl = paginator;
        comprobantes = getComprobantesDePago();
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Variable que contiene el paginador
    */
    public ApexPages.StandardSetController paginator {
        get{
            //if(paginator == null){

                makeQuery();
    
                Database.QueryLocator queryLocator = Database.getQueryLocator(baseQuery);
    
                paginator = new ApexPages.StandardSetController(queryLocator);
                
                if(paginator.getResultSize() > 0){
                    
                    if(paginator.getResultSize() > PAGE_SIZE){
                        paginator.setPageSize(PAGE_SIZE);
                    }else{
                        paginator.setPageSize(paginator.getResultSize());
                    }
    
                }
            //}
            return paginator;
        }set;
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que se ejecuta cuando se aplica el filtro por ordenamiento
    */
    public PageReference applyFilter(){

        //selectedComprobantesIds.clear();
        selectedComprobantesIds = new Set<Id>();
        
        stdCtrl = paginator;

        comprobantes = null;
        
        comprobantes = getComprobantesDePago();

        return null;
        
    }
    
    private void controlaCheckeados(){
        ERPvs.ApexLogger.Debug('controlaCheckeados');
        for(ComprobanteDePago c: comprobantes){
            if(c.isSelected == true){
                selectedComprobantesIds.add(c.comprobante.Id);
            }else{
                selectedComprobantesIds.remove(c.comprobante.Id);
            }    
        }
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que retorna el field set Comprobante_de_Pago del Objeto Comprobante_de_Pago__c
    */
    public List<Schema.FieldSetMember> getFields(){
        return SObjectType.Comprobante_de_Pago__c.FieldSets.Comprobante_de_Pago.getFields();
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Variable y su get y set para generar la expression por la cual se ordena la busqueda
    */
    public String sortExpression{
        
        get{
            return sortExp;
        }
        
        set{
            //if the column is clicked on then switch between Ascending and Descending modes
            if (value == sortExp){
                sortDirection = (sortDirection == 'ASC')? 'DESC' : 'ASC';
            }else{
                sortDirection = 'ASC';
                sortExp = value;
            }   
        }
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Get de la Variable sortDirection
    */
    public String getSortDirection(){
        //if not column is selected 
        if (sortExpression == null || sortExpression == ''){
            return 'ASC';
        }else{
            return sortDirection;
        }
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Set de la Variable sortDirection
    */
    public void setSortDirection(String value){  
        sortDirection = value;
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo encargado de generar la Query que usa el paginador
    */
    private void makeQuery(){

        // Map que tiene las conversiones si es que es un REFERENCE
        Map<String,String> orderByConvert = new Map<String, String>();

        baseQuery = 'SELECT ';
        
        for(Schema.FieldSetMember f : getFields()) {
            
            baseQuery += f.getFieldPath() + ', ';

            if(String.valueOf(f.getType()) == 'REFERENCE'){
                orderByConvert.put(f.getFieldPath(),f.getFieldPath().replace('_c','_r.Name'));
            }

        }

        //FL 2016-07-10: Traigo las aplicaciones para controlar los vencimientos. En caso de no tener vencimientos, no muestro el CP
        baseQuery += '(SELECT Id, Name, Comprobante__c, Importe_Aplicar__c, Factura__c, Tipo_de_Cambio__c FROM Aplicaciones__r),';
        
        baseQuery += 'Id FROM Comprobante_de_Pago__c WHERE DAY_ONLY(CreatedDate) >= 2016-01-01 AND Obtentor_Destinatario__r.Factura_por_Cuenta_y_Orden__c = true AND Id NOT IN (SELECT Comprobante_de_Pago__c FROM ERPvs__Movimiento_Fondo__c) AND Saldo_del_Comprobante__c = 0';

        if(cpFilter != null){
            if(cpFilter.Cliente__c != null){
                baseQuery += ' AND Cliente__c = \'' + cpFilter.Cliente__c + '\'';
            }
            if(cpFilter.Fecha_de_Recepcion_de_Pago__c != null){
                fechaRecepcionPago = cpFilter.Fecha_de_Recepcion_de_Pago__c;
                baseQuery += ' AND Fecha_de_Recepcion_de_Pago__c = :fechaRecepcionPago';
            }
            //FL 2016-07-04 Usoc el campo Fecha_de_Confirmacion_del_Pago__c como filtro de creacion de CP
            if(cpFilter.Fecha_de_Confirmacion_del_Pago__c != null){
                fechaCreacionPago = cpFilter.Fecha_de_Confirmacion_del_Pago__c;
                fechaCreacionDesde = DateTime.newInstance(fechaCreacionPago.year(), fechaCreacionPago.month(), fechaCreacionPago.day(), 0, 0, 0);
                fechaCreacionHasta = DateTime.newInstance(fechaCreacionPago.year(), fechaCreacionPago.month(), fechaCreacionPago.day(), 23, 59, 59);
                baseQuery += ' AND CreatedDate >= :fechaCreacionDesde AND CreatedDate <= :fechaCreacionHasta';
            }
        }

        if(!processingComprobantesIds.isEmpty()){
            baseQuery += ' AND Id NOT IN :processingComprobantesIds';
        }

        //FL 2016-08-18 Dias de exclusion
        List<Parametros_ERP_y_CRM__c> parametrosERPYCRM = [SELECT No_controla_dias_exclusion_COB__c FROM Parametros_ERP_y_CRM__c ORDER BY LastModifiedDate DESC];
        if(!parametrosERPYCRM.isEmpty()){
            
            if(!parametrosERPYCRM.get(0).No_controla_dias_exclusion_COB__c){
                proceccesDay = UtilsAccount.getExclusionDay(Date.today());
                baseQuery += ' AND (Obtentor_Destinatario__r.Dias_de_Exclusion_de_Facturacion__c = null OR (Obtentor_Destinatario__r.Dias_de_Exclusion_de_Facturacion__c != null AND Obtentor_Destinatario__r.Dias_de_Exclusion_de_Facturacion__c EXCLUDES(:proceccesDay)))';
            }

        }

        //FL 2018-01-26 Agregado de filtro de obtentor
        if(String.isNotBlank(selectedObtentor)){
          baseQuery += ' AND Obtentor_Destinatario__c = :selectedObtentor';
        }

        if(orderByConvert.containsKey(sortExpression)){

            baseQuery += ' ORDER BY ' + orderByConvert.get(sortExpression)  + ' ' + sortDirection;

        }else{
    
            baseQuery += ' ORDER BY ' + sortExpression  + ' ' + sortDirection;
        }   

        baseQuery += ' LIMIT 10000';
        
        System.debug(LoggingLevel.DEBUG, baseQuery);
        

    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que devuelve la cantidad de registros seleccionados
    */
    public Integer getCountCheckedIds(){
        
        return  selectedComprobantesIds.size();
    
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que devuelve una lista de ComprobanteDePago
    */
    public List<ComprobanteDePago> getComprobantesDePago(){
        
        ERPvs.ApexLogger.Debug(LoggingLevel.WARN, 'getComprobantesDePago()');

        List<ComprobanteDePago> comprobantes = new List<ComprobanteDePago>();

        List<Comprobante_de_Pago__c> comprobantesPago = (List<Comprobante_de_Pago__c>) stdCtrl.getRecords();

        comprobantesPago = filterComprobantesSinVencimientos(comprobantesPago);
    
        for(Comprobante_de_Pago__c cp : comprobantesPago){

            ComprobanteDePago c = new ComprobanteDePago();

            c.outerClass = this;

            c.comprobante = cp;

            c.isSelected = selectedComprobantesIds.contains(c.comprobante.Id);
            
            comprobantes.add(c);
            
        }

        System.Debug(LoggingLevel.WARN, 'comprobantes: ' + comprobantes);

        return comprobantes;
 
    }


    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que retorna a la Tab de Comprobantes de Pago
    */
    public PageReference cancel(){
        //Obtenemos Describe Result del objeto Comprobante_de_Pago__c
        Schema.DescribeSObjectResult dsr = Comprobante_de_Pago__c.SObjectType.getDescribe();
        //Seteamos la URL de la Tab de Comprobante_de_Pago__c
        PageReference prRef = new PageReference('/' + dsr.getKeyPrefix());
        prRef.setRedirect(true);
        //Redirigimos a la tab de Comprobante_de_Pago__c
        return prRef;
    }


    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que genera movimientos de fondo
    */
    public PageReference generarMovimientos(){

        // Generamos los movimientos de fondo
        try {
        
            controlaCheckeados();
            /**
            UtilsMovimientoFondo.generateMovimientosDeFondeFromCP(selectedComprobantesIds);

            selectedComprobantesIds.clear();

            //ApexPages.addmessages(e);
            Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM,'Operación Exitosa'));
            
            stdCtrl = paginator;
            
            comprobantes = getComprobantesDePago();
            **/
            if(selectedComprobantesIds != null && !selectedComprobantesIds.isEmpty()){
                Database.executeBatch(new BatchApexGeneracionCobranzas(selectedComprobantesIds), 1);
                apexClassName = 'BatchApexGeneracionCobranzas';
                showBatchJobsStatus = true;
                processingComprobantesIds.addAll(selectedComprobantesIds);

                //selectedComprobantesIds.clear();
                selectedComprobantesIds = new Set<Id>();

                //ApexPages.addmessages(e);
                Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM,'Procesando Registros'));
                
                stdCtrl = paginator;
                
                comprobantes = getComprobantesDePago();
            } else {
                Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'Debe seleccionar por lo menos un registro'));
            }
        
        return null;

        }catch(Exception e){

            //ApexPages.addmessages(e);
            Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, e.getMessage()));

        }

        return null;
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que navega a la primera pagina del paginador
    */
    public PageReference firstPage(){
        System.Debug(LoggingLevel.WARN, 'firstPage');
        controlaCheckeados();
        stdCtrl.first();
        comprobantes = getComprobantesDePago();

        return null;
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que navega a la primera pagina del paginador
    */
    public PageReference lastPage(){
        System.Debug(LoggingLevel.WARN, 'lastPage');
        controlaCheckeados();
        stdCtrl.last();
        comprobantes = getComprobantesDePago();

        return null;
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que navega a la siguiente pagina del paginador
    */
    public PageReference next(){
        System.Debug(LoggingLevel.WARN, 'next');
        controlaCheckeados();
        stdCtrl.next();
        comprobantes = getComprobantesDePago();

        return null;
    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que navega a la siguiente pagina del paginador
    */
    public PageReference prev(){
        System.Debug(LoggingLevel.WARN, 'prev');
        controlaCheckeados();
        stdCtrl.previous();
        comprobantes = getComprobantesDePago();

        return null;
    }

    
    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que retorna true/false si el paginador tiene una pagina siguiente
    */
    public Boolean hasNext {
        get {
            return stdCtrl.getHasNext();
        }
        set;
    }


     /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que retorna true/false si el paginador tiene una pagina anterior
    */
    public Boolean hasPrevious {
        get {
            return stdCtrl.getHasPrevious();
        }
        set;
    }

    //FL 2016-04-11: Lista de clientes
    public List<SelectOption> getClientes(){

      List<SelectOption> clientes = new List<SelectOption>();
        
      clientes.add(new  SelectOption('', '--Ninguno--'));

      for(AggregateResult ag : [SELECT Cliente__r.Name clienteName, Cliente__c clienteId FROM Comprobante_de_Pago__c WHERE DAY_ONLY(CreatedDate) >= 2016-01-01 AND Obtentor_Destinatario__r.Factura_por_Cuenta_y_Orden__c = true AND Id NOT IN (SELECT Comprobante_de_Pago__c FROM ERPvs__Movimiento_Fondo__c) GROUP BY Cliente__r.Name, Cliente__c ORDER BY Cliente__r.Name ASC LIMIT 999]){

        //Por cada obtentor generamos una opcion en una lista de seleccion
            clientes.add(new  SelectOption((String)ag.get('clienteId'), (String)ag.get('clienteName')));
      
      }

      //Devolvemos los clientes
      return clientes;

    }

    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Inner Class para manejar los comprobantes de pago seleccionados
    */
    public class ComprobanteDePago {
        
        public ComprobantesDePagoController outerClass {get; set;}

        private Boolean isSelected {get; set;}

        public Boolean getIsSelected(){
            return isSelected;
        }

        public void setIsSelected(Boolean isSelected){
            this.isSelected = isSelected;
            if(isSelected){
                outerClass.selectedComprobantesIds.add(comprobante.Id);
            }else if(outerClass.selectedComprobantesIds.contains(comprobante.Id)){
                outerClass.selectedComprobantesIds.remove(comprobante.Id);
            }
        }

        public Comprobante_de_Pago__c comprobante {get; set;}

    }

    //FL 2016-07-10 Método para filtrar comprobantes sin vencimientos
    private List<Comprobante_de_Pago__c> filterComprobantesSinVencimientos(List<Comprobante_de_Pago__c> comprobantes){

        //Sets para realizar busqueda de vencimientos
        Set<String> letrasComprobantes = new Set<String>();
        Set<Integer> sucursalesComprobantes = new Set<Integer>();
        Set<Integer> numerosComprobantes = new Set<Integer>();
        Set<String> clientesComprobantes = new Set<String>();
        Set<String> aCuentaOrdenComprobantes = new Set<String>();
        Set<String> facturasIds = new Set<String>();
        Map<String, Set<String>> mapComprobanteVencimientos = new Map<String, Set<String>>();
        List<Comprobante_de_Pago__c> result = new List<Comprobante_de_Pago__c>();
        String key;

        System.debug(LoggingLevel.DEBUG, 'comprobantes: ' + comprobantes);

        String letra;
        String sucursal;
        String numero;
        for(Comprobante_de_Pago__c cp : comprobantes){

            clientesComprobantes.add(cp.Cliente__c);
            aCuentaOrdenComprobantes.add(cp.Obtentor_Destinatario__c);
            for(Aplicacion__c ap : cp.Aplicaciones__r){
                String[] comprobanteSplit = ap.Comprobante__c != null ? ap.Comprobante__c.split('-') : null;
                letra = null;
                sucursal = null;
                numero = null;
                if(comprobanteSplit != null){
                    try{
                        letra = comprobanteSplit.get(0);
                        letrasComprobantes.add(letra);
                    } catch (Exception e) {}
                    try{
                        sucursal = comprobanteSplit.get(1);
                        sucursalesComprobantes.add(Integer.valueOf(sucursal));
                    } catch (Exception e) {}
                    try{
                        numero = comprobanteSplit.get(2);
                        numerosComprobantes.add(Integer.valueOf(numero));
                    } catch (Exception e) {}
                }
                facturasIds.add(ap.Factura__c);

                if(!mapComprobanteVencimientos.containsKey(key)){
                    mapComprobanteVencimientos.put(cp.Id, new Set<String>());
                }
                key = '' + cp.Cliente__c + cp.Obtentor_Destinatario__c + letra + (sucursal != null ? String.valueOf(Integer.valueOf(sucursal)) : '0') + (numero != null ? String.valueOf(Integer.valueOf(numero)) : '0');
                mapComprobanteVencimientos.get(cp.Id).add(key);
            }

        }
        System.debug(LoggingLevel.DEBUG, 'mapComprobanteVencimientos: ' + mapComprobanteVencimientos);
        Set<String> setVencimientos = new Set<String>();
        for(ERPvs__Vencimientos__c v : [SELECT Id, ERPvs__Cuenta__c, ERPvs__A_cuenta_y_orden_de__c, ERPvs__Serie_Documento__c, ERPvs__Sucursal_Documento__c, ERPvs__Numero_Documento__c, ERPvs__Importe_MO__c, ERPvs__Importe_MN__c, ERPvs__Signo__c, ERPvs__Comprobante_Venta__c FROM ERPvs__Vencimientos__c 
                                                                                                                                                                                        WHERE ERPvs__Cuenta__c IN :clientesComprobantes AND 
                                                                                                                                                                                              ERPvs__A_cuenta_y_orden_de__c IN :aCuentaOrdenComprobantes AND 
                                                                                                                                                                                              ERPvs__Serie_Documento__c IN :letrasComprobantes AND 
                                                                                                                                                                                              ERPvs__Sucursal_Documento__c IN :sucursalesComprobantes AND
                                                                                                                                                                                              ERPvs__Numero_Documento__c IN :numerosComprobantes AND
                                                                                                                                                                                              ERPvs__Importe_MO__c > 0]){

            key = '' + v.ERPvs__Cuenta__c + v.ERPvs__A_cuenta_y_orden_de__c + v.ERPvs__Serie_Documento__c + v.ERPvs__Sucursal_Documento__c + v.ERPvs__Numero_Documento__c;
            setVencimientos.add(key);
        }
        System.debug(LoggingLevel.DEBUG, 'setVencimientos: ' + setVencimientos);
        Boolean tieneVencimientos = false;
        for(Comprobante_de_Pago__c cp : comprobantes){
            tieneVencimientos = false;
            if(mapComprobanteVencimientos.containsKey(cp.Id)){
                for(String keyAux : mapComprobanteVencimientos.get(cp.Id)){
                    tieneVencimientos = tieneVencimientos || setVencimientos.contains(keyAux);
                }
                System.debug(LoggingLevel.DEBUG, 'tieneVencimientos: ' + tieneVencimientos);
                if(tieneVencimientos){
                    result.add(cp);
                }
            }
        }

        return result;
    }

    public List<SelectOption> getObtentores(){

        List<SelectOption> obtentores = new List<SelectOption>();

        obtentores.add(new  SelectOption('', '--Ninguno--'));

        for(AggregateResult ag : [SELECT Obtentor_Destinatario__r.Name ObtentorName, Obtentor_Destinatario__r.Id ObtentorId FROM Comprobante_de_Pago__c WHERE DAY_ONLY(CreatedDate) >= 2016-01-01 AND Obtentor_Destinatario__r.Factura_por_Cuenta_y_Orden__c = true AND Id NOT IN (SELECT Comprobante_de_Pago__c FROM ERPvs__Movimiento_Fondo__c) GROUP BY Obtentor_Destinatario__r.Name, Obtentor_Destinatario__r.Id ORDER BY Obtentor_Destinatario__r.Name ASC LIMIT 1000]){

        //Por cada obtentor generamos una opcion en una lista de seleccion
            obtentores.add(new  SelectOption((String)ag.get('ObtentorId'), (String)ag.get('ObtentorName')));

        }

        //Devolvemos los obtentores
        return obtentores;

    }

}