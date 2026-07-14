/**
* @author Maximo Martinez
* @date 24/10/2014
* @description Metodo que contiene metodos auxiliares de la clase Item Auditoria
*/
public with sharing class UtilsItemAuditoria {
	/**
    * @author Maximo Martinez
    * @date 24/10/2014
    * @description Metodo de Insert por lotes
    */
    public static void insertList(List<Item_Auditoria__c> lista){
        
        List<Item_Auditoria__c> toInsert = new List<Item_Auditoria__c>();
        
        for(Item_Auditoria__c o : lista){
            toInsert.add(o);
                
            if(toInsert.size() == 200){
                insert toInsert;
                toInsert.clear();
            }
        }

        if(toInsert.size() > 0){
            insert toInsert;
            toInsert.clear();
        }
        
    }
}