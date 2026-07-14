public without sharing class DeclaracionesOnlineIndexController{
    
    //Atributo que contendra las transacciones del Productor
    //public List<Transaccion__c> transacciones {get; set;}
    
    //Atributo que contendra la cuenta Actual
    public Account productor {get; set;}
    
    private String baseQuery {get; set;}
    public String AccFilterId {get; set;}
    private Integer pageSize = 10;
    
    public String tokenProductor {get; set;}
    
    public ApexPages.StandardSetController AccSetController {
        get{
            if(AccSetController == null){
                AccSetController = new ApexPages.StandardSetController(Database.getQueryLocator(baseQuery));
                AccSetController.setPageSize(pageSize);

                // We have to set FilterId after Pagesize, else it will not work
                if(AccFilterId != null)
                {
                  AccSetController.setFilterId(AccFilterId);
                }
            }
            return AccSetController;
        }set;
    }
    
    
    //Constructor
    public DeclaracionesOnlineIndexController(ApexPages.StandardController controller){
       
       //Obtenemos el token pasado a la pagina 
       String token = ApexPages.currentPage().getParameters().get('token');
       
       //Si el token no es null lo desencriptamos
       if(token != null){
           String data = Utils.decryptToken(token.trim());
           
           System.Debug(LoggingLevel.INFO,data);
           
           productor = (Account)controller.getRecord();
           init(data);
       }
       
       
    }
    
    public List<Transaccion> getTransacciones(){
    
      //Lista que contendra las transacciones a devolver
      List<Transaccion>  transacciones = new List<Transaccion>();
      
      //Recorremos las transacciones
      for(Transaccion__c t : (List<Transaccion__c>)AccSetController.getRecords()){
          
          //Creamos un wrapper
          Transaccion tr = new Transaccion();
          tr.t = t;
          tr.token = Utils.createToken(t.Id);
          
          //Agregamos el wrapper a la lista
          transacciones.add(tr);
      }
        
      return transacciones;
    }

    
    //Metodo auxiliar para inicializacion de datos
    public void init(String idProductor){
        
        //Obtenemos los datos del productor
        
        List<Account> productores = [SELECT Id,N_CUIT__c,Name,Calle_Envio__c,Codigo_Postal_Envio__c,Localidad_Envio__r.Name,Provincia_Envio__c,Numero_Depto_Piso_Envio__c FROM Account WHERE Id =:idProductor LIMIT 1];
        
        if(productores.size() > 0){
            
            //Seteamos al productor
            productor = productores.get(0);
            
            //Obtenemos el RecordSet de las DUP
            Id rtTransaccionDUP = RecordTypeTool.getRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
            
            //String subQuery = 'SELECT Id FROM Campana_Agricola__c WHERE Estado__c = '+'\''+'Activa'+'\'';
            
            baseQuery = 'SELECT Anio_de_la_Auditoria__c,Campana__c,Campana__r.Name,Comentarios__c,Contacto__c,CreatedById,CreatedDate,Cultivo__c,Cultivo__r.Name,DUP_Original__c,DUP_Preexistente__c,Estado__c,Es_Comercio__c,Es_Denuncia__c,Factura__c,Fecha_de_la_Visita__c,Fecha_de_Respuesta__c,Fecha_de_Vencimiento__c,Flag_de_Estado__c,Gestor__c,Id,Id_Externo__c,IsDeleted,LastActivityDate,LastModifiedById,LastModifiedDate,LastReferencedDate,LastViewedDate,Lote__c,Mes_Actual__c,Name,Nombre_del_Lote__c,Nombre_de_la_cuenta__c,N_CUIT__c,Obtentor__c,Obtentor__r.Name,RecordTypeId,Remesa__c,SystemModstamp,Tipo_de_Cambio__c,Total_a_FacturarDUP__c,Total_a_Facturar__c,Z9_Codigo_Postal_Envio__c,Z9_Codigo_Postal_Facturacion__c,Z9_Id_Obtentor__c,Z9_Integracion__c,Z9_Lineas_en_Aprobacion__c,Z9_Lineas_En_Seguimiento__c,Z9_Lineas_No_Informadas__c,Z9_Lineas_Totales_Auditorias__c,Z9_Lineas_Totales_DUP__c,Z9_Tipo_de_Cambio__c FROM Transaccion__c WHERE '+' '+'Mostrar_en_Minisitio__c = true AND '+' Nombre_de_la_cuenta__c = '+'\''+productor.Id+'\''+' AND RecordTypeId = '+'\''+rtTransaccionDUP+'\' ORDER BY CreatedDate DESC';
            
            tokenProductor = Utils.createToken(productor.Id);
            
        }
    }
    
    
    //Logica paginación
    
    //Navigate to first Page
    public void firstPage(){
      AccSetController.first();
    }

    //Navigate to last Page
    public void lastPage(){
      AccSetController.last();
    }

    //Navigate to Next page
    public void next(){
      if(AccSetController.getHasNext()){
        AccSetController.next();
      }
    }

    //Navigate to Prev Page
    public void prev(){
      if(AccSetController.getHasPrevious()){
        AccSetController.previous();
      }
    }
    
    
    //Clase auxiliar que contiene la transaccion y un token 
    public class Transaccion{
        
        //Atributos
        public Transaccion__c t {get; set;}
        public String token {get; set;}
        
        
    }
    
    
}