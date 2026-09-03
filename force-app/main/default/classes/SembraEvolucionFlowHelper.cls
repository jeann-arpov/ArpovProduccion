public with sharing class SembraEvolucionFlowHelper {

    // Clase contenedora para los parámetros de entrada desde el Flujo
    public class Request {
        @InvocableVariable(label='ID de la Cuenta (Productor)' required=true)
        public Id accountId;

        @InvocableVariable(label='ID de la Variedad' required=true)
        public Id variedadId;
    }

    @InvocableMethod(
        label='Evaluar Sembra Evolución para Cuenta y Variedad' 
        description='Determina si una combinación de Cuenta y Variedad se comporta como Sembra_Evolucion__c = true'
    )
    public static List<Boolean> evaluarSembraEvolucion(List<Request> requests) {
        List<Boolean> results = new List<Boolean>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> accountIds = new Set<Id>();
        Set<Id> variedadIds = new Set<Id>();

        // Recolectar IDs para masificar la consulta
        for (Request req : requests) {
            if (req.accountId != null) {
                accountIds.add(req.accountId);
            }
            if (req.variedadId != null) {
                variedadIds.add(req.variedadId);
            }
        }

        // 1. Consultar si la Variedad de por sí tiene Sembra_Evolucion__c = true
        Map<Id, Boolean> variedadSembraMap = new Map<Id, Boolean>();
        if (!variedadIds.isEmpty()) {
            for (Variedad__c var : [SELECT Id, Sembra_Evolucion__c FROM Variedad__c WHERE Id IN :variedadIds]) {
                variedadSembraMap.put(var.Id, var.Sembra_Evolucion__c == true);
            }
        }

        // 2. Consultar las excepciones/registros existentes en Variedad_SRE_por_Productor__c
        Set<String> excepcionesSet = new Set<String>();
        if (!accountIds.isEmpty() && !variedadIds.isEmpty()) {
            for (Variedad_SRE_por_Productor__c sre : [
                SELECT Cuenta__c, Variedad__c 
                FROM Variedad_SRE_por_Productor__c 
                WHERE Cuenta__c IN :accountIds 
                  AND Variedad__c IN :variedadIds
            ]) {
                // Clave única para búsqueda rápida: AccountId_VariedadId
                excepcionesSet.add(sre.Cuenta__c + '_' + sre.Variedad__c);
            }
        }

        // 3. Evaluar cada solicitud recibida del Flujo
        for (Request req : requests) {
            Boolean esSembra = false;

            // Criterio 1: La variedad tiene Sembra_Evolucion__c = true a nivel general
            if (req.variedadId != null && variedadSembraMap.containsKey(req.variedadId) && variedadSembraMap.get(req.variedadId)) {
                esSembra = true;
            } 
            // Criterio 2: Existe el registro en Variedad_SRE_por_Productor__c para esta combinación
            else if (req.accountId != null && req.variedadId != null) {
                String key = req.accountId + '_' + req.variedadId;
                if (excepcionesSet.contains(key)) {
                    esSembra = true;
                }
            }

            results.add(esSembra);
        }

        return results;
    }
}