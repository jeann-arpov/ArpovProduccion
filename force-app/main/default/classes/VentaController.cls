/*Controlador de la Pagina VF Venta*/
global class VentaController {
    
    private static final String FOLDER_DEVELOPER_NAME = 'Importacion_Masiva_Ventas';
    /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Atributos
    */
    public RowWrapper fila = new RowWrapper();
    public List<RowWrapper> filas = new List<RowWrapper>();
    public Integer numberOfRowToRemove { get; set; }
    public Boolean isCuitFocus {get; set;}
    public Blob contentFile{get;set;}
    public Product2 producto {get; set;}
    public Map<String, List<Integer>> ventasDuplicadasError {get; set;}
    public String fileName {get; set;}
    public Boolean runningBatchJob {get; set;}
    public Id idBatchJob {get; set;} 
    private BatchApexVentasImportFromFile batch {get; set;}
    private String timeStamp;


    /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Metodo Constructor
    */
    public VentaController() {
       this.fila.venta = new Venta__c();
       this.isCuitFocus = false;
       this.producto = new Product2();
       this.runningBatchJob = false;
       this.timeStamp = String.valueOf(System.now());
    }                 
    
    public void setFila(RowWrapper fila){
        this.fila = fila;
    }
    
    public RowWrapper getFila(){
        return this.fila;
    }
    
    public void setFilas(List<RowWrapper> filas){
        this.filas = filas;
    }
    
    public List<RowWrapper> getFilas(){
        return this.filas;
    }
    
    @RemoteAction
    public static List<Product2> getProductsByName(String name, String idOriginante, String idCampana){
        
        name = '%'+name+'%';
        
        String query = '';
        
        //Reglas de filtrado
         //Si no se definio un id o el id no es un id valido mostramos todos los productos
        if(idOriginante == '000000000000000' || validateId(idOriginante) == null){
            //Definimos la query
            query = 'Select ID, Name, Cultivo__r.Name, Variedad__c, Categoria__c,Unidad_de_Medida__c,Precio__c FROM Product2 WHERE Name LIKE :name ORDER BY NAME ASC';
        }else{
            
            //Obtenemos el recordtype de un Obtentor
            Id rtO = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');
            
            //Obtenemos el originante
            List<Account> cuentas = [SELECT Id, RecordTypeId FROM Account WHERE Id = :idOriginante LIMIT 1];
            
            if(cuentas.size() > 0){
            
                //OBtenemos la cuenta
                Account cuenta = cuentas.get(0);
                
                //Si el Originante es un Obtentor, filtramos por los productos donde el Obtentor Comercializa
                //es igual a este id
                if(cuenta.RecordTypeId == rtO){
                    
                    query = 'Select ID, Name, Cultivo__r.Name, Variedad__c, Categoria__c,Unidad_de_Medida__c,Precio__c FROM Product2 WHERE Obtentor_Comercializa__c = '+'\''+cuenta.Id+'\''+' '+'AND'+' '+'Name LIKE :name ORDER BY NAME ASC';
                    
                }else{
                    
                    //Si el originante no es ni Obtentor, ni Distribuidor ni Comercio, muestro todos los productos
                    query = 'Select ID, Name, Cultivo__r.Name, Variedad__c, Categoria__c,Unidad_de_Medida__c,Precio__c FROM Product2'+' '+'WHERE'+' '+'Name LIKE :name ORDER BY NAME ASC';
                
                }
            
            }
            
            
        }
        
        System.Debug(LoggingLevel.INFO,query);
        
        //Lista que contendra los productos a devolver
        List<Product2> productos = new List<Product2>();
        
        for(Product2 producto : Database.Query(query)){
            //Insertamos el producto en la lista de productos a devolver
            productos.add(producto);
        }
        
        return productos;
    }
    
   
    
    @RemoteAction
    public static Product2 getProduct(String name, String idOriginante, String idCampana){
        
        String baseQuery = '';
        
         //Si no se definio un id o el id no es un id valido mostramos todos los productos
        if(idOriginante == '000000000000000' || validateId(idOriginante) == null){
            //Definimos la query
            baseQuery = 'Select ID, Name, Cultivo__r.Name, Variedad__c, Categoria__c,Unidad_de_Medida__c,Precio__c FROM Product2 WHERE Name = :name ORDER BY NAME ASC';
        }else{
            
            //Obtenemos el recordtype de un Obtentor
            Id rtO = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');
            
            //Obtenemos el RecordType para un Distribuidor
            Id rtD = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Distribuidor');
        
            //Obtenemos el RecordType para un Comercio
            Id rtC = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Comercio');
            
            //Obtenemos el originante
            List<Account> cuentas = [SELECT Id, RecordTypeId FROM Account WHERE Id = :idOriginante LIMIT 1];
            
            if(cuentas.size() > 0){
            
                //OBtenemos la cuenta
                Account cuenta = cuentas.get(0);
                
                //Si el Originante es un Obtentor, filtramos por los productos donde el Obtentor Comercializa
                //es igual a este id
                if(cuenta.RecordTypeId == rtO){
                    
                    baseQuery = 'Select ID, Name, Cultivo__r.Name, Variedad__c, Categoria__c,Unidad_de_Medida__c,Precio__c FROM Product2 WHERE Name = :name AND Obtentor_Comercializa__c = '+'\''+cuenta.Id+'\''+' ORDER BY NAME ASC';
                    
                }else{
                    
                    //Si el originante no es ni Obtentor, ni Distribuidor ni Comercio, muestro todos los productos
                    baseQuery = 'Select ID, Name, Cultivo__r.Name, Variedad__c, Categoria__c,Unidad_de_Medida__c,Precio__c FROM Product2 WHERE Name = :name ORDER BY NAME ASC';
                
                }
           }
           
        }
        
        
        List<Product2> productos = Database.Query(baseQuery);
        
        
        Product2 producto = null;
        
        
        if(productos.size() > 0){
        
            producto = productos.get(0);
        
        }
        
        return producto;         
        
    }
    
    
    private static  String validateId(String Idparam) {
        String id = String.escapeSingleQuotes(Idparam);
        if((id.length() == 15 || id.length() == 18) && Pattern.matches('^[a-zA-Z0-9]*$', id)) {
            return id;
        }
        return null;
    }


    /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo que proceso el archivo CSV que contiene las lineas de venta
    */ 
    public void uploadFile(){
        runningBatchJob = true;
        batch = new BatchApexVentasImportFromFile(this.contentFile.toString(), '\r'+'\n', fileName, timeStamp);
        idBatchJob = Database.executeBatch(batch, BatchApexVentasImportFromFile.SCOPE_SIZE);  
        this.contentFile = null; 
    }

    public Boolean getShowDownloadFileError(){

        // Reviso el status del batch
        List<AsyncApexJob> ajs = [SELECT Id FROM AsyncApexJob WHERE Id = :idBatchJob AND Status = 'Completed'];

        if(ajs.isEmpty())
            return false;


        // Obtengo la carpeta donde almacenare el archivo de exitos y/o errores
        List<Folder> fs = [SELECT Id,DeveloperName FROM Folder WHERE DeveloperName = :FOLDER_DEVELOPER_NAME];

        String fileNameErrors = timeStamp+'_errors';

        // Obtengo el file de errores
        List<Document> ds = [SELECT Id FROM Document WHERE Name = :fileNameErrors AND Type = 'csv'];

        return ds.size() == 1;
    }

    public Boolean getShowUploadFileSuccess(){

        // Reviso el status del batch
        List<AsyncApexJob> ajs = [SELECT Id FROM AsyncApexJob WHERE Id = :idBatchJob AND Status = 'Completed'];

        if(ajs.isEmpty())
            return false;

        // Obtengo la carpeta donde almacenare el archivo de exitos y/o errores
        List<Folder> fs = [SELECT Id,DeveloperName FROM Folder WHERE DeveloperName = :FOLDER_DEVELOPER_NAME];

        String fileNameSuccess = timeStamp+'_success';

        // Obtengo el file de errores
        List<Document> ds = [SELECT Id FROM Document WHERE Name = :fileNameSuccess AND Type = 'csv'];

        return ds.size() == 1;
    }


    public String getFileErrorLink(){
        // Obtengo la carpeta donde almacenare el archivo de exitos y/o errores
        List<Folder> fs = [SELECT Id,DeveloperName FROM Folder WHERE DeveloperName = :FOLDER_DEVELOPER_NAME];

        String fileNameErrors = timeStamp+'_errors';

        // Obtengo el file de errores
        List<Document> ds = [SELECT Id FROM Document WHERE Name = :fileNameErrors AND Type = 'csv'];

        if(ds.size() == 1)
            return ds.get(0).Id;

        return null;
    }

    public String getFileSuccessLink(){
        // Obtengo la carpeta donde almacenare el archivo de exitos y/o errores
        List<Folder> fs = [SELECT Id,DeveloperName FROM Folder WHERE DeveloperName = :FOLDER_DEVELOPER_NAME];

        String fileNameSuccess = timeStamp+'_success';

        // Obtengo el file de errores
        List<Document> ds = [SELECT Id FROM Document WHERE Name = :fileNameSuccess AND Type = 'csv'];

        if(ds.size() == 1)
            return ds.get(0).Id;

        return null;
    }
    
    
    public PageReference addVenta(){
        
        //Creamos un wrapper
        RowWrapper rw = new RowWrapper();
        rw.venta = this.fila.venta.clone(false,false);
        //rw.venta.Producto__c = producto.Id;
        rw.index = this.filas.size();
        
        //Insertamos la venta en la Bd
        try{
            insert rw.venta;
            
            //Reseteamos algunos valores de la fila template
            this.fila.venta.Destinatario__c = null;
            this.fila.venta.Producto__c = null;
            this.fila.venta.Cantidad__c = null;
            this.fila.venta.Tipo_de_Venta__c = null;
            this.fila.venta.Nro_de_Comprobante__c = null;
            this.fila.venta.Tipo_de_Venta__c = null;
           
            this.filas.add(rw);   
        }catch(Exception e){
            System.Debug(LoggingLevel.INFO,e.getMessage());
            ApexPages.addMessages(e); 
        }
        
        
        return null;
    }
    
    public void deleteVenta(){
        //Obtenemos el id de la venta
        String id = ApexPages.currentPage().getParameters().get('idVenta');
        
        System.Debug(LoggingLevel.INFO,id);
        
        //Obtenemos la venta
        List<Venta__c> ventas = [SELECT Id FROM Venta__c WHERE Id = :id LIMIT 1];
        
        if(ventas.size() > 0){
            Venta__c venta = ventas.get(0);
            
            //Eliminamos la venta
            
            try{
                delete venta;
                //Eliminamos la venta (si esta) de la lista de ventas mostradas
                Integer i = 0;
                while(i < this.filas.size() && this.filas.get(i).venta.Id != id){
                    i++;
                }
                if(i < this.filas.size() && this.filas.get(i).venta.Id == id){
                    this.filas.remove(i);
                }
            }catch(Exception e){
                ApexPages.addMessages(e);
            }
            
            
        }
    }
    
    public PageReference finish(){
        //Obtenemos Describe Result del objeto ventas
        Schema.DescribeSObjectResult dsr = Venta__c.SObjectType.getDescribe();
        //Seteamos la URL de la Tab de ventas
        PageReference prRef = new PageReference('/' + dsr.getKeyPrefix());
        prRef.setRedirect(true);
        //Redirigimos a la tab de ventas
        return prRef;
    }
    
    public PageReference cancelVentas(){
        //Obtenemos Describe Result del objeto ventas
        Schema.DescribeSObjectResult dsr = Venta__c.SObjectType.getDescribe();
        //Seteamos la URL de la Tab de ventas
        PageReference prRef = new PageReference('/' + dsr.getKeyPrefix());
        prRef.setRedirect(true);
        //Redirigimos a la tab de ventas
        return prRef;
    }

    /*
        CLASES AUXILIARES
    */
    
    
    //Clase auxiliar usada para la carga desde archivo
    public class WrapperVenta{
        
        public Venta__c venta {get; set;}
        public Account originante {get; set;}
        public Account destinatario {get; set;}
        
    }

    public class RowWrapper{
        public Venta__c venta {get; set;}
        public Integer index {get; set;}
        public String cuitDestinatario {get;set;}
        public String cuitOriginante {get; set;}
    }
}