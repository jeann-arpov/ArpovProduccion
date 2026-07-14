/**
* @author Maximo Martinez
* @date 09/09/2020
* @description Helper class for lightning components
*/
public with sharing class AuraHelper {

    /**
    * @author Maximo Martinez
    * @date 11/08/2020
    * @description Method for getting a field set member list
    */
    @AuraEnabled(cacheable = true)
    public static List<FieldSetMember> getFieldSetFieldsByFieldSetName(String objectApiName, String fieldSetName){
        List<Schema.FieldSetMember> fieldSetMembers = ((SObject)Type.forName(objectApiName).newInstance()).getSObjectType().getDescribe().FieldSets.getMap().get(fieldSetName).getFields();
        List<FieldSetMember> fields = new List<FieldSetMember>();

        for (Schema.FieldSetMember fieldSetMember : fieldSetMembers){
            FieldSetMember fSetMember = new FieldSetMember(fieldSetMember);
            fields.add(fSetMember);
        }

        return fields;
    }

    /**
    * @author Maximo Martinez
    * @date 11/08/2020
    * @description 
    */
    public class FieldSetMember{
        
        @AuraEnabled
        public Boolean dbrequired;

        @AuraEnabled
        public String fieldpath;
        
        @AuraEnabled
        public String label;
        
        @AuraEnabled
        public Boolean required;

        @AuraEnabled
        public Boolean isNameField;

        public FieldSetMember(Schema.FieldSetMember fieldSetMember){
            this.dbrequired = fieldSetMember.getDbRequired();
            this.fieldpath = fieldSetMember.getFieldPath();
            this.label = fieldSetMember.getLabel();
            this.required = fieldSetMember.getRequired();
            this.isNameField = fieldSetMember.getSObjectField().getDescribe().isNameField();
        }

    }

}