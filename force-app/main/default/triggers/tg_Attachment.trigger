trigger tg_Attachment on Attachment (before insert,before update,before delete,after insert,after update,after delete,after undelete){
    new AttachmentTriggerHandler().run();
}