/**
* @author Maximo Martinez
* @date 12/11/2019
* @description Clase con clases que se usan para deserializar
*/
public with sharing class SalesforceModel {
   
    /**
	* @author Maximo Martinez
	* @date 27/09/2019
	* @description Custom Exception
	*/
    public class ListViewDescribeResult {

        @AuraEnabled
        public Id id { get; set; }

        @AuraEnabled
        public String query { get; set; }

        @AuraEnabled
        public String sobjectType { get; set; }

        @AuraEnabled
        public List<Map<String, String>> columns { get; set; }

    }

	/**
	* @author Maximo Martinez
	* @date 15/01/2019
	* @description Descriptor del layout
	*/
	public class LayoutDescribeResult{
		@AuraEnabled
		public List<LayoutSection> detailLayoutSections {get; set;}
		@AuraEnabled
		public List<RelatedList> relatedLists {get; set;}
	}

	/**
	* @author Maximo Martinez
	* @date 15/01/2019
	* @description Seccion del layout
	*/
	public class LayoutSection{
		@AuraEnabled
		public Integer columns {get; set;}
		@AuraEnabled
		public String heading {get; set;}
		@AuraEnabled
		public List<LayoutRow> layoutRows {get; set;}
	}

	/**
	* @author Maximo Martinez
	* @date 15/01/2019
	* @description Fila del layout
	*/
	public class LayoutRow{
		@AuraEnabled
		public Integer numItems {get;set;}
		@AuraEnabled
		public List<LayoutItem> layoutItems {get; set;}
	}

	/**
	* @author Maximo Martinez
	* @date 15/01/2019
	* @description Item de la fila del layout
	*/
	public class LayoutItem{
		@AuraEnabled
		public Boolean editableForNew {get; set;}
		@AuraEnabled
		public Boolean editableForUpdate {get; set;}
		@AuraEnabled
		public String label {get; set;}
		@AuraEnabled
		public List<LayoutComponent> layoutComponents {get; set;}
		@AuraEnabled
		public Boolean placeholder {get; set;}
		@AuraEnabled
		public Boolean required {get; set;}
	}

	/**
	* @author Maximo Martinez
	* @date 15/01/2019
	* @description Componente del item de la fila del layout
	*/
	public class LayoutComponent{
		@AuraEnabled
		public LayoutComponentDetail details {get; set;}
	}

	/**
	* @author Maximo Martinez
	* @date 15/01/2019
	* @description Detalle del componente del item de la fila del layout
	*/
	public class LayoutComponentDetail extends DescribeFieldResult{
		@AuraEnabled
		public String relationshipName {get; set;}
		@AuraEnabled
		public String soapType {get; set;}
		@AuraEnabled
		public Boolean updateable {get; set;}
	}

    /**
    * @author Maximo Martinez
    * @date 02/12/2019
    * @description Clase auxiliar para pasar al input field usado en el recordedit form
    */
    public virtual class DescribeFieldResult{

        @AuraEnabled
        public Boolean isRequired {get; set;}
        
        @AuraEnabled
        public String label {get; set;}

        @AuraEnabled
        public String name {get; set;}

        @AuraEnabled
        public Integer length {get; set;}

        @AuraEnabled 
        public String type {get; set;}

        @AuraEnabled 
        public Integer digits {get; set;}

        @AuraEnabled 
        public Integer scale {get; set;}

        @AuraEnabled 
        public Integer precision {get; set;}

	}
	
	/**
	* @author Maximo Martinez
	* @date 05/06/2020
	* @description Related List
	*/
	public class RelatedList{
		@AuraEnabled
		public Boolean custom {get; set;}
		@AuraEnabled
		public String field {get; set;}
		@AuraEnabled
		public String label {get; set;}
		@AuraEnabled
		public Integer limitRows {get; set;}
		@AuraEnabled
		public String name {get; set;}
		// @AuraEnabled
		// public String sobject {get; set;}
		@AuraEnabled
		public List<Column> columns {get; set;}
	}

	/**
	* @author Maximo Martinez
	* @date 05/06/2020
	* @description Column
	*/
	public class Column{
		@AuraEnabled
		public String field {get; set;}
		@AuraEnabled
		public String fieldApiName {get; set;}
		@AuraEnabled
		public String format {get; set;}
		@AuraEnabled
		public String label {get; set;}
		@AuraEnabled
		public String lookupId {get; set;}
		@AuraEnabled
		public String name {get; set;}
		@AuraEnabled
		public Boolean sortable {get; set;}
	}

	/**
	* @author Maximo Martinez
	* @date 08/06/2020
	* @description Custom Exception
	*/
	public class Sortx{
		@AuraEnabled
		public Boolean ascending {get; set;}
		@AuraEnabled
		public String column {get; set;}
	}


}