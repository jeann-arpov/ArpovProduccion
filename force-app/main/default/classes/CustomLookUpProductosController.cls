public with sharing class CustomLookUpProductosController {
  
  private String baseQuery {get; set;}
  public String AccFilterId {get; set;}
  private Integer pageSize = 10;
  private String sortDirection = 'ASC';
  private String sortExp = 'name';

  public CustomLookUpProductosController(){
      filter();
  }

  public ApexPages.StandardSetController AccSetController {
        get{
            if(AccSetController == null){
                AccSetController = new ApexPages.StandardSetController(Database.getQueryLocator(baseQuery));
                AccSetController.setPageSize(pageSize);

                // We have to set FilterId after Pagesize, else it will not work
                if(AccFilterId != null){
                  AccSetController.setFilterId(AccFilterId);
                }
            }
            return AccSetController;
        }set;
    }
    
    private void filter(){
    
        //Obtenemos el Id del Originante
        String idOriginante = ApexPages.currentPage().getParameters().get('idOriginante');
        
        //Obtenemos el Id de la campaña
        String idCampana = ApexPages.currentPage().getParameters().get('idCampana');
        
        System.Debug(LoggingLevel.INFO,idOriginante);
        
        //Si no se definio un id o el id no es un id valido mostramos todos los productos
        if(idOriginante == '000000000000000' || validateId(idOriginante) == null){
            //Definimos la query
            baseQuery = 'Select ID, Name, Cultivo__r.Name, Variedad__c, Categoria__c,Unidad_de_Medida__c,Precio__c FROM Product2';
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
                    
                    baseQuery = 'Select ID, Name, Cultivo__r.Name, Variedad__c, Categoria__c,Unidad_de_Medida__c,Precio__c FROM Product2 WHERE Obtentor_Comercializa__c = '+'\''+cuenta.Id+'\'';
                    
                }else{
                    
                    //Si el originante no es ni Obtentor, ni Distribuidor ni Comercio, muestro todos los productos
                    baseQuery = 'Select ID, Name, Cultivo__r.Name, Variedad__c, Categoria__c,Unidad_de_Medida__c,Precio__c FROM Product2';
                
                }
            
            }
            
            
        }
        
        baseQuery += ' '+'ORDER BY '+sortExp+' '+sortDirection;
        
    }
    
    private static  String validateId(String Idparam) {
        String id = String.escapeSingleQuotes(Idparam);
        if((id.length() == 15 || id.length() == 18) && Pattern.matches('^[a-zA-Z0-9]*$', id)) {
            return id;
        }
        return null;
    }
    
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

    public List<Product2> getProducts()    {
      return (List<Product2>)AccSetController.getRecords();
    }

    /**
    * Reset List View
    */
    public PageReference resetFilter(){
        AccSetController = null;
        AccSetController.setPageNumber(1);
        return null;
    }
    
    //Sort Column
    public void sortTable(){
        AccSetController = null;
        filter();
    }
    
    public String sortExpression{
     get{
        return sortExp;
     }
     
     set{
       //if the column is clicked on then switch between Ascending and Descending modes
       if (value == sortExp)
         sortDirection = (sortDirection == 'ASC')? 'DESC' : 'ASC';
       else
         sortDirection = 'ASC';
       sortExp = value;
     }
   }
   
   public String getSortDirection(){
    //if not column is selected 
    if (sortExpression == null || sortExpression == '')
      return 'ASC';
    else
     return sortDirection;
   }

   public void setSortDirection(String value){  
       sortDirection = value;
   }

}