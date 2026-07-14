public with sharing class UtilsRemesa {

	public static void setearContactoRemesaEnviado(List<Task> lista){

        //Coleccionamos el whatid de cada task
        Map<Id,Set<Id>> taskByWhatIds = new Map<Id,Set<Id>>();

        for(Task t : lista){

            if(t.WhatId != null){
                if(!taskByWhatIds.containsKey(t.WhatId)){
                    taskByWhatIds.put(t.WhatId,new Set<Id>());
                }
                taskByWhatIds.get(t.WhatId).add(t.Id);
            }

        }

        //Lista que contendra las remesas 
        Set<Id> contactosRemesa = new Set<Id>();

        //Recorremos los Ids y verificamos cuales corresponden a objetos de contacto Remesa
        for(Id id : taskByWhatIds.keySet()){

            if(String.valueOf(id.getSObjectType()) == 'Contacto_Remesa__c'){
                contactosRemesa.add(id);
            }

        }


        for(List<Contacto_Remesa__c> contactos : [SELECT Id FROM Contacto_Remesa__c WHERE Id IN :contactosRemesa]){

            for(Contacto_Remesa__c contacto : contactos){
                
                //Seteamos la fecha de envio
                contacto.Fecha_de_envio__c = Datetime.now();

                //Seteamos el estado a enviada
                contacto.Estado__c = 'Enviado';
            
            }

            update contactos;

        }


    }

}