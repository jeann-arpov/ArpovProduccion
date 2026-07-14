public with sharing class TransaccionTriggerHandler {
    
    public static void run(){
        switch on Trigger.operationType {
            when AFTER_INSERT{
                afterInsert(Trigger.new);
            }
            when AFTER_UPDATE {
                if(isSyncUpdate(Trigger.old, Trigger.new) == false){
                    afterUpdate(Trigger.old, Trigger.new);
                }
            }
            when BEFORE_DELETE {
                beforeDelete(Trigger.old);
            }
        }
    }

    public static void afterInsert(List<Transaccion__c> newRecords){
        TransaccionTriggerHelper.processTransaccionesInsertOld(newRecords);
        if(Hzpc_Integracion__c.getOrgDefaults().Sync_Active__c){
            TransaccionTriggerHelper.syncWithHzpc(getTransaccionesToSync(newRecords, Trigger.operationType), Trigger.operationType);
        }
    }

    public static void afterUpdate(List<Transaccion__c> oldRecords, List<Transaccion__c> newRecords){
        TransaccionTriggerHelper.processTransaccionesUpdateOld(oldRecords, newRecords);
        if(Hzpc_Integracion__c.getOrgDefaults().Sync_Active__c){
            TransaccionTriggerHelper.syncWithHzpc(getTransaccionesToSync(newRecords, Trigger.operationType), Trigger.operationType);
        }
    }

    public static void beforeDelete(List<Transaccion__c> oldRecords){
        if(Hzpc_Integracion__c.getOrgDefaults().Sync_Active__c){
            TransaccionTriggerHelper.syncWithHzpc(getTransaccionesToSync(oldRecords, Trigger.operationType), Trigger.operationType);
        }
    }

    private static List<Transaccion__c> getTransaccionesToSync(List<Transaccion__c> transacciones, TriggerOperation context){
        List<Transaccion__c> toSync = new List<Transaccion__c>();

        List<Transaccion__c> valid = getDUPsHZPC(transacciones);

        if(context == TriggerOperation.AFTER_INSERT){
            return valid;
        }

        for(Transaccion__c transaccion : valid){
            if(String.isNotBlank(transaccion.HZPCId__c)){
                toSync.add(transaccion);
            }
        }

        return toSync;
    }

    public static List<Transaccion__c> getDUPsHZPC(List<Transaccion__c> transacciones){
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');

        List<Transaccion__c> dups = new List<Transaccion__c>();
        for(Transaccion__c transaccion : transacciones){
            if(transaccion.RecordTypeId == rtDup && transaccion.Obtentor_Id__c == '73'){
                dups.add(transaccion);
            }
        }

        return dups;
    }

    private static Boolean isSyncUpdate(List<Transaccion__c> oldRecords, List<Transaccion__c> newRecords){
        Map<Id, Transaccion__c> mapOld = new Map<Id, Transaccion__c>(oldRecords);
        Boolean isSyncUpdate = false;
        for(Transaccion__c transaccion : newRecords){
            if(String.isBlank(mapOld.get(transaccion.Id).HZPCId__c) && String.isNotBlank(transaccion.HZPCId__c) || String.isBlank(mapOld.get(transaccion.Id).Hzpc_Sync_Error__c) && String.isNotBlank(transaccion.Hzpc_Sync_Error__c)){
                isSyncUpdate = true;
            }
        }

        return isSyncUpdate;
    }
}