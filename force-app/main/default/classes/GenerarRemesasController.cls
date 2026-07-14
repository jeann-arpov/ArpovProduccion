public with sharing class GenerarRemesasController {
    private final static Integer PAGE_SIZE = 200;

    private Set<Id> selectedAplicacionesIds {get; set;} 

    private Set<Id> inBatchTransaction {get; set;}

    private String proceccesDay {get; set;} 

    private String baseQuery {get; set;}

    public String selectedObtentor {get; set;}
    public ERPvs__Util_Formulario__c rangoFechaContable {get; set;}
    private Date selectedContableDateFrom;
    private Date selectedContableDateTo;
    public Aplicacion__c aplicacionFilter {get; set;}
    private String selectedCuenta;
    private String selectedCVComisiones;

    public Aplicacion__c ap {get; set;}

    public String nameApexClass {get; set;}

    private Date today;

    public List<Aplicacion> aplicaciones {get; set;}

    private transient BatchApexGeneracionComprobantesVentas b; 

    public Integer countCheckedIds {get; set;}

    public GenerarRemesasController(){
        ap = new Aplicacion__c();
        selectedAplicacionesIds = new Set<Id>();
        countCheckedIds = 0;
        inBatchTransaction = new Set<Id>();
        nameApexClass = 'BatchApexGenerarRemesas';
        today = Date.today();
        rangoFechaContable = new ERPvs__Util_Formulario__c();
        aplicacionFilter = new Aplicacion__c();
        
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

        for(AggregateResult ag : [SELECT Factura__r.Obtentor__r.Nombre_Obtentor__c ObtentorName, Factura__r.Obtentor__c ObtentorId FROM Aplicacion__c WHERE CreatedDate >= 2018-01-01T00:00:00Z AND Factura__c != null AND CV_Comisiones__c != null GROUP BY Factura__r.Obtentor__r.Nombre_Obtentor__c, Factura__r.Obtentor__c ORDER BY Factura__r.Obtentor__r.Nombre_Obtentor__c ASC LIMIT 1000]){

            //Por cada obtentor generamos una opcion en una lista de seleccion
            obtentores.add(new  SelectOption((String)ag.get('ObtentorId'), (String)ag.get('ObtentorName')));

        }

        //Devolvemos los obtentores
        return obtentores;

    }

    public List<SelectOption> getCVsComisiones(){

        List<SelectOption> options = new List<SelectOption>();

        options.add(new  SelectOption('', '--Ninguno--'));

        for(AggregateResult ag : [SELECT CV_Comisiones__c cvId, CV_Comisiones__r.Name cvName FROM Aplicacion__c WHERE CV_Comisiones__c != null GROUP BY CV_Comisiones__c, CV_Comisiones__r.Name ORDER BY CV_Comisiones__r.Name ASC LIMIT 1000]){

            options.add(new  SelectOption((String)ag.get('cvId'), (String)ag.get('cvName')));

        }

        //Devolvemos las opciones
        return options;

    }

    public Boolean getShowBatchJobsStatus(){
        return 0 < [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = :nameApexClass AND DAY_ONLY(CreatedDate) = :today ];
    }
    

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

        baseQuery += 'Forma_de_Pago__c, Id_Obtentor__c, Importe_Aplicar__c, Tipo_de_Cambio__c, Importe__c, DUP_Auditoria__c, Tipo_de_Comprobante__c, Comprobante__c, Cuenta_Originante__r.ERPvs__Activa__c, ';

        baseQuery += 'Id, Name FROM Aplicacion__c WHERE CV_Comisiones__c != null AND Liquido_Producto__c != null AND MOV_Remesa__c = null';     

        if(String.isNotBlank(selectedObtentor)){
            baseQuery += ' AND Factura__r.Obtentor__c = :selectedObtentor';
        }

        selectedContableDateFrom = rangoFechaContable.ERPvs__Fecha_Desde__c;
        if(selectedContableDateFrom != null){
            baseQuery += ' AND Comprobante_de_Pago__r.Fecha_Contable__c >= :selectedContableDateFrom';
        }
        selectedContableDateTo = rangoFechaContable.ERPvs__Fecha_Hasta__c;
        if(selectedContableDateTo != null){
            baseQuery += ' AND Comprobante_de_Pago__r.Fecha_Contable__c <= :selectedContableDateTo';
        }

        selectedCuenta = aplicacionFilter.Cuenta_Originante__c;
        if(selectedCuenta != null){
            baseQuery += ' AND Cuenta_Originante__c = :selectedCuenta';
        }

        selectedCVComisiones = aplicacionFilter.CV_Comisiones__c;
        if(selectedCVComisiones != null){
            baseQuery += ' AND CV_Comisiones__c = :selectedCVComisiones';
        }
       
        baseQuery += ' AND Id NOT IN :inBatchTransaction';

        baseQuery += ' LIMIT 10000';

        System.debug('baseQuery: ' + baseQuery);

    }

    public PageReference generarRemesas(){

        setSelected();

        try{

            // Si no hay elementos seleccionados indicamos esto
            if(selectedAplicacionesIds.isEmpty()){

                Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'No hay elementos seleccionados.'));

                return null;
            }

            System.debug('selectedAplicacionesIds: ' + selectedAplicacionesIds);

            // Enviamos a procesar por el batch
            BatchApexGenerarRemesas b = new BatchApexGenerarRemesas(selectedAplicacionesIds);

            Database.executebatch(b, BatchApexGenerarRemesas.BATCH_SIZE);

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

    
}