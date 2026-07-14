trigger tg_EmailMessage on EmailMessage (before insert,before update,before delete,after insert,after update,after delete,after undelete) {
	new EmailMessageTriggerHandler().run();
}