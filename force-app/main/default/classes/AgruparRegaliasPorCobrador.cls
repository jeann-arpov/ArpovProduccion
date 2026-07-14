public with sharing class AgruparRegaliasPorCobrador {

    @InvocableMethod(label='Agrupar TN_Regalia_Enlist por Cobrador y sumar Cantidad')
    public static List<SalidaWrapper> procesar(List<EntradaWrapper> inputList) {

        // Validación defensiva
        if (inputList == null || inputList.isEmpty() || inputList[0].registros == null) {
            SalidaWrapper salidaVacia = new SalidaWrapper();
            salidaVacia.registrosAgrupados = new List<TN_Regalia_Enlist__c>();
            return new List<SalidaWrapper>{ salidaVacia };
        }

        List<TN_Regalia_Enlist__c> registros = inputList[0].registros;

        // Mapa principal por cobrador
        Map<Id, TN_Regalia_Enlist__c> agrupados = new Map<Id, TN_Regalia_Enlist__c>();

        // Mapa auxiliar para acumular CTGs por cobrador (con duplicados)
        Map<Id, List<String>> ctgsPorCobrador = new Map<Id, List<String>>();

        for (TN_Regalia_Enlist__c reg : registros) {

            if (reg == null || reg.Cobrador__c == null) continue;

            Id cobrador = reg.Cobrador__c;

            // Inicializar agrupación si no existe
            if (!agrupados.containsKey(cobrador)) {

                TN_Regalia_Enlist__c nuevo = reg.clone(false, true, false, false);
                nuevo.Cantidad__c = reg.Cantidad__c != null ? reg.Cantidad__c : 0;

                agrupados.put(cobrador, nuevo);

                // Inicializar lista de CTGs (con duplicados)
                ctgsPorCobrador.put(cobrador, new List<String>());

            } else {

                TN_Regalia_Enlist__c existente = agrupados.get(cobrador);

                Decimal actual = existente.Cantidad__c != null ? existente.Cantidad__c : 0;
                Decimal nueva  = reg.Cantidad__c != null ? reg.Cantidad__c : 0;

                existente.Cantidad__c = actual + nueva;
            }

            // Acumular CTGs (permitiendo duplicados)
            if (reg.CTGs_Involucrados__c != null) {
                ctgsPorCobrador.get(cobrador).add(reg.CTGs_Involucrados__c);
            }
        }

        // Convertir listas de CTGs a string con formato [a, b, c]
        for (Id cobradorId : agrupados.keySet()) {
            List<String> ctgs = ctgsPorCobrador.get(cobradorId);

            if (ctgs != null && !ctgs.isEmpty()) {
                String listaFormateada = '[' + String.join(ctgs, ', ') + ']';
                agrupados.get(cobradorId).CTGs_Involucrados__c = listaFormateada;
            }
        }

        SalidaWrapper salida = new SalidaWrapper();
        salida.registrosAgrupados = agrupados.values();

        return new List<SalidaWrapper>{ salida };
    }

    // Wrapper de entrada (Flow sí permite lista aquí)
    public class EntradaWrapper {
        @InvocableVariable(required=true)
        public List<TN_Regalia_Enlist__c> registros;
    }

    // Wrapper de salida
    public class SalidaWrapper {
        @InvocableVariable
        public List<TN_Regalia_Enlist__c> registrosAgrupados;
    }
}