/**
 * Nombre: RegistrarGestionController
 * Descripción: Controlador para registrar gestiones de llamadas/contactos
 * Autor: Sistema
 * Fecha: 2026-03-04
 */
public with sharing class RegistrarGestionController {
    
    /**
     * Obtiene el próximo número de gestión secuencial
     */
    @AuraEnabled(cacheable=false)
    public static Integer obtenerProximoNumeroGestion() {
        try {
            // Generar número aleatorio entre 1000 y 99999
            Integer numeroGestion = (Integer)(Math.random() * 99000) + 1000;
            return numeroGestion;
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener número de gestión: ' + e.getMessage());
        }
    }
    
    /**
     * Guarda una nueva gestión como Task
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> guardarGestion(String recordId, String numeroGestion, String celular, 
                                                   String medio, String inicio, String respuesta, String comentario) {
        try {
            Map<String, Object> resultado = new Map<String, Object>();
            
            // Obtener el RecordType de Expediente_de_Negativos
            RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Task' AND DeveloperName = 'Expediente_de_Negativos' LIMIT 1];
            
            // Crear la nueva Task
            Task nuevaTarea = new Task();
            nuevaTarea.Subject = 'Registrar gestion';
            nuevaTarea.Status = 'Completed';
            nuevaTarea.TaskSubtype = 'Call';
            nuevaTarea.Description = comentario;
            nuevaTarea.RecordTypeId = rt.Id;
            nuevaTarea.WhatId = recordId; // Asociar con el registro actual
            
            // Campos custom (asumiendo que existen)
            // Nota: Estos campos deben crearse en el org si no existen
            if (Schema.getGlobalDescribe().get('Task').getDescribe().fields.getMap().containsKey('Numero_Gestion__c')) {
                nuevaTarea.put('Numero_Gestion__c', numeroGestion);
            }
            if (Schema.getGlobalDescribe().get('Task').getDescribe().fields.getMap().containsKey('Celular__c')) {
                nuevaTarea.put('Celular__c', celular);
            }
            if (Schema.getGlobalDescribe().get('Task').getDescribe().fields.getMap().containsKey('Medio__c')) {
                nuevaTarea.put('Medio__c', medio);
            }
            if (Schema.getGlobalDescribe().get('Task').getDescribe().fields.getMap().containsKey('Inicio__c')) {
                nuevaTarea.put('Inicio__c', inicio);
            }
            if (Schema.getGlobalDescribe().get('Task').getDescribe().fields.getMap().containsKey('Respuesta__c')) {
                nuevaTarea.put('Respuesta__c', respuesta);
            }
            
            insert nuevaTarea;
            
            resultado.put('success', true);
            resultado.put('taskId', nuevaTarea.Id);
            resultado.put('message', 'Gestión ' + numeroGestion + ' registrada correctamente');
            
            return resultado;
            
        } catch (Exception e) {
            Map<String, Object> errorResult = new Map<String, Object>();
            errorResult.put('success', false);
            errorResult.put('message', 'Error al guardar gestión: ' + e.getMessage());
            return errorResult;
        }
    }
    
    /**
     * Obtiene las opciones de respuesta disponibles
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> obtenerOpcionesRespuesta() {
        try {
            List<Map<String, String>> opciones = new List<Map<String, String>>();
            
            opciones.add(new Map<String, String>{'label' => 'Contactado', 'value' => 'Contactado'});
            opciones.add(new Map<String, String>{'label' => 'No Contactado', 'value' => 'No_Contactado'});
            opciones.add(new Map<String, String>{'label' => 'Contestador', 'value' => 'Contestador'});
            opciones.add(new Map<String, String>{'label' => 'Rechazo', 'value' => 'Rechazo'});
            opciones.add(new Map<String, String>{'label' => 'Interesado', 'value' => 'Interesado'});
            opciones.add(new Map<String, String>{'label' => 'No Interesado', 'value' => 'No_Interesado'});
            
            return opciones;
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener opciones: ' + e.getMessage());
        }
    }
}