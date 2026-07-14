trigger tg_Item_de_DUP on Item_de_DUP__c (before insert, before update, after insert, after update, before delete, after delete) {
   ItemDeDupTriggerHandler.run();
}