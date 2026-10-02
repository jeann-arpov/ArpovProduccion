public with sharing class FiltrarMBTPendientes {
    
    public class Request {
        @InvocableVariable(required=true label='Expediente ID')
        public String expedienteId;
    }

    public class Response {
        @InvocableVariable(label='Lista MBT Pendientes')
        public List<Movimiento_BolsaTech__c> mbtPendientes;
        @InvocableVariable(label='Cantidad Pendientes')
        public Integer cantidadPendientes;
    }

    @InvocableMethod(label='Obtener MBTs Pendientes de Facturar' category='Facturacion')
    public static List<Response> obtenerPendientes(List<Request> requests) {
        List<Response> respuestas = new List<Response>();
        
        List<String> listaIds = new List<String>();
        for (Request req : requests) {
            if (String.isNotBlank(req.expedienteId)) {
                listaIds.add(req.expedienteId);
            }
        }
        
        // 1. Consultar facturas existentes
        String queryFacturas = 'SELECT Expediente_de_Negativos__c, CTGs_Involucrados__c ' +
                               'FROM TN_Regalia_Enlist__c ' +
                               'WHERE Expediente_de_Negativos__c IN :listaIds';
                               
        Map<Id, Set<String>> ctgsPorExpediente = new Map<Id, Set<String>>();
        
        for (TN_Regalia_Enlist__c fact : (List<TN_Regalia_Enlist__c>)Database.query(queryFacturas)) {
            if (!ctgsPorExpediente.containsKey(fact.Expediente_de_Negativos__c)) {
                ctgsPorExpediente.put(fact.Expediente_de_Negativos__c, new Set<String>());
            }
            if (String.isNotBlank(fact.CTGs_Involucrados__c)) {
                // Limpia corchetes '[', ']', comillas y espacios antes de hacer el split
                // Transforma "[1025834788, 1025834789]" en "1025834788,1025834789"
                String cleanedStr = fact.CTGs_Involucrados__c.replaceAll('[\\[\\]\\s"\']', '');
                for (String ctg : cleanedStr.split(',')) {
                    if (String.isNotBlank(ctg)) {
                        ctgsPorExpediente.get(fact.Expediente_de_Negativos__c).add(ctg.trim());
                    }
                }
            }
        }

        // 2. Consultar MBTs
        String queryMBTs = 'SELECT Id, Name, Expediente_de_Negativos__c, CTG__c, Razon_Social_Titular__c, ' +
                           'Razon_Social_Remitente_Comercial__c, Tonelada_MBT__c, ' +
                           'CUIT_Titular__c, Cuit_Remitente_Comercial__c, ' +
                           'Titular_asignado__c, Titular_original__c, Destinatario__c ' +
                           'FROM Movimiento_BolsaTech__c ' +
                           'WHERE Expediente_de_Negativos__c IN :listaIds';
                           
        Map<Id, List<Movimiento_BolsaTech__c>> mbtPorExpediente = new Map<Id, List<Movimiento_BolsaTech__c>>();
        
        for (Movimiento_BolsaTech__c mbt : (List<Movimiento_BolsaTech__c>)Database.query(queryMBTs)) {
            if (!mbtPorExpediente.containsKey(mbt.Expediente_de_Negativos__c)) {
                mbtPorExpediente.put(mbt.Expediente_de_Negativos__c, new List<Movimiento_BolsaTech__c>());
            }
            mbtPorExpediente.get(mbt.Expediente_de_Negativos__c).add(mbt);
        }

        // 3. Filtrar en memoria
        for (Request req : requests) {
            Response res = new Response();
            List<Movimiento_BolsaTech__c> pendientes = new List<Movimiento_BolsaTech__c>();
            
            Id expId = null;
            if (String.isNotBlank(req.expedienteId)) {
                expId = (Id)req.expedienteId;
            }
            
            Set<String> ctgsFacturados = ctgsPorExpediente.containsKey(expId) ? ctgsPorExpediente.get(expId) : new Set<String>();
            List<Movimiento_BolsaTech__c> mbts = mbtPorExpediente.containsKey(expId) ? mbtPorExpediente.get(expId) : new List<Movimiento_BolsaTech__c>();
            
            for (Movimiento_BolsaTech__c mbt : mbts) {
                String mbtCtg = String.isNotBlank(mbt.CTG__c) ? mbt.CTG__c.trim() : '';
                if (String.isBlank(mbtCtg) || !ctgsFacturados.contains(mbtCtg)) {
                    pendientes.add(mbt);
                }
            }
            
            res.mbtPendientes = pendientes;
            res.cantidadPendientes = pendientes.size();
            respuestas.add(res);
        }
        
        return respuestas;
    }
}