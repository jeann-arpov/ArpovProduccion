/**
* @author Maximo Martinez
* @date 17/12/2015
* @description Controlador de la la Visual Force TransaccionesParaFactura
*/
public with sharing class TransaccionesParaFacturarController {

  private final static Integer PAGE_SIZE = 200;

  private Set<Id> selectedTransaccionesIds {get; set;} 

    private Set<Id> inBatchTransaction {get; set;}

  private String proceccesDay {get; set;} 

  private String baseQuery {get; set;}

  public String selectedObtentor {get; set;}

  public String selectedRazon {get; set;}

    public Transaccion__c t {get; set;}

    public String nameApexClass {get; set;}

    private Date selectedDate;

    private Date today;

    public List<Transaccion> transacciones {get; set;}

  private transient BatchApexGeneracionComprobantesVentas b; 

    public Integer countCheckedIds {get; set;}

    public List<Schema.FieldSetMember> fieldsTransacciones {get; set;}

  public TransaccionesParaFacturarController(){
        fieldsTransacciones = SObjectType.Transaccion__c.FieldSets.Transacciones_Para_Facturar.getFields();
        t = new Transaccion__c();
    proceccesDay = UtilsAccount.getExclusionDay(Date.today());
    selectedTransaccionesIds = new Set<Id>();
        countCheckedIds = 0;
        inBatchTransaction = new Set<Id>();
        nameApexClass = 'BatchApexGeneracionComprobantesVentas';
        today = Date.today();
        loadTransacciones();
  }

  public ApexPages.StandardSetController transaccionesController {
        get{
            if(transaccionesController == null){

                makeQuery();

                Database.QueryLocator queryLocator = Database.getQueryLocator(baseQuery);

                transaccionesController = new ApexPages.StandardSetController(queryLocator);
                
                if(transaccionesController.getResultSize() > 0){
                    
                    System.debug(LoggingLevel.DEBUG, transaccionesController.getResultSize());

                    if(transaccionesController.getResultSize() > PAGE_SIZE){
                        transaccionesController.setPageSize(PAGE_SIZE);
                    }else{
                        transaccionesController.setPageSize(transaccionesController.getResultSize());
                    }

                }
            }
            return transaccionesController;
        }set;
    }

    public List<SelectOption> getObtentores(){

      List<SelectOption> obtentores = new List<SelectOption>();
        
        obtentores.add(new  SelectOption('', '--Ninguno--'));

      for(AggregateResult ag : [SELECT Obtentor__r.Name ObtentorName, Obtentor__r.Id ObtentorId FROM Transaccion__c WHERE ((RecordType.DeveloperName = 'Auditorias' AND Z9_Items_Auditoria_Facturar__c > 0 AND Estado__c = 'Completa') OR (RecordType.DeveloperName = 'DUP' AND Z9_Items_Dup_Facturar__c > 0 AND ((Estado__c = 'Respondida' OR Estado__c = 'Respondida Parcialmente') AND (Respondida_via_Minisitio__c = false OR (Respondida_via_Minisitio__c = true AND Resultado_Validacion_Analista__c = 'Positiva') ) ) ) ) AND Z9_Cambio__c = true AND Obtentor__r.Dias_de_Exclusion_de_Facturacion__c EXCLUDES(:proceccesDay) AND Obtentor__r.Factura_por_Cuenta_y_Orden__c = true AND Nombre_de_la_cuenta__r.Estado__c = 'Activo' AND Tiene_CV__c = false AND Factura__c != null GROUP BY Obtentor__r.Name, Obtentor__r.Id ORDER BY Obtentor__r.Name ASC LIMIT 1000]){

        //Por cada obtentor generamos una opcion en una lista de seleccion
            obtentores.add(new  SelectOption((String)ag.get('ObtentorId'), (String)ag.get('ObtentorName')));
      
      }

      //Devolvemos los obtentores
        return obtentores;

    }

    public Boolean getShowBatchJobsStatus(){
        return 0 < [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = :nameApexClass AND DAY_ONLY(CreatedDate) = :today ];
    }

    public List<SelectOption> getRazonSocial(){

      List<SelectOption> razonSocial = new List<SelectOption>();
        
        razonSocial.add(new  SelectOption('', '--Ninguno--'));

      for(AggregateResult ag : [SELECT Nombre_de_la_cuenta__r.Name RazonName, Nombre_de_la_cuenta__r.Id RazonId FROM Transaccion__c WHERE ((RecordType.DeveloperName = 'Auditorias' AND Z9_Items_Auditoria_Facturar__c > 0 AND Estado__c = 'Completa') OR (RecordType.DeveloperName = 'DUP' AND Z9_Items_Dup_Facturar__c > 0 AND ((Estado__c = 'Respondida' OR Estado__c = 'Respondida Parcialmente') AND (Respondida_via_Minisitio__c = false OR (Respondida_via_Minisitio__c = true AND Resultado_Validacion_Analista__c = 'Positiva') ) ) ) ) AND Z9_Cambio__c = true AND Obtentor__r.Dias_de_Exclusion_de_Facturacion__c EXCLUDES(:proceccesDay) AND Obtentor__r.Factura_por_Cuenta_y_Orden__c = true AND Nombre_de_la_cuenta__r.Estado__c = 'Activo' AND Tiene_CV__c = false AND Factura__c != null GROUP BY Nombre_de_la_cuenta__r.Name, Nombre_de_la_cuenta__r.Id ORDER BY Nombre_de_la_cuenta__r.Name ASC LIMIT 1000]){

        //Por cada obtentor generamos una opcion en una lista de seleccion
            razonSocial.add(new  SelectOption((String)ag.get('RazonId'), (String)ag.get('RazonName')));
      
      }

      //Devolvemos los razonSocial
        return razonSocial;

    }


    public PageReference applyFilter(){

        // Limpiamos los set que contienen los datos seleccionados
        //selectedTransaccionesIds.clear();
        selectedTransaccionesIds = new Set<Id>();

        transaccionesController = null;

        transacciones = null;

        loadTransacciones();

        return null;

    }

    private void setSelected(){

        if(transacciones != null){

            System.debug('transacciones.size: ' + transacciones.size());

            for(Transaccion t : transacciones){

                System.debug('t: ' + t);
                System.debug('t.isSelected: ' + t.isSelected);

                if(t.isSelected){
                    selectedTransaccionesIds.add(t.transaccion.id);
                }else{
                    selectedTransaccionesIds.remove(t.transaccion.id);
                }

            }

        }

        countCheckedIds = selectedTransaccionesIds.size();
    }

    private void loadTransacciones(){
        /**
        if(transacciones == null){
            transacciones = new List<Transaccion>();
        }else{
            transacciones.clear();
        }
        **/
        transacciones = new List<Transaccion>();

        for(Transaccion__c tr : (List<Transaccion__c>) transaccionesController.getRecords()){

            Transaccion t = new Transaccion();

            t.transaccion = tr;

            t.isSelected = selectedTransaccionesIds.contains(t.transaccion.Id);

            t.isProcessing = inBatchTransaction.contains(t.transaccion.Id);
            
            transacciones.add(t);
            
        }

    }

  public class Transaccion {

        public Boolean isSelected {get; set;}

        public Boolean isProcessing {get; set;}

        public Transaccion__c transaccion {get; set;}

        public Boolean getHasError(){
            Boolean result = false;

            if(!transaccion.Nombre_de_la_cuenta__r.ERPvs__Activa__c){
                result = true;
            } else {
                for(Item_de_DUP__c item : transaccion.Item_de_DUP__r){
                    if(item.Producto__r.ERPvs_Producto__c == null){
                        result = true;
                        break;
                    }
                }
            }

            return result;
        }

        public String getError(){
            String result = '';

            if(!transaccion.Nombre_de_la_cuenta__r.ERPvs__Activa__c){
                result += 'La cuenta del cliente no está activa' + '\n';
            } else {
                for(Item_de_DUP__c item : transaccion.Item_de_DUP__r){
                    if(item.Producto__r.ERPvs_Producto__c == null){
                        result += 'El producto ' + item.Producto__r.Name + ' no tiene producto asociado en el ERP.\n';
                    }
                }
            }

            return result;
        }

    }


    //Navigate to first Page
    public PageReference firstPage(){
        setSelected();
        transaccionesController.first();
        loadTransacciones();

        return null;
    }

    //Navigate to last Page
    public PageReference lastPage(){
        setSelected();
        transaccionesController.last();
        loadTransacciones();

        return null;
    }

    //Navigate to Next page
    public PageReference next(){
        setSelected();
        transaccionesController.next();
        loadTransacciones();

        return null;
    }

    //Check if hash next
    public Boolean hasNext {
        get {
            return transaccionesController.getHasNext();
        }
        set;
    }


    // indicates whether there are more records before the current page set.
    public Boolean hasPrevious {
        get {
            return transaccionesController.getHasPrevious();
        }
        set;
    }

    //Navigate to Prev Page
    public PageReference prev(){
        setSelected();
        transaccionesController.previous();
        loadTransacciones();

        return null;
    }


    /**
    * @description Metodo encargado de generar la Query que usa el paginador
    */
    private void makeQuery(){
        
        baseQuery = 'SELECT ';
        
        for(Schema.FieldSetMember f : fieldsTransacciones) {
            baseQuery += f.getFieldPath() + ', ';
        }

        baseQuery += 'Id, Nombre_de_la_cuenta__r.ERPvs__Activa__c, (SELECT Id, Name, Producto__r.Name, Producto__r.ERPvs_Producto__c FROM Item_de_DUP__r) FROM Transaccion__c WHERE ((RecordType.DeveloperName = \'Auditorias\' AND Z9_Items_Auditoria_Facturar__c > 0 AND Estado__c = \'Completa\') OR (RecordType.DeveloperName = \'DUP\' AND Z9_Items_Dup_Facturar__c > 0 AND ((Estado__c = \'Respondida\' OR Estado__c = \'Respondida Parcialmente\') AND (Respondida_via_Minisitio__c = false OR (Respondida_via_Minisitio__c = true AND Resultado_Validacion_Analista__c = \'Positiva\') ) ) ) ) AND Z9_Cambio__c = true AND Obtentor__r.Dias_de_Exclusion_de_Facturacion__c EXCLUDES(:proceccesDay) AND Obtentor__r.Factura_por_Cuenta_y_Orden__c = true AND Nombre_de_la_cuenta__r.Estado__c = \'Activo\' AND Tiene_CV__c = false AND No_Facturar__c = false AND Factura__c != null AND Subestado__c IN (\'POSITIVA\',\'NEGATIVA\')';     

        if(String.isNotBlank(selectedObtentor)){
          baseQuery += ' AND Obtentor__c = :selectedObtentor';
        }

        if(String.isNotEmpty(selectedRazon)){
          baseQuery += ' AND Nombre_de_la_cuenta__c = :selectedRazon';
        }

        if(t.Fecha_de_Respuesta__c != null){
            selectedDate = t.Fecha_de_Respuesta__c;
            baseQuery += ' AND Fecha_de_Respuesta__c = :selectedDate';
        }

        baseQuery += ' AND Id NOT IN :inBatchTransaction';

        //baseQuery += ' AND Id NOT IN (SELECT Transaccion__c FROM ERPvs__Comprobante_Venta__c)';

        baseQuery += ' LIMIT 10000';
   
    }

    public PageReference facturar(){
      
        setSelected();

        try{

            // Si no hay elementos seleccionados indicamos esto
            if(selectedTransaccionesIds.isEmpty()){
                
                Apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'No hay elementos seleccionados.'));
                
                return null;
            }

            System.debug('selectedTransaccionesIds: ' + selectedTransaccionesIds);

            // Enviamos a procesar por el batch
            BatchApexGeneracionComprobantesVentas b = new BatchApexGeneracionComprobantesVentas(selectedTransaccionesIds);

            Database.executebatch(b, BatchApexGeneracionComprobantesVentas.BATCH_SIZE);
        
            inBatchTransaction.addAll(selectedTransaccionesIds);

            selectedTransaccionesIds = new Set<Id>();

            countCheckedIds = 0;

            transaccionesController = null;

            loadTransacciones();

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
        Schema.DescribeSObjectResult dsr = Transaccion__c.SObjectType.getDescribe();
        //Seteamos la URL de la Tab de ventas
        PageReference prRef = new PageReference('/' + dsr.getKeyPrefix());
        prRef.setRedirect(true);
        //Redirigimos a la tab de ventas
        return prRef;
    }

}