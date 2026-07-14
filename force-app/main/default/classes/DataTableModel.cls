/**
* @author Maximo Martinez
* @date 02/06/2020
* @description Clase auxiliar a la clase CustomDataTableModel con objetos utilizados por el componente lightning customDataTable
*/
public with sharing class DataTableModel {
    
    public class Column{

        @AuraEnabled
        public String label {get; set;}
        
        @AuraEnabled
        public String fieldName {get; set;}
        
        @AuraEnabled
        public String type {get; set;}
        
        @AuraEnabled
        public CellAttributes cellAttributes {get; set;}
        
        @AuraEnabled
        public Boolean editable {get; set;}
        
        @AuraEnabled
        public TypeAttributes typeAttributes {get; set;}

        public Column(){}

        public Column(Schema.DescribeFieldResult describeFieldResult){
        	this.type = String.valueOf(describeFieldResult.getType()).toLowerCase();
        	this.fieldName = describeFieldResult.getName();
        	this.label = describeFieldResult.getLabel();
        }

    }

    public class CellAttributes{
    
        @AuraEnabled
        public IconName iconName {get; set;}

        @AuraEnabled
        public String iconPosition {get; set;}
    
    }

    public class IconName{

        @AuraEnabled
        public String fieldName {get; set;}
    
    }

    /**
    * @author Maximo Martinez
    * @date 02/06/2020
    * @description Clase que representa attributos del input field que se renderiza en la datatable del lt component
    */
    public class TypeAttributes{

        @AuraEnabled
        public String year {get; set;}
        
        @AuraEnabled
        public String month {get; set;}
        
        @AuraEnabled
        public String day {get; set;}
        
        @AuraEnabled
        public String target {get; set;}
        
        @AuraEnabled
        public Column label {get; set;}

    }

}