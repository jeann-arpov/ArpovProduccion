trigger tg_Case on Case (before insert, after update,  after insert) {
    //Test_UtilsCasos
    if (Trigger.isBefore && Trigger.isInsert) {
        Map<String, String> portales = new Map<String, String> {
            'Portal ArPOV' => 'SREP',
            'Portal Distribuidor' => 'SRED',
            'Sembrá Evolución' => 'SEP',
            'Sembrá Evolución Comercio' => 'SED',
            'Sembrá Evolución Obtentor' => 'SEO'
        };

        String createdIn = 'SF';

        if (Network.getNetworkId() != null) {
            createdIn = portales.get([select name from network where id =: Network.getNetworkId()].name);
        }

        for (Case c: Trigger.new) {
            c.Creado_En__c = createdIn;
        }
    }
    
    if(Trigger.isAfter){
        
        // Lista que contendra los casos hijos abiertos
        List<Case> casosAbiertos = new List<Case>();

        if(Trigger.isInsert){
            for(Case caso : Trigger.new){
                if(caso.Status == 'Abierto' && caso.ParentId != null)
                    casosAbiertos.add(caso);
            }
        }

        if(Trigger.isUpdate){
            
            //Lista que contendra los casos que han pasado a estado Cerrado
            List<Case> casosCerrados = new List<Case>();
        
            
            for(Case caso : Trigger.new){
                
                //Si el caso es hijo y paso a estado cerrado, lo colecciono
                if(caso.Status == 'Cerrado' && Trigger.oldMap.get(caso.Id).Status != 'Cerrado' && caso.ParentId != null){
                    
                    //Colecciono el caso
                    casosCerrados.add(caso);
                    
                }

                if(caso.Status == 'Abierto' && caso.ParentId != null && Trigger.oldMap.get(caso.Id).Status != 'Abierto')
                    casosAbiertos.add(caso);
                
            }
            
            if(casosCerrados.size() > 0){
                UtilsCasos.cerrarCasosPadres(casosCerrados);
            }
        }


        if(!casosAbiertos.isEmpty())
            UtilsCasos.abrirCasosPadres(casosAbiertos);
        
    }


    
}