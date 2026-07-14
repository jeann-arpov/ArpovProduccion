public with sharing class GenerarCVComisionesController {
    private final static Integer PAGE_SIZE = 200;

    private Set<Id> selectedAplicacionesIds {get; set;} 

    private Set<Id> inBatchTransaction {get; set;}

    private String proceccesDay {get; set;} 

    private String baseQuery {get; set;}

    public String selectedObtentor {get; set;}

    public String selectedRazon {get; set;}

    public String tipoRegistro {get; set;}

    public String formaPago {get; set;}

    public ERPvs__Util_Formulario__c rangoFechaAplicacion {get; set;}

    public ERPvs__Util_Formulario__c rangoFechaContable {get; set;}

    public ERPvs__Util_Formulario__c rangoFechaPago {get; set;}

    public ERPvs__Util_Formulario__c rangoFechaAcreditado {get; set;}

    public Aplicacion__c ap {get; set;}

    public String nameApexClass {get; set;}

    private String selectedTipoRegistro;
    private String selectedFormaPago;
    private String selectedRazonFilter;
    private Date selectedAplicacionDateFrom;
    private Date selectedAplicacionDateTo;
    private Date selectedContableDateFrom;
    private Date selectedContableDateTo;
    private Date selectedPayDateFrom;
    private Date selectedPayDateTo;
    private Date selectedCreditDateFrom;
    private Date selectedCreditDateTo;

    private Date today;

    public List<Aplicacion> aplicaciones {get; set;}

    private transient BatchApexGeneracionComprobantesVentas b; 

    public Integer countCheckedIds {get; set;}

    public Boolean desaplicaciones {get; set;}

    public GenerarCVComisionesController(){
        ap = new Aplicacion__c();
        selectedAplicacionesIds = new Set<Id>();
        countCheckedIds = 0;
        inBatchTransaction = new Set<Id>();
        nameApexClass = 'BatchApexGenerarCVComisiones';
        today = Date.today();
        rangoFechaAplicacion = new ERPvs__Util_Formulario__c();
        rangoFechaContable = new ERPvs__Util_Formulario__c();
        rangoFechaPago = new ERPvs__Util_Formulario__c();
        rangoFechaAcreditado = new ERPvs__Util_Formulario__c();
        desaplicaciones = false;

        loadAplicaciones();
    }

    public ApexPages.StandardSetController aplicacionesController {
        get{
            if(aplicacionesController == null){

                makeQuery();

                Database.QueryLocator queryLocator = Database.getQueryLocator(baseQuery);

                aplicacionesController = new ApexPages.StandardSetController(queryLocator);

                if(aplicacionesController.getResultSize() > 0){

                    System.debug(LoggingLevel.DEBUG, aplicacionesController.getResultSize());

                    if(aplicacionesController.getResultSize() > PAGE_SIZE){
                        aplicacionesController.setPageSize(PAGE_SIZE);
                    }   else    {
                        aplicacionesController.setPageSize(aplicacionesController.getResultSize());
                    }

                }
            }
            return aplicacionesController;
        }
        set;
    }

    public List<SelectOption> getObtentores(){

        List<SelectOption> obtentores = new List<SelectOption>();

        obtentores.add(new  SelectOption('', '--Ninguno--'));

        for(AggregateResult ag : [SELECT Factura__r.Obtentor__r.Nombre_Obtentor__c ObtentorName, Factura__r.Obtentor__c ObtentorId FROM Aplicacion__c WHERE CreatedDate >= 2018-01-01T00:00:00Z AND Factura__c != null GROUP BY Factura__r.Obtentor__r.Nombre_Obtentor__c, Factura__r.Obtentor__c ORDER BY Factura__r.Obtentor__r.Nombre_Obtentor__c ASC LIMIT 1000]){

            //Por cada obtentor generamos una opcion en una lista de seleccion
            obtentores.add(new  SelectOption((String)ag.get('ObtentorId'), (String)ag.get('ObtentorName')));

        }

        //Devolvemos los obtentores
        return obtentores;

    }

    public List<SelectOption> getTiposRegistro(){

        List<SelectOption> options = new List<SelectOption>();

        options.add(new  SelectOption('', '--Todos--'));
        options.add(new  SelectOption('DUP', 'DUP'));
        options.add(new  SelectOption('Auditoría', 'Auditoría'));

        return options;

    }

    public Boolean getShowBatchJobsStatus(){
        return 0 < [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = :nameApexClass AND DAY_ONLY(CreatedDate) = :today ];
    }
    /*
    public List<SelectOption> getRazonSocial(){

        List<SelectOption> razonSocial = new List<SelectOption>();

        razonSocial.add(new  SelectOption('', '--Ninguno--'));

        for(AggregateResult ag : [SELECT Cuenta_Originante__r.Name RazonName, Cuenta_Originante__r.Id RazonId FROM Aplicacion__c WHERE CreatedDate >= 2018-01-01T00:00:00Z AND Cuenta_Originante__c != null AND CV_Comisiones__c = null GROUP BY Cuenta_Originante__r.Name, Cuenta_Originante__r.Id ORDER BY Cuenta_Originante__r.Name ASC LIMIT 500]){

            //Por cada obtentor generamos una opcion en una lista de seleccion
            razonSocial.add(new SelectOption((String)ag.get('RazonId'), (String)ag.get('RazonName')));

        }

        //Devolvemos los razonSocial
        return razonSocial;

    }
    */

    public PageReference applyFilter(){

        // Limpiamos los set que contienen los datos seleccionados
        //selectedAplicacionesIds.clear();
        //FL 2019-08-20 AF pidió que no se limpie la búsqueda para seguir agregando a la selección realizada. Para limpiar esto, hay que salir y volver a entrar en la pantalla
        //selectedAplicacionesIds = new Set<Id>();
        setSelected();

        aplicacionesController = null;

        aplicaciones = null;

        loadAplicaciones();

        return null;

    }

    private void setSelected(){

        if(aplicaciones != null){

            System.debug('aplicaciones.size: ' + aplicaciones.size());

            for(Aplicacion ap : aplicaciones){

                System.debug('ap: ' + ap);
                System.debug('ap.isSelected: ' + ap.isSelected);

                if(ap.isSelected){
                    selectedAplicacionesIds.add(ap.aplicacion.id);
                }else{
                    selectedAplicacionesIds.remove(ap.aplicacion.id);
                }

            }

        }

        countCheckedIds = selectedAplicacionesIds.size();
    }

    private void loadAplicaciones(){
    
        aplicaciones = new List<Aplicacion>();

        for(Aplicacion__c tr : (List<Aplicacion__c>) aplicacionesController.getRecords()){

            Aplicacion ap = new Aplicacion();

            ap.aplicacion = tr;

            ap.isSelected = selectedAplicacionesIds.contains(ap.aplicacion.Id);

            ap.isProcessing = inBatchTransaction.contains(ap.aplicacion.Id);

            aplicaciones.add(ap);

        }

    }

    public class Aplicacion {

        public Boolean isSelected {get; set;}

        public Boolean isProcessing {get; set;}

        public Aplicacion__c aplicacion {get; set;}

        public Boolean getHasError(){
            Boolean result = false;

            if(!aplicacion.Cuenta_Originante__r.ERPvs__Activa__c){
                result = true;
            } 

            return result;
        }

        public String getError(){
            String result = '';

            if(!aplicacion.Cuenta_Originante__r.ERPvs__Activa__c){
                result += 'La cuenta del cliente no está activa' + '\n';
            } 

            return result;
        }

    }


    //Navigate to first Page
    public PageReference firstPage(){
        setSelected();
        aplicacionesController.first();
        loadAplicaciones();

        return null;
    }

    //Navigate to last Page
    public PageReference lastPage(){
        setSelected();
        aplicacionesController.last();
        loadAplicaciones();

        return null;
    }

    //Navigate to Next page
    public PageReference next(){
        setSelected();
        aplicacionesController.next();
        loadAplicaciones();

        return null;
    }

    //Check if hash next
    public Boolean hasNext {
        get {
        return aplicacionesController.getHasNext();
        }
        set;
    }


    // indicates whether there are more records before the current page set.
    public Boolean hasPrevious {
        get {
        return aplicacionesController.getHasPrevious();
        }
        set;
    }

    //Navigate to Prev Page
    public PageReference prev(){
        setSelected();
        aplicacionesController.previous();
        loadAplicaciones();

        return null;
    }


    /**
    * @description Metodo encargado de generar la Query que usa el paginador
    */
    private void makeQuery(){

        baseQuery = 'SELECT ';

        baseQuery += 'CreatedDate, Factura__r.Type, Factura__r.Transaccion__c, Factura__r.Campania_Transaccion__c, Obtentor_Nombre__c, Cuenta_Originante__c, ';

        baseQuery += 'Id, Name, Cuenta_Originante__r.ERPvs__Activa__c, Estado_ERP__c FROM Aplicacion__c WHERE CreatedDate >= 2018-01-01T00:00:00Z AND Cuenta_Originante__r.Estado__c = \'Activo\' AND Factura__c != null AND Comisionable__c = true AND (Cuenta_y_Orden__c = false OR (Cuenta_y_Orden__c = true AND Estado_ERP__c = \'PROCESADO\'))';     

        if(String.isNotBlank(selectedObtentor)){
            baseQuery += ' AND Factura__r.Obtentor__c = :selectedObtentor';
        }

        if(String.isNotEmpty(selectedRazon)){
            selectedRazonFilter = '%' + selectedRazon + '%';
            baseQuery += ' AND Cuenta_Originante__r.Name LIKE :selectedRazonFilter';
        }

        selectedTipoRegistro = tipoRegistro;
        if(String.isNotEmpty(selectedTipoRegistro)){
            baseQuery += ' AND Factura__r.Type = :selectedTipoRegistro';
        }

        selectedFormaPago = formaPago;
        if(String.isNotEmpty(selectedFormaPago)){
            baseQuery += ' AND Forma_de_Pago__c = :selectedFormaPago';
        }

        selectedPayDateFrom = rangoFechaPago.ERPvs__Fecha_Desde__c;
        if(selectedPayDateFrom != null){
            baseQuery += ' AND Valor_Aplicado__r.Fecha_de_Pago__c >= :selectedPayDateFrom';
        }
        selectedPayDateTo = rangoFechaPago.ERPvs__Fecha_Hasta__c;
        if(selectedPayDateTo != null){
            baseQuery += ' AND Valor_Aplicado__r.Fecha_de_Pago__c <= :selectedPayDateTo';
        }

        selectedContableDateFrom = rangoFechaContable.ERPvs__Fecha_Desde__c;
        if(selectedContableDateFrom != null){
            baseQuery += ' AND Comprobante_de_Pago__r.Fecha_Contable__c >= :selectedContableDateFrom';
        }
        selectedContableDateTo = rangoFechaContable.ERPvs__Fecha_Hasta__c;
        if(selectedContableDateTo != null){
            baseQuery += ' AND Comprobante_de_Pago__r.Fecha_Contable__c <= :selectedContableDateTo';
        }

        selectedAplicacionDateFrom = rangoFechaAplicacion.ERPvs__Fecha_Desde__c;
        selectedAplicacionDateTo = rangoFechaAplicacion.ERPvs__Fecha_Hasta__c;
        selectedCreditDateFrom = rangoFechaAcreditado.ERPvs__Fecha_Desde__c;
        selectedCreditDateTo = rangoFechaAcreditado.ERPvs__Fecha_Hasta__c;

        if(selectedAplicacionDateFrom != null){
            baseQuery += ' AND Fecha_de_Aplicacion__c >= :selectedAplicacionDateFrom';
        }
        
        if(selectedAplicacionDateTo != null){
            baseQuery += ' AND Fecha_de_Aplicacion__c <= :selectedAplicacionDateTo';
        }

        if(selectedCreditDateFrom != null){
            baseQuery += ' AND Valor_Aplicado__r.Fecha_Acreditado__c >= :selectedCreditDateFrom';
        } 
        
        if(selectedCreditDateTo != null){
            baseQuery += ' AND Valor_Aplicado__r.Fecha_Acreditado__c <= :selectedCreditDateTo';
        } 
        // 2019-12-02 Denise pidió que ahora todos los filtros sean con AND
        /*
        if(selectedCreditDateFrom == null && selectedCreditDateTo == null){
            if(selectedCreatedDateFrom != null){
                baseQuery += ' AND CreatedDate >= :selectedCreatedDateFrom';
            }
            
            if(selectedCreatedDateTo != null){
                baseQuery += ' AND CreatedDate <= :selectedCreatedDateTo';
            }

            baseQuery += ' AND Valor_Aplicado__r.Fecha_Acreditado__c = null';
        } else {

            if(selectedCreatedDateFrom != null && selectedCreatedDateTo != null){
                baseQuery += ' AND ((CreatedDate >= :selectedCreatedDateFrom AND CreatedDate <= :selectedCreatedDateTo) OR';
            } else if(selectedCreatedDateFrom != null && selectedCreatedDateTo == null){
                baseQuery += ' AND (CreatedDate >= :selectedCreatedDateFrom OR';
            } else if(selectedCreatedDateFrom == null && selectedCreatedDateTo != null){
                baseQuery += ' AND (CreatedDate <= :selectedCreatedDateTo OR';
            } else {
                baseQuery += ' AND';
            }

            if(selectedCreditDateFrom != null && selectedCreditDateTo == null){
                baseQuery += ' Valor_Aplicado__r.Fecha_Acreditado__c >= :selectedCreditDateFrom'  + (selectedCreatedDateFrom != null || selectedCreatedDateTo != null ? ')' : '');
            } else if(selectedCreditDateFrom == null && selectedCreditDateTo != null){
                baseQuery += ' Valor_Aplicado__r.Fecha_Acreditado__c <= :selectedCreditDateTo'  + (selectedCreatedDateFrom != null || selectedCreatedDateTo != null ? ')' : '');
            } else if(selectedCreditDateFrom != null && selectedCreditDateTo != null){
                baseQuery += ' (Valor_Aplicado__r.Fecha_Acreditado__c >= :selectedCreditDateFrom AND Valor_Aplicado__r.Fecha_Acreditado__c <= :selectedCreditDateTo)'  + (selectedCreatedDateFrom != null || selectedCreatedDateTo != null ? ')' : '');
            }
        }
        */
        if(desaplicaciones){
            baseQuery += ' AND CV_Comisiones__c = null AND Importe__c < 0';
        } else {
            baseQuery += ' AND CV_Comisiones__c = null AND Importe__c > 0';
        }

        baseQuery += ' AND Id NOT IN :inBatchTransaction';

        baseQuery += ' LIMIT 10000';

        System.debug('baseQuery: ' + baseQuery);

    }

    public PageReference facturar(){

        setSelected();

        try{

            // Si no hay elementos seleccionados indicamos esto
            if(selectedAplicacionesIds.isEmpty()){

                Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'No hay elementos seleccionados.'));

                return null;
            }

            System.debug('selectedAplicacionesIds: ' + selectedAplicacionesIds);

            // Enviamos a procesar por el batch
            BatchApexGenerarCVComisiones b = new BatchApexGenerarCVComisiones(selectedAplicacionesIds, desaplicaciones);

            Database.executebatch(b, BatchApexGenerarCVComisiones.BATCH_SIZE);

            inBatchTransaction.addAll(selectedAplicacionesIds);

            selectedAplicacionesIds = new Set<Id>();

            countCheckedIds = 0;

            aplicacionesController = null;

            loadAplicaciones();

            //ApexPages.addmessages(e);
            Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM,'Operación Exitosa'));

        }catch(Exception e){

            //ApexPages.addmessages(e);
            Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, e.getMessage()));

        }

    return null;

    }

    public PageReference cancel(){
        //Obtenemos Describe Result del objeto ventas
        Schema.DescribeSObjectResult dsr = Aplicacion__c.SObjectType.getDescribe();
        //Seteamos la URL de la Tab de ventas
        PageReference prRef = new PageReference('/' + dsr.getKeyPrefix());
        prRef.setRedirect(true);
        //Redirigimos a la tab de ventas
        return prRef;
    }

    public List<SelectOption> getFormasPago() {

        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('','--Todos--'));

        Schema.DescribeFieldResult fieldResult = Valor__c.Forma_de_Pago__c.getDescribe();

        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();

        for(Schema.PicklistEntry pickListVal : ple){

            options.add(new SelectOption(pickListVal.getLabel(), pickListVal.getLabel()));
        
        }    

        return options;
    }
}