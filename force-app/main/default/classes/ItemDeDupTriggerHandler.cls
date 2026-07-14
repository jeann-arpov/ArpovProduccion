public with sharing class ItemDeDupTriggerHandler {

    public static void run(){
        switch on Trigger.operationType {
            when BEFORE_INSERT {
                beforeInsert(Trigger.new);
            }
            when AFTER_INSERT{
                afterInsert(Trigger.new);
            }
            when BEFORE_UPDATE{
                if(isSyncUpdate(Trigger.old, Trigger.new) == false){
                    beforeUpdate(Trigger.old, Trigger.new);
                }
            }
            when AFTER_UPDATE {
                if(isSyncUpdate(Trigger.old, Trigger.new) == false){
                    afterUpdate(Trigger.old, Trigger.new);
                }
            }
            when BEFORE_DELETE{
                beforeDelete(Trigger.old);
            }
            when AFTER_DELETE {
                afterDelete(Trigger.old);
            }
        }
    }

    public static void beforeInsert(List<Item_de_DUP__c> newRecords){
        ItemDeDupTriggerHelper.processItemsDupBeforeInsertOld(newRecords);
    }

    public static void afterInsert(List<Item_de_DUP__c> newRecords){
        ItemDeDupTriggerHelper.processItemsDupAfterInsertOld(newRecords);
        if(Hzpc_Integracion__c.getOrgDefaults().Sync_Active__c){
            ItemDeDupTriggerHelper.syncWithHzpc(getItemsToSync(newRecords, Trigger.operationType), Trigger.operationType);
        }
    }

    public static void beforeUpdate(List<Item_de_DUP__c> oldRecords, List<Item_de_DUP__c> newRecords){
        ItemDeDupTriggerHelper.processItemsDupBeforeUpdateOld(oldRecords, newRecords);
    }

    public static void afterUpdate(List<Item_de_DUP__c> oldRecords, List<Item_de_DUP__c> newRecords){
        ItemDeDupTriggerHelper.processItemsDupAfterUpdateOld(oldRecords, newRecords);
        if(Hzpc_Integracion__c.getOrgDefaults().Sync_Active__c){
            ItemDeDupTriggerHelper.syncWithHzpc(getItemsToSync(newRecords, Trigger.operationType), Trigger.operationType);
        }
    }

    public static void beforeDelete(List<Item_de_DUP__c> oldRecords){
        if(Hzpc_Integracion__c.getOrgDefaults().Sync_Active__c){
            ItemDeDupTriggerHelper.syncWithHzpc(getItemsToSync(oldRecords, Trigger.operationType), Trigger.operationType);
        }
    }

    public static void afterDelete(List<Item_de_DUP__c> oldRecords){
        ItemDeDupTriggerHelper.processItemsDupAfterDelete(oldRecords);
    }

    private static List<Item_de_DUP__c> getItemsToSync(List<Item_de_DUP__c> items, TriggerOperation context){
        List<Item_de_DUP__c> toSync = new List<Item_de_DUP__c>();

        List<Item_de_Dup__c> valid = getItemsHzpc(items);
        if(context == TriggerOperation.AFTER_INSERT){
            return valid;
        }

        for(Item_de_DUP__c item : items){
            if(String.isNotBlank(item.HZPCId__c)){
                toSync.add(item);
            }
        }

        return toSync;
    }

    public static List<Item_de_DUP__c> getItemsHzpc(List<Item_de_DUP__c> items){
        List<Item_de_DUP__c> valid = new List<Item_de_DUP__c>();
        for(Item_de_DUP__c item : items){
            if(item.Id_Obtentor__c == '73'){
                valid.add(item);
            }
        }

        return valid;
    }

    private static boolean isSyncUpdate(List<Item_de_DUP__c> oldRecords, List<Item_de_DUP__c> newRecords){

        Map<Id, Item_de_DUP__c> mapOld = new Map<Id, Item_de_DUP__c>(oldRecords);

        for(Item_de_DUP__c item : newRecords){
            if(String.isBlank(mapOld.get(item.Id).HZPCId__c) && String.isNotBlank(item.HZPCId__c) || String.isBlank(mapOld.get(item.Id).Hzpc_Sync_Error__c) && String.isNotBlank(item.Hzpc_Sync_Error__c)){
                return true;
            }
        }

        return false;
    }
}