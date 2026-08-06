public without sharing class VariedadesSREFlowHelper {

    // Clase contenedora para los parámetros de entrada desde el Flow
    public class FlowInput {
        @InvocableVariable(required=true label='ID del Productor / Comercio (Cuenta)')
        public Id productorId;

        @InvocableVariable(required=true label='ID del Obtentor / Marca Comercializadora')
        public Id obtentorId;
    }

    @InvocableMethod(
        label='Asignar Todas las Variedades SRE a Productor (Bulk)' 
        description='Asigna masivamente todas las variedades SRE disponibles a los productores indicados sin exceder límites SOQL/DML.'
    )
    public static void asignarTodasLasVariedades(List<FlowInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            return;
        }

        // 1. Recopilar todos los IDs únicos de la transacción para evitar consultas duplicadas
        Set<Id> obtentorIds = new Set<Id>();
        Set<Id> productorIds = new Set<Id>();

        for (FlowInput input : inputs) {
            if (input.productorId != null && input.obtentorId != null) {
                productorIds.add(input.productorId);
                obtentorIds.add(input.obtentorId);
            }
        }

        if (productorIds.isEmpty() || obtentorIds.isEmpty()) {
            return;
        }

        // 2. Consulta SOQL ÚNICA: Cargar todas las Variedades por Obtentor
        Map<Id, List<Variedad__c>> variedadesPorObtentorMap = new Map<Id, List<Variedad__c>>();
        for (Variedad__c variedad : [
            SELECT Id, Obtentor_Comercializa__c 
            FROM Variedad__c 
            WHERE Obtentor_Comercializa__c IN :obtentorIds 
              AND Sembra_Evolucion__c = false
        ]) {
            if (!variedadesPorObtentorMap.containsKey(variedad.Obtentor_Comercializa__c)) {
                variedadesPorObtentorMap.put(variedad.Obtentor_Comercializa__c, new List<Variedad__c>());
            }
            variedadesPorObtentorMap.get(variedad.Obtentor_Comercializa__c).add(variedad);
        }

        // 3. Consulta SOQL ÚNICA: Cargar todas las asignaciones existentes para este lote
        // Estructura de clave compuesta: "ProductorId_VariedadId"
        Set<String> asignacionesExistentesSet = new Set<String>();
        for (Variedad_SRE_por_Productor__c existente : [
            SELECT Id, Cuenta__c, Variedad__c 
            FROM Variedad_SRE_por_Productor__c 
            WHERE Cuenta__c IN :productorIds 
              AND Variedad__r.Obtentor_Comercializa__c IN :obtentorIds
        ]) {
            String key = existente.Cuenta__c + '_' + existente.Variedad__c;
            asignacionesExistentesSet.add(key);
        }

        // 4. Procesar la lógica en memoria sin hacer SOQLs ni DMLs dentro del bucle
        List<Variedad_SRE_por_Productor__c> aInsertarList = new List<Variedad_SRE_por_Productor__c>();
        Set<String> registrosEnColaSet = new Set<String>(); // Previene duplicados dentro del mismo lote de entrada

        for (FlowInput input : inputs) {
            if (input.productorId == null || input.obtentorId == null) {
                continue;
            }

            List<Variedad__c> variedadesDisponibles = variedadesPorObtentorMap.get(input.obtentorId);
            if (variedadesDisponibles == null) {
                continue;
            }

            for (Variedad__c variedad : variedadesDisponibles) {
                String key = input.productorId + '_' + variedad.Id;

                // Solo agregar si no existe en la base de datos NI fue agregada previamente en este mismo lote
                if (!asignacionesExistentesSet.contains(key) && !registrosEnColaSet.contains(key)) {
                    aInsertarList.add(new Variedad_SRE_por_Productor__c(
                        Cuenta__c = input.productorId,
                        Marca__c = variedad.Obtentor_Comercializa__c,
                        Variedad__c = variedad.Id
                    ));
                    registrosEnColaSet.add(key);
                }
            }
        }

        // 5. Operación DML ÚNICA: Insertar todos los registros acumulados
        if (!aInsertarList.isEmpty()) {
            insert aInsertarList;
        }
        
    }
}