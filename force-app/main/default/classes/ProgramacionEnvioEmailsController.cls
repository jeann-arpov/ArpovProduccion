/**
* @author Maximo Martinez
* @date 28/05/2014
* @description Controlador de la la Visual Force ProgramacionEnvioEmails
*/
public with sharing class ProgramacionEnvioEmailsController{

    private Integer PAGE_SIZE;
    
    private Integer EMAIL_SEND_LIMIT;

    private String baseQuery {get; set;}
    
    public Lote__c lote {get; set;}
    
    public Set<String> selectedRemesasIds {get; set;}
    
    public Set<String> selectedContactosIds {get; set;} 

    public String contextItem{get;set;}
    
    public String selectedZona {get; set;}

    public String selectedEstado {get; set;}
    
    public Contacto_Remesa__c contactoRemesa {get; set;}
    
    public ApexPages.StandardSetController contactosRemesaSetController {
        get{
            if(contactosRemesaSetController == null){

                makeQuery();

                Database.QueryLocator queryLocator = Database.getQueryLocator(baseQuery);

                contactosRemesaSetController = new ApexPages.StandardSetController(queryLocator);
                
                if(contactosRemesaSetController.getResultSize() > 0){
                    
                    if(contactosRemesaSetController.getResultSize() > PAGE_SIZE){
                        contactosRemesaSetController.setPageSize(PAGE_SIZE);
                    }else{
                        contactosRemesaSetController.setPageSize(contactosRemesaSetController.getResultSize());
                    }

                }
            }
            return contactosRemesaSetController;
        }set;
    }
    
    /**
    * @description Contructor
    * @param controller Instancia del Controlador Standard de la Visual Force
    */
    public ProgramacionEnvioEmailsController(ApexPages.StandardController controller){
    
        lote = (Lote__c)controller.getRecord();
        
        //Llamamos al metodo encargardo de la inicializaciones
        init();
    }
    
    /**
    * @description Metodo encargado de la inicializaciones
    */
    public void init(){

        //Seteamos el set que contendra los ids seleccionados
        selectedRemesasIds = new Set<String>();
        
        // Seteamos el set que contendra los ids de los contactos remesas seleccionados
        selectedContactosIds = new Set<String>();

        //Instanciamos un remesa usada de plantilla
        contactoRemesa = new Contacto_Remesa__c();
        
        // Levantamos el setup de la pagina
        ProgramacionEnvioEmailsSetup__c setup = ProgramacionEnvioEmailsSetup__c.getOrgDefaults();

        PAGE_SIZE = (setup.RowsPerPage__c!=null)?setup.RowsPerPage__c.intValue():0;

        EMAIL_SEND_LIMIT = (setup.EmailSendLimit__c!=null)?setup.EmailSendLimit__c.intValue():0;

    }
    
    /**
    * @description Metodo encargado de generar la Query que usa el paginador
    */
    private void makeQuery(){
        
        baseQuery = 'SELECT ';
        
        for(Schema.FieldSetMember f : getFieldsContactosRemesas()) {
            baseQuery += f.getFieldPath() + ', ';
        }

        baseQuery += ' Id FROM Contacto_Remesa__c WHERE Remesa__r.RecordType.DeveloperName = \'Correo_Electronico\'';

        if(String.isNotEmpty(selectedZona)){
            baseQuery += ' AND Remesa__r.Zona_Bolsa_de_Cereales__c = '+'\''+selectedZona+'\'';
        }

        if(String.isNotEmpty(selectedEstado)){
            baseQuery += ' AND Estado__c = ' + '\'' + selectedEstado + '\'';
        }

        baseQuery += ' AND Remesa__r.Lote__c = '+'\''+lote.Id+'\'';

        baseQuery += ' LIMIT 10000';

        System.debug(LoggingLevel.WARN, baseQuery);
        
    }

    /**
    * @description Metodo encargado de retornar el limite de emails disponibles
    */
    public Integer getEmailSendLimit(){
        return EMAIL_SEND_LIMIT;
    }

    /**
    * @description Metodo encargado de devolver los campos del fieldset Lista_Remesas_Programacion_Envio_Emails del objeto Remesa__c
    */
    public List<Schema.FieldSetMember> getFieldsContactosRemesas() {
        return SObjectType.Contacto_Remesa__c.FieldSets.Lista_Contactos_Remesas_Programacion_Env.getFields();
    }

    /**
    * @description Metodo encargado de devolver los valores de los estado de una remesa (no todos)
    */
    public List<SelectOption> getEstados(){
    
        //Lista de opciones
        List<SelectOption> options = new List<SelectOption>();

        options.add(new  SelectOption('', '--Ninguno--'));

        //Agregamos la opciones que necesitamos
        options.add(new SelectOption('Pendiente', 'Pendientes'));

        options.add(new SelectOption('Programado', 'Programadas'));

        options.add(new SelectOption('Enviado', 'Enviadas'));

        options.add(new SelectOption('Error', 'Error'));
    
        return options;
    }
    
    
    /**
    * @description Metodo encargado de devolver las Zona_Bolsa_de_Cereales__c para las remesas cuyo  Modo_de_Envio__c sea Correo Electrónico
    */
    public List<SelectOption> getZonas(){
        
        //Lista de zonas
        List<SelectOption> zonas = new List<SelectOption>();
        
        zonas.add(new  SelectOption('', '--Ninguno--'));
        
        //Obtenemos todos las zonas
        for(AggregateResult ag : [SELECT Productor__r.Zona_Productiva__c ZonaProductiva, COUNT(Id) FROM Remesa__c WHERE Lote__c = :lote.Id AND Modo_de_Envio__c = 'Correo Electrónico' AND Estado__c != 'Enviado' AND Productor__r.Zona_Productiva__c != null GROUP BY Productor__r.Zona_Productiva__c ORDER BY Productor__r.Zona_Productiva__c ASC]){
            
            //Por cada obtentor generamos una opcion en una lista de seleccion
            zonas.add(new  SelectOption((String)ag.get('ZonaProductiva'), (String)ag.get('ZonaProductiva')));
        
        }        
        
        //Devolvemos los obtentores
        return zonas;
        
    }
    
    public Integer getCountCheckedIds(){
        
        return  selectedContactosIds.size();
    
    }
    
    
    public void applyFilter(){

        contactosRemesaSetController = null;

        // Limpiamos los set que contienen los datos seleccionados
        selectedContactosIds.clear();
                
    }
    
    public PageReference cancel(){
        
        PageReference prRef = new PageReference('/' + lote.Id);
        prRef.setRedirect(true);
        return prRef;
        
    }

    public PageReference desprogramar(){

        //Variable que contendra el mensaje a mostrar 
        ApexPages.Message msg = null;

        //Lista que contendra las remesas a actualizar
        List<Contacto_Remesa__c> toUpdate = new List<Contacto_Remesa__c>();
        
        //Obtenemos las remesas seleccionadas        
        for(Contacto_Remesa__c c : [SELECT Id FROM Contacto_Remesa__c WHERE Id IN :selectedContactosIds]){

            //Actualizamos datos
            c.Estado__c = 'Pendiente';
            
            //Agregamos la remesa
            toUpdate.add(c);
        
        }    

        if(toUpdate.size() > 0){
        
            //Obtenemos el estado actual de la base de datos
            Savepoint sp = Database.setSavepoint();
            
            try{
                //Llamamos al metodo de actualizacion por lotes
                Utils.updateList(toUpdate, true);
                
                msg = new ApexPages.Message(ApexPages.severity.CONFIRM, 'Operación Exitosa','Se han vuelto a estado pendiente '+toUpdate.size()+' contactos remesa.');
                
                //Añadimos el mensaje a la pagina
                ApexPages.addMessage(msg);
                
                //Seteamos en null el listado de remesas para que vuelva a la BD y traiga el actualizado
                contactosRemesaSetController = null;

                selectedContactosIds.clear();
                
            }catch(DMLException e){
                //Ocurrio un error hacemos un Rollback
                Database.rollback(sp);
                
                ApexPages.addMessages(e);
            }
        
        }else{
            
            msg = new ApexPages.Message(ApexPages.severity.WARNING, 'Atención','No selecciono ningun contacto remesa.');
                    
            //Añadimos el mensaje a la pagina
            ApexPages.addMessage(msg);
            
        
        }

        return null;
    }
    
    public PageReference save(){
        
        //Variable que contendra el mensaje a mostrar 
        ApexPages.Message msg = null;
        
        if(contactoRemesa.Fecha_programada_de_envio__c == null){
            
            msg = new ApexPages.Message(ApexPages.severity.WARNING, 'Atención','No selecciono ninguna fecha.');
                    
            //Añadimos el mensaje a la pagina
            ApexPages.addMessage(msg);
            
            return null;    
        }
       
        //Lista que contendra las remesas a actualizar
        List<Contacto_Remesa__c> toUpdate = new List<Contacto_Remesa__c>();
        
        // Ciclamos sobre sus contactos remesas
        for(Contacto_Remesa__c c : [SELECT Id FROM Contacto_Remesa__c WHERE Id IN :selectedContactosIds LIMIT :EMAIL_SEND_LIMIT]){

            //Actualizamos datos
            c.Fecha_programada_de_envio__c = contactoRemesa.Fecha_programada_de_envio__c;
            c.Estado__c = 'Programado';

            //Agregamos el contacto
            toUpdate.add(c);

        }

        if(toUpdate.size() > 0){
        
            //Obtenemos el estado actual de la base de datos
            Savepoint sp = Database.setSavepoint();
            
            try{

                //Llamamos al metodo de actualizacion por lotes
                Utils.updateList(toUpdate, true);
                
                //Checkeamos que la cantidad de remesas programadas para esa fecha no haya superado las mil
                if(getContactosRemesasProgramadosByFecha()>EMAIL_SEND_LIMIT){
                    
                    //Si supero las mil hacemos un rollback
                    Database.rollback(sp);
                    
                    //Indicamos a la pagina que la cantidad de remesas programadas para esa fecha supera las 1000
                    msg = new ApexPages.Message(ApexPages.severity.WARNING, 'Error','Se ha superado el limite de '+EMAIL_SEND_LIMIT+'contactos remesas programados para la fecha seleccionada. Por favor seleccione otra fecha ó seleccione menos contactos remesas para la fecha seleccionada.');
                    
                }else{
                    
                    Date fechaProgramacion = contactoRemesa.Fecha_programada_de_envio__c;
             
                    msg = new ApexPages.Message(ApexPages.severity.CONFIRM, 'Operación Exitosa','Se han programado correctamente '+toUpdate.size()+' contactos remesa para la fecha '+fechaProgramacion.day()+'/'+fechaProgramacion.month()+'/'+fechaProgramacion.year());
                    
                }
                
                //Añadimos el mensaje a la pagina
                ApexPages.addMessage(msg);
                
                //Seteamos en null el listado de remesas para que vuelva a la BD y traiga el actualizado
                contactosRemesaSetController = null;

                selectedContactosIds.clear();
                
            }catch(DMLException e){
                //Ocurrio un error hacemos un Rollback
                Database.rollback(sp);
                
                ApexPages.addMessages(e);
            }
        
        }else{
            
            msg = new ApexPages.Message(ApexPages.severity.WARNING, 'Atención','No selecciono ningún contacto remesa.');
                    
            //Añadimos el mensaje a la pagina
            ApexPages.addMessage(msg);
            
        
        }
    
        
        return null;
    }
    
    public Integer getContactosRemesasProgramadosByFecha(){
        
        List<AggregateResult> cantidadRemesas = null;
        
        if(selectedZona == null){
        
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Fecha_programada_de_envio__c = :contactoRemesa.Fecha_programada_de_envio__c AND Estado__c != 'Enviado' AND Remesa__r.Lote__c = :lote.Id];
        
        }else{ 
            
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Fecha_programada_de_envio__c =:contactoRemesa.Fecha_programada_de_envio__c AND Estado__c != 'Enviado' AND Remesa__r.Zona_Bolsa_de_Cereales__c = :selectedZona AND Remesa__r.Lote__c = :lote.Id];
        }    
        
        if(cantidadRemesas.size() > 0)
            return (Integer)cantidadRemesas.get(0).get('Cantidad');
        else
            return 0;
    
    }
    
    /**
    * @author Maximo Martinez
    * @date 16/07/2014
    * @description Metodo que obtiene la Sumatoria de remesas de correo postal pendientes
    */ 
    public Integer getTotalRemesasError(){
        
        List<AggregateResult> cantidadRemesas = null;
        
        if(selectedZona == null)
        
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Error' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Lote__c = :lote.Id];
        
        else
            
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Error' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Zona_Bolsa_de_Cereales__c = :selectedZona AND Remesa__r.Lote__c = :lote.Id];
        
        
        if(cantidadRemesas.size() > 0)
            return (Integer)cantidadRemesas.get(0).get('Cantidad');
        else
            return 0;
        
    }
    
    /**
    * @author Maximo Martinez
    * @date 16/07/2014
    * @description Metodo que obtiene la Sumatoria de remesas de correo postal pendientes
    */ 
    public Integer getTotalRemesasCPPendientes(){
        
        List<AggregateResult> cantidadRemesas = null;
        
        if(selectedZona == null)
        
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Pendiente' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Lote__c = :lote.Id];
        
        else
            
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Pendiente' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Zona_Bolsa_de_Cereales__c = :selectedZona AND Remesa__r.Lote__c = :lote.Id];
        
        
        if(cantidadRemesas.size() > 0)
            return (Integer)cantidadRemesas.get(0).get('Cantidad');
        else
            return 0;
        
    }
    
    /**
    * @author Maximo Martinez
    * @date 16/07/2014
    * @description Metodo que obtiene la Sumatoria de remesas de correo postal programadas
    */ 
    public Integer getTotalRemesasCPProgramadas(){
        
        List<AggregateResult> cantidadRemesas = null;
        
        if(selectedZona == null)
        
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Programado' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Lote__c = :lote.Id];
        
        else
        
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Programado' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Zona_Bolsa_de_Cereales__c = :selectedZona AND Remesa__r.Lote__c = :lote.Id];
        
        
        if(cantidadRemesas.size() > 0)
            return (Integer)cantidadRemesas.get(0).get('Cantidad');
        else
            return 0;
        
    }


    public Integer getTotalContactosRemesaProgramadosByFecha(){
        return [SELECT COUNT() FROM Contacto_Remesa__c WHERE Estado__c = 'Programado' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Fecha_programada_de_envio__c = :contactoRemesa.Fecha_programada_de_envio__c];
    }
    
    /**
    * @author Maximo Martinez
    * @date 16/07/2014
    * @description Metodo que obtiene la Sumatoria de remesas de correo postal programadas
    */ 
    public Integer getTotalRemesasCPProgramadasByFecha(){
        
        List<AggregateResult> cantidadRemesas = null;
        
        if(selectedZona == null && contactoRemesa.Fecha_programada_de_envio__c == null){
        
            cantidadRemesas = new List<AggregateResult>();//[SELECT COUNT(Id) Cantidad FROM Remesa__c WHERE Estado__c = 'Programado' AND Modo_de_Envio__c = 'Correo Electrónico' AND Lote__c = :lote.Id];
        
        }else if(selectedZona != null && contactoRemesa.Fecha_programada_de_envio__c != null){
            
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Programado' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Zona_Bolsa_de_Cereales__c = :selectedZona  AND Fecha_programada_de_envio__c = :contactoRemesa.Fecha_programada_de_envio__c AND Remesa__r.Lote__c = :lote.Id];
        
        }else if(selectedZona != null){
        
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Programado' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Zona_Bolsa_de_Cereales__c = :selectedZona AND Remesa__r.Lote__c = :lote.Id];
        
        }else{
            
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Programado' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Fecha_programada_de_envio__c = :contactoRemesa.Fecha_programada_de_envio__c AND Remesa__r.Lote__c = :lote.Id];
        
        }   
        
        if(cantidadRemesas.size() > 0){
            return (Integer)cantidadRemesas.get(0).get('Cantidad');
        }else{
            return 0;
        }
                
    }
    
    /**
    * @author Maximo Martinez
    * @date 16/07/2014
    * @description Metodo que obtiene la Sumatoria de remesas de correo postal envia
    */ 
    public Integer getTotalRemesasCPEnviadas(){
        
        List<AggregateResult> cantidadRemesas = null;
        
        if(selectedZona == null)
        
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Enviado' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Lote__c = :lote.Id];
        
        else
            
            cantidadRemesas = [SELECT COUNT(Id) Cantidad FROM Contacto_Remesa__c WHERE Estado__c = 'Enviado' AND Remesa__r.RecordType.DeveloperName = 'Correo_Electronico' AND Remesa__r.Zona_Bolsa_de_Cereales__c = :selectedZona AND Remesa__r.Lote__c = :lote.Id];
        
        
        if(cantidadRemesas.size() > 0)
            return (Integer)cantidadRemesas.get(0).get('Cantidad');
        else
            return 0;
        
    }
    
    

    public List<ContactoRemesa> getContactosRemesa(){
        
        List<ContactoRemesa> contactosRemesas = new List<ContactoRemesa>();

        //Si no se seteo un filtro, retornamos una lista vacia
        if(String.isEmpty(selectedZona)){
            return contactosRemesas;
        }
    
        for(Contacto_Remesa__c c : (List<Contacto_Remesa__c>) contactosRemesaSetController.getRecords()){

            ContactoRemesa cr = new ContactoRemesa();

            cr.outerClass = this;

            cr.contacto = c;

            cr.isSelected = selectedContactosIds.contains(cr.contacto.Id);
            
            contactosRemesas.add(cr);
            
        }

        return contactosRemesas;
 
    }
    
    //Navigate to first Page
    public void firstPage(){
        contactosRemesaSetController.first();
    }

    //Navigate to last Page
    public void lastPage(){
        contactosRemesaSetController.last();
    }

    //Navigate to Next page
    public void next(){
        contactosRemesaSetController.next();
    }

    //Check if hash next
    public Boolean hasNext {
        get {
            return contactosRemesaSetController.getHasNext();
        }
        set;
    }


    // indicates whether there are more records before the current page set.
    public Boolean hasPrevious {
        get {
            return contactosRemesaSetController.getHasPrevious();
        }
        set;
    }

    //Navigate to Prev Page
    public void prev(){
        contactosRemesaSetController.previous();
    }

    public class ContactoRemesa {
        
        public ProgramacionEnvioEmailsController outerClass {get; set;}

        private Boolean isSelected {get; set;}

        public Boolean getIsSelected(){
            return isSelected;
        }

        public void setIsSelected(Boolean isSelected){
            this.isSelected = isSelected;
            if(isSelected){
                outerClass.selectedContactosIds.add(contacto.Id);
            }else if(outerClass.selectedContactosIds.contains(contacto.Id)){
                outerClass.selectedContactosIds.remove(contacto.Id);
            }
        }

        public Contacto_Remesa__c contacto {get; set;}

    }
    
}