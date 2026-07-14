public with sharing class DocumentoGestionadoTriggerHandler extends TriggerHandler{

	public override void afterInsert(){
		new GestionDeCuentasController().setFechaUltimaGestion(Trigger.new);
	}

	public override void afterUpdate(){
		new GestionDeCuentasController().setFechaUltimaGestion(Trigger.new);
	}

}