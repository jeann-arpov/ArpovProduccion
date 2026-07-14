/**
* @author Maximo Martinez
* @date 20/12/2019
* @description Clase que maneja los eventos sobre el trigger tg_Task y los distribuye en los métodos pertinentes.
*/
public class TaskTriggerHandler extends TriggerHandler{
    
    public override void beforeInsert() {
        UtilsTask.setearOperadorRemesa(Trigger.new);
    }

    public override void afterInsert() {
        UtilsTask.AdjuntaAttachments(Trigger.new);
        UtilsTask.gestionarCasos(Trigger.new); 
        UtilsRemesa.setearContactoRemesaEnviado(Trigger.new);  
        new GestionDeCuentasController().createGestionesFromSObjects((List<Task>)Trigger.new,(Map<Id,Task>)Trigger.oldMap);
    }

}