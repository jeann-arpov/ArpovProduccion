/*
    Clase Auxiliar utilizada en el Trigger tg_Opportunity, encargada de cerrar las task
    asociadas a la factura
*/

public with sharing class CerrarTasksDesdeFacturas{
    
    //Atributo que contiene el subject de las task a cerrar
    public static final String ASUNTO = 'Enviar Liquidacion';
    
    //Atributo que contiene el status de cierre de una task
    public static final String CLOSE_STATUS = 'Cerrada';
    
    //Metodo encargado de procesar las tasks
    public static void cerrarTasks(Set<Id> idsOportunidades){
        
        //Lista de tareas a cerrar
        List<Task> taskToUpdate = new List<Task>();
        
        //Recorremos las oportunidades
        for(Opportunity oportunidad : [SELECT Id, (SELECT Id, Subject, Status FROM Tasks) FROM Opportunity WHERE Id IN :idsOportunidades]){
            
            //Por cada oportunidad recorremos sus tasks
            for(Task tarea : oportunidad.Tasks){
                
                //Si el Subject es igual a la constante ASUNTO la cerramos
                if(tarea.Subject == ASUNTO && tarea.Status != CLOSE_STATUS){
                    
                    //Cambiamos su Status a Cerrada
                    tarea.Status = CLOSE_STATUS; 
                    
                    //Agregamos las Task a la lista de tasks a utilizar
                    taskToUpdate.add(tarea);
                }
                
            }
            
        }
        
        //Actualizamos las tareas (si hubiera) 
        if(taskToUpdate.size() > 0){
        
            updateList(taskToUpdate);
        
        }
        
        
    }
    
    //Metodo para actualizacion de tareas por lote
    public static void updateList(List<Task> tareas){
        
        List<Task> toUpdate = new List<Task>();
        for(Task t : tareas){
            toUpdate.add(t);
        
            if(toUpdate.size() == 200){
                update toUpdate;
                toUpdate.clear();
            }
        }
        
        if(toUpdate.size() > 0){
            update toUpdate;
            toUpdate.clear();
        }

        
    }
    
}