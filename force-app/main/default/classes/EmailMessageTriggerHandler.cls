/**
* @author Maximo Martinez
* @date 25/09/2018
* @description Clase que maneja los eventos sobre el trigger tg_EmailMessage y los distribuye en los métodos pertinentes.
*/
public class EmailMessageTriggerHandler extends TriggerHandler{
	
	public override void afterUpdate() {
		new GestionDeCuentasController().createGestionesFromSObjects((List<EmailMessage>)Trigger.new,(Map<Id,EmailMessage>)Trigger.oldMap);
	}

	public override void afterInsert(){
		new GestionDeCuentasController().createGestionesFromSObjects((List<EmailMessage>)Trigger.new,null);
	}

}