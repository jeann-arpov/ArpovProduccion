trigger tg_RelacionEntreCUITs on Relacion_entre_CUITS__c (after insert) {
    if(Trigger.isInsert && Trigger.isAfter && !DisableTrigger.turnedOffAfterInsert){
        List<Relacion_entre_CUITS__c> relacionesNuevas = new List<Relacion_entre_CUITS__c>();
        String rol;
        /*
        Cambio de CUIT (Nuevo) ---> Cambio de CUIT (Original) 
        Cambio de CUIT (Original) ---> Cambio de CUIT (Nuevo) 
        Desglose (Nuevo) ---> Desglose (Originario) 
        Desglose (Originario) ---> Desglose (Nuevo) 
        Fusión (Nuevo) ---> Fusión (Originario) 
        Fusión (Originario) ---> Fusión (Nuevo)                 
        */
        for(Relacion_entre_CUITS__c relacion: Trigger.New){
            if(relacion.Rol__c == 'Cambio de CUIT (Nuevo)')
                rol = 'Cambio de CUIT (Original)';
            else if(relacion.Rol__c == 'Cambio de CUIT (Original)')
                rol = 'Cambio de CUIT (Nuevo)';
            else if(relacion.Rol__c == 'Desglose (Nuevo)')
                rol = 'Desglose (Originario)';
            else if(relacion.Rol__c == 'Desglose (Originario)')
                rol = 'Desglose (Nuevo)';
            else if(relacion.Rol__c == 'Fusión (Nuevo)')
                rol = 'Fusión (Originario)';
            else if(relacion.Rol__c == 'Fusión (Originario)')
                rol = 'Fusión (Nuevo)';

            relacionesNuevas.add(
                new Relacion_entre_CUITS__c(
                    CUIT__c = relacion.CUIT_Anterior__c,
                    CUIT_Anterior__c = relacion.CUIT__c,
                    Rol__c = rol
                )
            );
        }
        if(relacionesNuevas.size() > 0){
            DisableTrigger.turnedOffAfterInsert = true;
            insert relacionesNuevas;
            DisableTrigger.turnedOffAfterInsert = false;
        }
            
    }
}