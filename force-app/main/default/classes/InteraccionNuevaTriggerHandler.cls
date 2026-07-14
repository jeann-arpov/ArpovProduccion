public with sharing class InteraccionNuevaTriggerHandler extends TriggerHandler{
	
	public override void beforeInsert(){
		new GestionDeCuentasController().setUltimoResultadoGestion(Trigger.new);
	}

}