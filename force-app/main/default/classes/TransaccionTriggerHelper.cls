public with sharing class TransaccionTriggerHelper {

    public static void syncWithHzpc(List<Transaccion__c> transacciones, TriggerOperation context){
        Map<Id, Transaccion__c> dups = new Map<Id, Transaccion__c>(transacciones);

        if(dups.isEmpty() == false){
            if(context == TriggerOperation.BEFORE_DELETE){
                HzpcSync.doSyncDeleteTransacciones(JSON.serialize(getHzpcIds(dups.values())));
            }else{
                System.enqueueJob(new QueueableSyncHzpc(dups.keySet(), context));
            }
        }
    }

    public static Set<String> getHzpcIds(List<Transaccion__c> transacciones){
        Set<String> hzpcIds = new Set<String>();
        for(Transaccion__c transaccion : transacciones){
            hzpcIds.add(transaccion.HZPCId__c);
        }
        return hzpcIds;
    }

    //lógica que ya estaba en el trigger de transaccion para insert antes de desarrollar la integración con hzpc
    public static void processTransaccionesInsertOld(List<Transaccion__c> transacciones){
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        Id rtAud = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');

        Set<Id> idsNegativas = new Set<Id>();
        List<Transaccion__c> auditorias = new List<Transaccion__c>();
        List<Transaccion__c> audsToCancelDUPS = new List<Transaccion__c>();

        for(Transaccion__c transaccion : transacciones){

            if(transaccion.Subestado__c == 'Negativa'){
                idsNegativas.add(transaccion.Id);
            }
            
            //Si la transaccion tiene una DUP original y el campo Cancela_DUP_Original__c en true
            //agregamos al set su DUP original
            if(transaccion.Cancela_DUP_Original__c == true && transaccion.DUP_Original__c != null && transaccion.Estado__c != 'Borrador'){
                audsToCancelDUPS.add(transaccion);
            }
            
            //Si la transaccion es una auditoria y su estado es Justificada, coleccionamos su id    
            if(transaccion.RecordTypeId == rtAud && transaccion.Estado__c == 'Justificada'){
                auditorias.add(transaccion);
            }
        }

        //Si tenemos transacciones negativas
        if(idsNegativas.size() > 0) UtilsTransaccion.asignaTipoCambioTransaccionNegativa(idsNegativas);

        if(audsToCancelDUPS.size()>0) UtilsTransaccion.cancelarDups(audsToCancelDUPS);

        if(auditorias.size() > 0) UtilsTransaccion.generarNCAuditorias(auditorias);

        UtilsTransaccion.envioDeDUPPorMail(transacciones, null);
    }

    //lógica que ya estaba en el trigger de transaccion antes de desarrollar la integración con hzpc
    public static void processTransaccionesUpdateOld(List<Transaccion__c> oldTransacciones, List<Transaccion__c> transacciones){
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        Id rtAud = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');
        
        Set<Id> idsNegativas = new Set<Id>();
        List<Transaccion__c> transaccionesDUP = new List<Transaccion__c>();
        List<Transaccion__c> dupsCanceladasPorAud = new List<Transaccion__c>();
        List<Transaccion__c> audsToCancelDUPS = new List<Transaccion__c>();
        List<Transaccion__c> auditorias = new List<Transaccion__c>();

        Map<Id, Transaccion__c> oldMap = new Map<Id, Transaccion__c>(oldTransacciones);

        for(Transaccion__c transaccion : transacciones){
            if(transaccion.Subestado__c == 'Negativa' && transaccion.DUP_Original__c != oldMap.get(transaccion.Id).DUP_Original__c){
                idsNegativas.add(transaccion.Id);
            }
            
            //Logica para cerrar casos de las DUPS
            if(transaccion.Estado__c != oldMap.get(transaccion.Id).Estado__c && (transaccion.Estado__c == 'Respondida' || transaccion.Estado__c == 'Respondida Parcialmente')){
                if(transaccion.Subestado__c == 'Positiva'){
                    transaccionesDUP.add(transaccion);
                }
            }
    
            //Logica para obtener DUP Canceladas por Auditoria
            if(transaccion.Estado__c == 'Cancelada por Auditoría' && transaccion.Auditoria__c != null && (transaccion.Estado__c != oldMap.get(transaccion.Id).Estado__c) && (transaccion.Auditoria__c != oldMap.get(transaccion.Id).Auditoria__c)){
                dupsCanceladasPorAud.add(transaccion);
            }
        
            //Si la transaccion tiene una DUP original y el campo Cancela_DUP_Original__c en true
            //agregamos al set su DUP original
            if(transaccion.Cancela_DUP_Original__c == true && transaccion.DUP_Original__c != null && transaccion.Estado__c != 'Borrador'){
                if(transaccion.Cancela_DUP_Original__c != oldMap.get(transaccion.Id).Cancela_DUP_Original__c || transaccion.DUP_Original__c != oldMap.get(transaccion.Id).DUP_Original__c || transaccion.Estado__c != oldMap.get(transaccion.Id).Estado__c){
                    audsToCancelDUPS.add(transaccion);
                } 
            }
        
            //Si la transaccion es una auditoria y su estado es Justificada, coleccionamos su id    
            if(transaccion.RecordTypeId == rtAud && transaccion.Estado__c == 'Justificada' && transaccion.Estado__c != oldMap.get(transaccion.Id).Estado__c){
                auditorias.add(transaccion);
            }
        }

        if(transaccionesDUP.size() > 0) UtilsCasos.cerrarCasosFromDups(transaccionesDUP);

        if(idsNegativas.size() > 0) UtilsTransaccion.asignaTipoCambioTransaccionNegativa(idsNegativas);

        if(dupsCanceladasPorAud.size() > 0) UtilsCasos.cerrarCasosFromDups(dupsCanceladasPorAud);

        if(audsToCancelDUPS.size()>0) UtilsTransaccion.cancelarDups(audsToCancelDUPS);

        if(auditorias.size() > 0) UtilsTransaccion.generarNCAuditorias(auditorias);

        UtilsTransaccion.envioDeDUPPorMail(transacciones, oldMap);
    }
}