public class EstablecimientoTriggerHandler {
    @TestVisible static Boolean shouldRun = !Test.isRunningTest();
    private static Map<String, Id> keysExists = new Map<String, Id>();

    public static void run(){
        if(!shouldRun) return;

        List<Establecimiento__c> toInsert = getEstablecimientosToInsert();

        for(Establecimiento__c establecimiento : toInsert){
            if(establecimiento.Coordenadas__latitude__s > 0 || establecimiento.Coordenadas__longitude__s > 0){
                establecimiento.addError('Las coordenadas deben ser negativas');
            }
        }

        if(Site.getSiteType() != null){
            Id accountId = CrearCompraController.getAccount().Id;
    
            for(Establecimiento__c establecimiento : toInsert){
                if(establecimiento.Productor__c == null){
                    establecimiento.Productor__c = accountId;
                }
            }
        }

        for(Establecimiento__c establecimiento : [SELECT Name, Coordenadas__latitude__s, Coordenadas__longitude__s FROM Establecimiento__c WHERE Productor__c = :toInsert[0].Productor__c AND Origen__c = 'Propio']){
            keysExists.put(establecimiento.Name + String.valueOf(establecimiento.Coordenadas__latitude__s) + String.valueOf(establecimiento.Coordenadas__longitude__s), establecimiento.Id);
        }

        for(Establecimiento__c establecimiento : toInsert){
            if(establecimiento.Origen__c == 'Propio'){
                String key = establecimiento.Name + String.valueOf(establecimiento.Coordenadas__latitude__s) + String.valueOf(establecimiento.Coordenadas__longitude__s);
    
                if(keysExists.get(key) != null && keysExists.get(key) != establecimiento.Id){
                    establecimiento.addError('Registro duplicado: No se puede agregar más de un establecimiento con el mismo nombre y coordenadas (' + establecimiento.Name + ')');
                }else{
                    keysExists.put(key, establecimiento.Id);
                }
            }
        }
    }

    public static List<Establecimiento__c> getEstablecimientosToInsert(){
        return (List<Establecimiento__c>) Trigger.new;
    }
}