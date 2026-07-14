/**
* @author Maximo Martinez
* @date 17/02/2020
* @description Clase batcheable que representa un proceso por lotes para procesar las filas de un archivo excel subido por pantall
*/
public with sharing class BatchApexProcessItemsDupsFromExcel implements Database.Batchable<Map<String,Object>>, Database.Stateful{
    
    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Configuracion Personalizada del Desarrollo
    */
    private static final Configuracion_Carga_Dups_Excel__c settings = Configuracion_Carga_Dups_Excel__c.getOrgDefaults();


    /**
    * @author Maximo Martinez
    * @date 24/04/2020
    * @description Cultivo a usar en el procesamiento
    */
    public static final Integer BATCH_SIZE = settings.Tamano_Lote_Batch__c.intValue();

     /**
    * @author Maximo Martinez
    * @date 28/04/2020
    * @description Tipo de Registro Productor
    */
    public static final Id recordTypeProductorId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Productor');
    

    /**
    * @author Maximo Martinez
    * @date 24/04/2020
    * @description Cultivo a usar en el procesamiento
    */
    private static final Cultivo__c cultivo = [SELECT Densidad_de_Siembra__c FROM Cultivo__c WHERE Id = :settings.Cultivo__c];


    /**
    * @author Maximo Martinez
    * @date 24/04/2020
    * @description Id de la campaña a usar en el procesamiento
    */
    private Id campaignId;
    
    
    /**
    * @author Maximo Martinez
    * @date 24/04/2020
    * @description Id de la deslintadora
    */
    private Id deslintadoraId;
    
    /**
    * @author Maximo Martinez
    * @date 24/04/2020
    * @description Id de la campaña a usar en el procesamiento
    */
    private String description;

    /**
    * @author Maximo Martinez
    * @date 24/04/2020
    * @description Id de la campaña a usar en el procesamiento
    */
    private List<Map<String,Object>> fileRows;


    /**
    * @author Maximo Martinez
    * @date 24/04/2020
    * @description Id de la campaña a usar en el procesamiento
    */
    private Map<String,Transaccion> transactionsByKey = new Map<String,Transaccion>();

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Separador
    */
    private static final String SEPARATOR = '-';

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Separador
    */
    private Boolean hasErrors = false;

    /**
    * @author Maximo Martinez
    * @date 24/04/2020
    * @description Separador
    */
    public BatchApexProcessItemsDupsFromExcel(List<Map<String,Object>> fileRows, Id campaignId, Id deslintadoraId, String description){
        this.fileRows = fileRows;
        this.campaignId = campaignId;
        this.deslintadoraId = deslintadoraId;
        this.description = description;
    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Separador
    */
    public Iterable<Map<String,Object>> start(Database.batchableContext batchableContext){
        return new MapIterator(fileRows);
    }


    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Separador
    */
    public void execute(Database.BatchableContext bc, List<Map<String,Object>> scope){

        Response result = new Response().setFileRows(scope).setIsSuccess(true);

        Set<String> variedades = new Set<String>();

        Set<String> cuitsRemitenteDestinatario = new Set<String>(); 

        Map<String,List<Map<String,Object>>> fileRowsByKey = new Map<String,List<Map<String,Object>>>();

        Map<String,Product2> productByVariedad = new Map<String,Product2>();

        Map<String,Account> accountsByCuit = new Map<String,Account>();

        Map<String,Cuenta> pructoresToCreateByCuit = new Map<String,Cuenta>();

        Map<Schema.SObjectType,ListHelper> listHelperByType = new Map<Schema.SObjectType,ListHelper>{
            Account.getSObjectType() => new ListHelper(),
            Transaccion__c.getSObjectType() => new ListHelper(),
            Item_de_DUP__c.getSObjectType() => new ListHelper()
        };

        Lote__c lote = createNewLote(campaignId,description);

        // Coleccionams las variedades para luego ir a buscar el obtentor que las comercializa
        for(Map<String,Object> fileRow : scope){

            String variedad = String.valueOf(fileRow.get(settings.Columna_Variedad_Producto__c));
            String cuitRemitenteDestinatario = String.valueOf(fileRow.get(settings.Columna_CUIT_Remitente_Destinatario__c));
            String remitenteDestinatario = String.valueOf(fileRow.get(settings.Columna_Remitente_Destinatario__c));

            if(!String.isEmpty(variedad)){
                variedades.add(variedad.toLowerCase());
            }

            if(!String.isEmpty(cuitRemitenteDestinatario)){
                cuitsRemitenteDestinatario.add(cuitRemitenteDestinatario);
            }

            if(!pructoresToCreateByCuit.containsKey(cuitRemitenteDestinatario) && !String.isEmpty(cuitRemitenteDestinatario) && !String.isEmpty(remitenteDestinatario)){
                pructoresToCreateByCuit.put(cuitRemitenteDestinatario,new Cuenta(createProductor(cuitRemitenteDestinatario,remitenteDestinatario),fileRow));
            }

        }

        // Busco los productos de las variedades que se cultivan para obtener la info que tenemos de los mismos
        for(Product2 product : [SELECT Id, Variedad__c, Obtentor_Comercializa__c FROM Product2 WHERE Variedad__c IN :variedades AND Family = :settings.Familia_Productos__c AND Precio__c != null AND Categoria__c = :settings.Categoria_Productos__c AND IsActive = true ]){
            productByVariedad.put(product.Variedad__c.toLowerCase(),product);
        }

        // Busco los cuits en las cuentas
        for(Account acc : [SELECT Id, N_CUIT__c FROM Account WHERE N_CUIT__c IN :cuitsRemitenteDestinatario]){
            
            accountsByCuit.put(acc.N_CUIT__c,acc);

            // Si existe la cuenta ya cargada no la inserto
            pructoresToCreateByCuit.remove(acc.N_CUIT__c);

        }

        // Si hay productores para insertar insertamos
        if(!pructoresToCreateByCuit.isEmpty()){

            for(Cuenta cta : pructoresToCreateByCuit.values()){
                
                listHelperByType
                .get(Account.getSObjectType())
                .add(cta.cuenta)
                .add(cta);

                // Agregamos la cuenta al map de cuentas para que no de error al momento de asociarla con una transaccion
                accountsByCuit.put(cta.cuenta.N_CUIT__c, cta.cuenta);

            }

            if(checkErrors(listHelperByType.get(Account.getSObjectType()))){
                result.setIsSuccess(false);
            }

        }

        for(Map<String,Object> fileRow : scope){

            String variedad = String.valueOf(fileRow.get(settings.Columna_Variedad_Producto__c));
            String cuitRemitenteDestinatario = String.valueOf(fileRow.get(settings.Columna_CUIT_Remitente_Destinatario__c));

            // Verificamos que:
            // Exista un valor para variedad
            // Exista un valor para cuitRemitenteDestinatario
            // Tengamos en Salesforce un producto para esa variedad
            // Tengamos en Salesforce una Cuenta para ese CUIT
            if(String.isEmpty(variedad)){
                fileRow.put(settings.Columna_Error__c,String.format('Ingrese un valor en {0}', new List<String>{settings.Columna_Variedad_Producto__c}));
                continue;
            }else if(!productByVariedad.containsKey(variedad.toLowerCase())){
                fileRow.put(settings.Columna_Error__c,String.format('Variedad "{0}" no encontrada en Salesforce.', new List<String>{variedad}));
                continue;
            }

            if(String.isEmpty(cuitRemitenteDestinatario)){
                fileRow.put(settings.Columna_Error__c,String.format('Ingrese un valor en {0}', new List<String>{settings.Columna_CUIT_Remitente_Destinatario__c}));
                continue;
            }else if(!accountsByCuit.containsKey(cuitRemitenteDestinatario)){
                fileRow.put(settings.Columna_Error__c,String.format('CUIT "{0}" no encontrado en Salesforce, revice errores asociados intentar crear la cuenta.', new List<String>{cuitRemitenteDestinatario}));
                continue;
            }

            // Obtenemos el productos
            Product2 producto = productByVariedad.get(variedad.toLowerCase());

            // Obtenemos la cuenta
            Account accRemitenteDestinatario = accountsByCuit.get(cuitRemitenteDestinatario);

            String keyTransaction = String.valueOf(fileRow.get(settings.Columna_CUIT_Remitente_Destinatario__c)) + SEPARATOR + producto.Obtentor_Comercializa__c;

            // Creamos un objeto decorator de la transaccion a fin de agrupar transacciones con sus items
            // Si existe ya una entrada para la convinacion de cuits simplemente obtenemos el mismo
            Transaccion decorator = (!transactionsByKey.containsKey(keyTransaction)) ? new Transaccion(fileRow) : transactionsByKey.get(keyTransaction);

            System.debug(LoggingLevel.WARN,decorator);

            // Verificamos si ya creamos una transacciones para la convinacion de cuits
            if(!transactionsByKey.containsKey(keyTransaction)){
                
                // Creamos una transaccion
                decorator.transacion = createNewTransaction(lote.Id,campaignId,producto.Obtentor_Comercializa__c,accRemitenteDestinatario.Id, deslintadoraId);

                // Agregamos la entrada al map
                transactionsByKey.put(keyTransaction, decorator);

                // Agregamos la transaccion a la lista de insertables
                // Agregamos el decotaror a una lista de decorators

                listHelperByType
                .get(Transaccion__c.getSObjectType())
                .add(decorator.transacion)
                .add(decorator);

            }

            Item decoratorItem =  new Item(createNewItemDeDUP(campaignId,producto.Obtentor_Comercializa__c,producto.Id, Integer.valueOf(fileRow.get(settings.Columna_Egresos__c)),Integer.valueOf(fileRow.get(settings.Columna_Ingresos__c))),fileRow);

            // Verificamos si la transaccion ya habia sido creada en otro lote
            if(String.isEmpty(decorator.transacion.Id)){
            
                // Agregamos un item dup
                decorator.items.add(decoratorItem);
            
            }else{ // La transaccion ya fue creada en otro lote

                decoratorItem.item.Transaccion__c = decorator.transacion.Id;

                listHelperByType
                .get(Item_de_DUP__c.getSObjectType())
                .add(decoratorItem.item)
                .add(decoratorItem);

            }

        }


        // Insertamos las transacciones si es que hay alguna
        if(listHelperByType.get(Transaccion__c.getSObjectType()).isEmpty() && listHelperByType.get(Item_de_DUP__c.getSObjectType()).isEmpty()){
            EventBus.publish(new Notificacion_Batch_Apex__e(Job_Id__c=bc.getJobId(),IsSuccess__c=false,Body__c=JSON.serialize(result.setIsSuccess(false).build())));
            hasErrors = true;
            return;
        }

        for(Schema.SObjectType sObjectType : listHelperByType.keySet()){
            if(checkErrors(listHelperByType.get(sObjectType))){
                result.setIsSuccess(false);
            }
        }

        // Limpiamos los items a insertar y los decorators de item de dup ya que vamos a usar un nuevo set de datos
        listHelperByType.get(Item_de_DUP__c.getSObjectType()).clear();

        // Recorremos los decorators relacionados a transacciones y agregamos el id en los items de dup
        for(Decorator dec : listHelperByType.get(Transaccion__c.getSObjectType()).decoratorsList){

            if(String.isEmpty(((Transaccion)dec).transacion.Id)){
                continue;
            }

            for(Item it : ((Transaccion)dec).items){
                
                it.item.Transaccion__c = ((Transaccion)dec).transacion.Id;

                listHelperByType
                .get(Item_de_DUP__c.getSObjectType())
                .add(it.item)
                .add(it);

            }

        }

        if(checkErrors(listHelperByType.get(Item_de_DUP__c.getSObjectType()))){
            result.setIsSuccess(false);
            hasErrors = true;
        }
        
        // Lanzamos el evento para indicar a los que esten subscriptos que se proceso el lote
        EventBus.publish(new Notificacion_Batch_Apex__e(Job_Id__c=bc.getJobId(),IsSuccess__c=result.success,Body__c=JSON.serialize(result.setIsSuccess(result.success).build())));
        
    }

    public void finish(Database.BatchableContext bc){


        System.debug(LoggingLevel.ERROR,transactionsByKey);
        System.debug(LoggingLevel.ERROR,hasErrors);

        String systemErrors = BatchErrorHelper.getBatchClassErrors(bc);

        // Si hay errores limpiamos las transacciones creadas
        if(hasErrors){

            List<Transaccion__c> transactionsToDelete = new List<Transaccion__c>();

            for(Transaccion tr : transactionsByKey.values()){
                transactionsToDelete.add(tr.transacion);
            }

            Database.delete(transactionsToDelete,true);

        }

        EventBus.publish(new Notificacion_Batch_Apex__e(
                    Job_Id__c = bc.getJobId(),
                    IsSuccess__c = String.isEmpty(systemErrors),
                    Body__c = systemErrors,
                    IsFinish__c = true
                )
        );

    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Clase Auxiliar para manejar las dos listas que debemos procesar en paralelo
    */
    @TestVisible
    private class ListHelper{
        
        public List<SObject> sObjectsList = new List<SObject>();
        
        public List<Decorator> decoratorsList = new List<Decorator>();

        public ListHelper add(SObject sobj){
            sObjectsList.add(sobj);
            return this;
        }

        public ListHelper add(Decorator dec){
            decoratorsList.add(dec);
            return this;
        }

        public Boolean isEmpty(){
            return sObjectsList.isEmpty() && decoratorsList.isEmpty();
        }

        public void clear(){
            sObjectsList.clear();
            decoratorsList.clear();
        }

    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description crea un productor con datos pasados como parametro
    */
    private static Account createProductor(String cuit, String nombre){
        Account productor = new Account();
        productor.RecordTypeId = recordTypeProductorId;
        productor.Name = nombre;
        productor.N_CUIT__c = cuit;
        return productor;
    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description crea un lote con datos pasados como parametro
    */
    private static  Lote__c createNewLote(Id campaignId, String description) {
        Lote__c lote = new Lote__c();
        lote.Campana__c = campaignId;        
        lote.Cultivo__c = settings.Cultivo__c;
        lote.Descripcion__c = description;
        lote.Enviar_Letterhead_Siempre__c = True;
        lote.Fecha_Lanzamiento__c = System.today();
        lote.Tipo_de_Lote__c = settings.Lote_Tipo_de_Lote__c;
        lote.Tipo__c = settings.Lote_Tipo__c;
        insert lote;
        return lote;
    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Crea una transaccion a partir de datos y de la custom settings usada en el desarrollo de carga desde excel
    */
    @TestVisible
    private static Transaccion__c createNewTransaction(Id loteId, Id campaignId, Id obtentorComercialProducto, Id remitenteDestinatario, Id deslintadora){
        Transaccion__c trans = new Transaccion__c();
        trans.RecordTypeId = settings.Transaccion_Tipo_de_Registro__c;
        trans.Cultivo__c = settings.Cultivo__c;
        trans.Estado__c = settings.Transaccion_Estado__c;
        trans.Lote__c = loteId;
        trans.Fecha_de_Vencimiento__c = Date.today().addDays(settings.Dias_Vencimiento__c.intValue());
        trans.Obtentor__c = obtentorComercialProducto;
        trans.Nombre_de_la_cuenta__c = remitenteDestinatario;
        trans.Campana__c = campaignId;
        trans.Deslintadora__c = deslintadora;
        return trans;
    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Crea un item de dup a partir de datos y de la custom settings usada en el desarrollo de carga desde excel
    */
    @TestVisible
    private static Item_de_DUP__c createNewItemDeDUP(Id campaignId, Id  obtentorComercialProducto, Id productId, Integer cantidadEgresada, Integer cantidadIngresada){
        Item_de_DUP__c item = new Item_de_DUP__c();
        item.Campana_Agricola__c =  campaignId;
        item.Cantidad_Declarada__c =  cantidadEgresada;
        item.Densidad_de_Siembra__c = cultivo.Densidad_de_Siembra__c;
        item.Estado__c = settings.Item_de_Dup_Estado__c;
        item.Obtentor__c = obtentorComercialProducto;
        item.Producto__c = productId;
        item.Z9_Tipo_de_Producto__c = settings.Item_de_Dup_Tipo_de_Producto__c;
        item.Unidad_de_Medida_Declarada__c = settings.Item_de_Dup_Unidad_de_Medida_Declarada__c;
        item.Cantidad_Ingresada__c = cantidadIngresada;
        return item;
    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Intenta insertar registros y marca los errores en las filas de archivos
    */
    private static Boolean checkErrors(ListHelper lHelper){

        Boolean hasErrors = false;

        List<Database.SaveResult> svrs = Utils.insertList(lHelper.sObjectsList,false);

        Integer i = 0;

        for(Database.SaveResult svr : svrs){

            Decorator dec = lHelper.decoratorsList.get(i);

            if(!svr.isSuccess()){
                hasErrors = true;
                dec.setErrors(svr.getErrors()[0].getMessage());
            }else{
                dec.setRecordId(svr.getId());
            }

            i++;

        }

        return hasErrors;

    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Clase Auxiliar para agrupar extender funcionalidad de un sobject
    */
    public abstract class Decorator{
        
        public Map<String,Object> fileRow {get; set;}
        
        public Decorator(Map<String,Object> fileRow){
            this.fileRow = fileRow;
        }

        public abstract void setErrors(String errors);

        public abstract void setRecordId(Id recordId);

    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Clase Auxiliar para agrupar extender funcionalidad de una transaccion
    */
    public class Transaccion extends Decorator{
        
        public Transaccion__c transacion {get; set;}
        
        public List<Item> items {get; set;}
        
        public Transaccion(Map<String,Object> fileRow){
            super(fileRow);
            items = new List<Item>();
        }

        public override void setErrors(String errors){
            this.fileRow.put(settings.Columna_Error_Alta_Transaccion__c,errors);
        }

        public override void setRecordId(Id recordId){
            this.fileRow.put(settings.Columna_Alta_Transaccion__c,recordId);
        }

    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Clase Auxiliar para extender funcionalidad de un Item Dup
    */
    public class Item extends Decorator{
        
        public Item_de_DUP__c item {get; set;}
        
        public Item(Item_de_DUP__c item,Map<String,Object> fileRow){
            super(fileRow);
            this.item = item;
        }

        public override void setErrors(String errors){
            this.fileRow.put(settings.Columna_Error_Alta_Item_DUP__c,errors);
        }

        public override void setRecordId(Id recordId){
            this.fileRow.put(settings.Columna_Alta_Item_DUP__c,recordId);
        }

    }

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Clase Auxiliar para agrupar extender funcionalidad de una cuenta
    */
    public class Cuenta extends Decorator{
        
        public Account cuenta {get; set;}
        
        public Cuenta(Account cuenta,Map<String,Object> fileRow){
            super(fileRow);
            this.cuenta = cuenta;
        }

        public override void setErrors(String errors){
            this.fileRow.put(settings.Columna_Error_Alta_Cuenta__c,errors);
        }

        public override void setRecordId(Id recordId){
            this.fileRow.put(settings.Columna_Alta_Cuenta__c,recordId);
        }

    }


    /**
    * @author Maximo Martinez
    * @date 19/02/2020
    * @description Clase Auxiliar que actua entre interfaz del controlador y el componente
    */
    public class Response{
        
        @AuraEnabled
        public List<Map<String,Object>> filesRows;
        
        @AuraEnabled
        public Boolean success;

        public Response setFileRows(List<Map<String,Object>> filesRows){
            this.filesRows = filesRows;
            return this;
        }

        public Response setIsSuccess(Boolean isSuccess){
            success = isSuccess;
            return this;
        }

        public Response build(){
            return this;

        }

    }



}