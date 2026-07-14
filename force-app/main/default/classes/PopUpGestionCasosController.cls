public with sharing class PopUpGestionCasosController{
    
    //Campos del conjunto de campos
    public List<Schema.FieldSetMember> conjuntoDeCampos {get; set;}
    
    //Objeto 
    public sObject objeto {get; set;}
    
    //Tipo de objeto
    public String tipoObjeto {get; set;}
    
    public PopUpGestionCasosController(){
        
        //Obtenemos el id que se esta pasando por parametro
        Id idObjeto = ApexPages.currentPage().getParameters().get('idObjeto');
        
        //Obetenemos el conjunto de cambios que se paso
        String conjunto = ApexPages.currentPage().getParameters().get('conjunto');
        
        //Obtenemos el tipo de objeto por su id
        tipoObjeto = getTipoObjetoById(idObjeto);
        
        //Seteamos el conjunto de cambios
        conjuntoDeCampos = readFieldSet(conjunto , tipoObjeto);
        
        //Obtenemos el objeto
        objeto = getObject(idObjeto, conjuntoDeCampos);
        
    }
    
    private static List<Schema.FieldSetMember> readFieldSet(String fieldSetName, String ObjectName){
        
        Map<String, Schema.SObjectType> GlobalDescribeMap = Schema.getGlobalDescribe(); 
        
        Schema.SObjectType SObjectTypeObj = GlobalDescribeMap.get(ObjectName);
        
        Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();
    
        Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.FieldSets.getMap().get(fieldSetName);
    
        return fieldSetObj.getFields(); 
    }  
    
    private static String getTipoObjetoById(Id idObjeto){
        
        return String.valueOf(idObjeto.getSObjectType());
        
    }
    
    private sObject getObject(Id id, List<Schema.FieldSetMember> conjuntoDeCampos){
       
        //Objeto a retornar
        sObject objeto= null;
        
        //Armamos una query
        String query = '';
        
        //Armamos el select
        query += 'SELECT'+' ';
        
        for(Integer i = 0 ; i < conjuntoDeCampos.size() ; i++){
            if(i!=0)
               query += ','+' '; 
            query += String.valueOf(conjuntoDeCampos[i].getFieldPath());
        }
        
        //Armamos el from
        query += ' '+'FROM'+' '+tipoObjeto;
        
        //Armamos el where
        query += ' '+'WHERE'+' '+'Id'+' '+'='+' '+':id';
        
        List<sObject> objetos = Database.Query(query);
        
        if(objetos.size() > 0)
            objeto = objetos.get(0);
        
        return objeto;
    }

}