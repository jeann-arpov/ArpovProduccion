public with sharing class InteraccionTriggerHandler extends TriggerHandler{
	
	public override void beforeInsert(){
		UtilsAccount.setearPrioridades(Trigger.new);
	}
}