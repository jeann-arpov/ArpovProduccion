public with sharing class GeneradorFacturasMBTApex {
    
    public class Request {
        @InvocableVariable(required=true label='MBTs Seleccionados')
        public List<Movimiento_BolsaTech__c> mbtsSeleccionados;
        
        @InvocableVariable(required=true label='ID Cultivo')
        public String cultivoId;
        
        @InvocableVariable(required=true label='ID Expediente')
        public String expedienteId;
        
        @InvocableVariable(required=true label='ID Productor (Cuenta)')
        public String productorId;
        
        @InvocableVariable(required=true label='CUIT Productor')
        public String productorCuit;
    }

    @InvocableMethod(label='Generar Facturas Temporales SEC' category='Facturacion')
    public static List<List<TN_Regalia_Enlist__c>> generar(List<Request> requests) {
        List<List<TN_Regalia_Enlist__c>> respuestas = new List<List<TN_Regalia_Enlist__c>>();
        
        // Obtener ID del Obtentor desde el Custom Setting (Evita DML en loops)
        Sembra_Evolucion__c setting = Sembra_Evolucion__c.getOrgDefaults();
        String obtentorId = setting != null ? setting.Corteva_30_Id__c : null;
        
        for (Request req : requests) {
            List<TN_Regalia_Enlist__c> facturasNuevas = new List<TN_Regalia_Enlist__c>();
            Set<Id> destinatarioIds = new Set<Id>();
            Set<String> cuitsABuscar = new Set<String>();
            
            // 1. Recopilar todos los CUITs y Destinatarios para consultarlos de un solo golpe (Bulkification)
            for (Movimiento_BolsaTech__c mbt : req.mbtsSeleccionados) {
                if (String.isNotBlank(mbt.CUIT_Titular__c) && String.isNotBlank(mbt.Cuit_Remitente_Comercial__c)) {
                    cuitsABuscar.add(mbt.Cuit_Remitente_Comercial__c);
                } else if (mbt.Destinatario__c != null) {
                    destinatarioIds.add(mbt.Destinatario__c);
                }
            }
            
            // 2. Resolver los CUITs de los Destinatarios (1 sola consulta SOQL)
            Map<Id, String> mapDestCuit = new Map<Id, String>();
            if (!destinatarioIds.isEmpty()) {
                for (Account acc : [SELECT Id, N_CUIT__c FROM Account WHERE Id IN :destinatarioIds]) {
                    mapDestCuit.put(acc.Id, acc.N_CUIT__c);
                    if (String.isNotBlank(acc.N_CUIT__c)) {
                        cuitsABuscar.add(acc.N_CUIT__c);
                    }
                }
            }
            
            // 3. Buscar las Cuentas Cobradoras por CUIT (1 sola consulta SOQL)
            Map<String, Id> mapCuitCuenta = new Map<String, Id>();
            if (!cuitsABuscar.isEmpty()) {
                for (Account acc : [SELECT Id, N_CUIT__c FROM Account WHERE N_CUIT__c IN :cuitsABuscar AND ParentId = null]) {
                    mapCuitCuenta.put(acc.N_CUIT__c, acc.Id);
                }
            }
            
            // 4. Armar las facturas procesando todo en memoria
            for (Movimiento_BolsaTech__c mbt : req.mbtsSeleccionados) {
                TN_Regalia_Enlist__c fac = new TN_Regalia_Enlist__c();
                
                // --- REGLA TITULAR ---
                Boolean titularAsignado = String.isNotBlank(mbt.Titular_asignado__c);
                String cuitTitular = titularAsignado ? mbt.Titular_asignado__c : mbt.Titular_original__c;
                
                if (titularAsignado) {
                    fac.Titular_asignado__c = cuitTitular;
                } else {
                    fac.Titular_original__c = cuitTitular;
                }
                
                // --- REGLA COBRADOR ---
                String cuitEvaluar = '';
                if (String.isNotBlank(mbt.CUIT_Titular__c) && String.isNotBlank(mbt.Cuit_Remitente_Comercial__c)) {
                    cuitEvaluar = mbt.Cuit_Remitente_Comercial__c;
                } else if (mbt.Destinatario__c != null && mapDestCuit.containsKey(mbt.Destinatario__c)) {
                    cuitEvaluar = mapDestCuit.get(mbt.Destinatario__c);
                }
                
                if (String.isNotBlank(cuitEvaluar) && mapCuitCuenta.containsKey(cuitEvaluar)) {
                    fac.Cobrador__c = mapCuitCuenta.get(cuitEvaluar);
                }
                
                // --- ASIGNACIONES GENERALES ---
                fac.Biotecnologia__c = 'Enlist';
                fac.Cantidad__c = mbt.Tonelada_MBT__c;
                fac.Cultivo__c = req.cultivoId;
                fac.Etapa__c = 'A Facturar';
                fac.Expediente_de_Negativos__c = req.expedienteId;
                fac.Productor__c = req.productorId;
                fac.N_CUIT__c = req.productorCuit;
                fac.Obtentor__c = obtentorId;
                fac.CTGs_Involucrados__c = mbt.CTG__c;
                
                facturasNuevas.add(fac);
            }
            
            respuestas.add(facturasNuevas);
        }
        
        return respuestas;
    }
}