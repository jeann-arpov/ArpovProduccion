/**
* @author Maximo Martinez
* @date 20/12/2019
* @description Clase que maneja los eventos sobre el trigger tg_Attachment y los distribuye en los métodos pertinentes.
*/
public class AttachmentTriggerHandler extends TriggerHandler{
    
    public override void afterInsert() {
        new GestionDeCuentasController().attachToInteracciones((List<Attachment>)Trigger.new, (Map<Id,Attachment>)Trigger.oldMap);
    }

}