/**
* @author Maximo Martinez
* @date 02/06/2020
* @description Clase utilitaria para obtener registros
*/
public with sharing class QueryBuilder{

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Contiene el sobject type del sobject a filtrar
    */
    private Schema.SObjectType sObjectType;

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Set con ids a filtrar
    */
    private Set<Id> ids;

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Contiene el field set a usar en la query
    */
    private Schema.FieldSet fieldSet;
    
    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Asigna el SObject por el que se va a filtrar
    */
    public QueryBuilder get(Schema.SObjectType sObjectType){
        this.sObjectType = sObjectType; 
        return this;
    }

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Asigna el SObject por el que se va a filtrar
    */
    public QueryBuilder get(String sObjectType){
        this.sObjectType = Schema.getGlobalDescribe().get(sObjectType); 
        return this;
    }

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Asigna los ids por los que se va a filtrar
    */
    public QueryBuilder filteringByIds(Set<Id> ids){
        this.ids = ids;
        return this;
    }

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Asigna el field set por el que se va a filtrar
    */
    public QueryBuilder usingFieldSet(String fieldSetApiName){
        return usingFieldSet(this.sObjectType.getDescribe().fieldSets.getMap().get(fieldSetApiName));
    }

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Asigna el field set por el que se va a filtrar
    */
    public QueryBuilder usingFieldSet(Schema.FieldSet fieldSet){
        this.fieldSet = fieldSet;
        return this;
    }

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Devuelve la lista de registros a filtrar
    */
    public List<SObject> getRecords(){
        return Database.query(buildQuery());
    }

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Arma la query para realizar la consulta a partir de los parametros pasados en el builder
    */
    private String buildQuery(){

        Set<String> fields = new Set<String>();

        String query;

        for(Schema.FieldSetMember fSetMember : this.fieldSet.getFields()){
            fields.add(fSetMember.fieldpath);
        }

        query = String.format('SELECT {0} FROM {1}', new List<String>{String.join(new List<String>(fields),','),sObjectType.getDescribe().getName()});

        if(this.ids != null){
            query += String.format(' WHERE {0} {1} {2}', new List<String>{'Id','IN',':ids'});
        }

        System.debug(query);

        return query;

    }

}