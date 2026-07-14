/**
* @author Maximo Martinez
* @date 15/07/2014
* @description Clase con Metodos Utilitarios para el Objeto Campana_Agricola__c
*/
public with sharing class UtilsCampanaAgricola{
    
    /**
    * @description Método que a partir de un listado de campanas agricolas 
    * actualiza a Completa, a la campana anterior
    * @param lista: Campañas Agricolas que serán procesadas
    */
    public static void setearCampanaAnteriorACompleta(List<Campana_Agricola__c> lista){
        
        //Recorro las campanas agricolas
        
        //Set para coleccionar las campanas agricolas anteriores
        Set<Id> idsCampanas = new Set<Id>();
        
        for(Campana_Agricola__c ca : lista){
            
            //Si la campaña agricola esta en estado activa, coleccionamos la campaña anterior
            //para pasarla a estado completa
            if(ca.Estado__c == 'Activa' && ca.Nombre_de_Campana_Anterior__c != null){
                
                idsCampanas.add(ca.Nombre_de_Campana_Anterior__c);
                
            }
            
        }
        
        
        //Obtenemos las campañas anteriores que no esten en estado 'Completa'
        
        //Lista que contendra
        List<Campana_Agricola__c> toUpdate = new List<Campana_Agricola__c>();
        
        for(Campana_Agricola__c ca : [SELECT Id, Estado__c FROM Campana_Agricola__c WHERE Id IN :idsCampanas AND Estado__c != 'Completa']){
            
            //Seteamos el estado a completa
            ca.Estado__c = 'Completa';
            
            //Agregamos la campaña a la lista de campañas a actualizar
            toUpdate.add(ca);
            
        }
        
        if(toUpdate.size() > 0){
            updateList(toUpdate);
        }
        
    }
    
    /**
    * @description Método que a partir de un listado de campanas agricolas 
    * las actualiza en la Base de Datos en lotes de no mas de 200 registros
    * @param lista: Campañas Agricolas que serán procesadas
    */
    public static void updateList(List<Campana_Agricola__c> lista){
        List<Campana_Agricola__c> toUpdate = new List<Campana_Agricola__c>();
        for(Campana_Agricola__c c : lista){
            toUpdate.add(c);
        
            if(toUpdate.size() == 200){
                update toUpdate;
                toUpdate.clear();
            }
        }
        
        if(toUpdate.size() > 0){
            update toUpdate;
            toUpdate.clear();
        }

    }

}