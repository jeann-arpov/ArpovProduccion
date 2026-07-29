/**
 * Relaciona facturas Regalía Enlist (FCRE3) con MBT y, si existen, con sus TN.
 * Matching por CTG contenido en CTGs_Involucrados_Largo__c / CTGs_Involucrados__c.
 * Si hay una sola factura para el expediente, se aplica a todos los MBT del EXP.
 */
public with sharing class RelacionarFacturaEnlistMbt {

    @InvocableMethod(
        label='Relacionar FCRE3 a MBT del Expediente'
        description='Setea FT_RE3_Id__c en MBT (y TN vinculadas) según facturas del expediente PRI/SEC'
    )
    public static List<Resultado> relacionar(List<Request> requests) {
        List<Resultado> results = new List<Resultado>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> expedienteIds = new Set<Id>();
        for (Request req : requests) {
            if (req != null && req.expedienteId != null) {
                expedienteIds.add(req.expedienteId);
            }
        }

        Map<Id, Integer> updatedByExp = relacionarPorExpedientes(expedienteIds);

        for (Request req : requests) {
            Resultado r = new Resultado();
            r.expedienteId = req != null ? req.expedienteId : null;
            r.mbtsActualizados = r.expedienteId != null && updatedByExp.containsKey(r.expedienteId)
                ? updatedByExp.get(r.expedienteId)
                : 0;
            results.add(r);
        }
        return results;
    }

    public static Map<Id, Integer> relacionarPorExpedientes(Set<Id> expedienteIds) {
        Map<Id, Integer> updatedByExp = new Map<Id, Integer>();
        if (expedienteIds == null || expedienteIds.isEmpty()) {
            return updatedByExp;
        }

        List<TN_Regalia_Enlist__c> facturas = [
            SELECT Id, Expediente_de_Negativos__c, CTGs_Involucrados_Largo__c, CTGs_Involucrados__c
            FROM TN_Regalia_Enlist__c
            WHERE Expediente_de_Negativos__c IN :expedienteIds
        ];

        Map<Id, List<TN_Regalia_Enlist__c>> facturasPorExp = new Map<Id, List<TN_Regalia_Enlist__c>>();
        for (TN_Regalia_Enlist__c f : facturas) {
            if (!facturasPorExp.containsKey(f.Expediente_de_Negativos__c)) {
                facturasPorExp.put(f.Expediente_de_Negativos__c, new List<TN_Regalia_Enlist__c>());
            }
            facturasPorExp.get(f.Expediente_de_Negativos__c).add(f);
        }

        List<Movimiento_BolsaTech__c> mbts = [
            SELECT Id, CTG__c, Expediente_de_Negativos__c, FT_RE3_Id__c, TN_Id__c
            FROM Movimiento_BolsaTech__c
            WHERE Expediente_de_Negativos__c IN :expedienteIds
        ];

        Map<Id, Id> facturaPorMbt = new Map<Id, Id>();
        for (Movimiento_BolsaTech__c mbt : mbts) {
            List<TN_Regalia_Enlist__c> facts = facturasPorExp.get(mbt.Expediente_de_Negativos__c);
            if (facts == null || facts.isEmpty()) {
                continue;
            }

            Id facturaId = resolverFacturaParaMbt(mbt, facts);
            if (facturaId == null) {
                continue;
            }
            if (mbt.FT_RE3_Id__c != facturaId) {
                facturaPorMbt.put(mbt.Id, facturaId);
            }
        }

        if (facturaPorMbt.isEmpty()) {
            for (Id expId : expedienteIds) {
                updatedByExp.put(expId, 0);
            }
            return updatedByExp;
        }

        Map<Id, Movimiento_BolsaTech__c> mbtById = new Map<Id, Movimiento_BolsaTech__c>(mbts);
        List<Movimiento_BolsaTech__c> mbtsToUpdate = new List<Movimiento_BolsaTech__c>();
        Set<Id> tnIds = new Set<Id>();
        Map<Id, Id> facturaPorTn = new Map<Id, Id>();

        for (Id mbtId : facturaPorMbt.keySet()) {
            Id facturaId = facturaPorMbt.get(mbtId);
            Movimiento_BolsaTech__c mbt = mbtById.get(mbtId);
            mbtsToUpdate.add(new Movimiento_BolsaTech__c(
                Id = mbtId,
                FT_RE3_Id__c = facturaId
            ));

            Id expId = mbt.Expediente_de_Negativos__c;
            updatedByExp.put(expId, (updatedByExp.containsKey(expId) ? updatedByExp.get(expId) : 0) + 1);

            if (mbt.TN_Id__c != null) {
                tnIds.add(mbt.TN_Id__c);
                facturaPorTn.put(mbt.TN_Id__c, facturaId);
            }
        }

        // TN ligadas por lookup inverso Mov_BolsaTech__c
        for (Tonelada__c tn : [
            SELECT Id, Mov_BolsaTech__c, FT_RE3_Id__c
            FROM Tonelada__c
            WHERE Mov_BolsaTech__c IN :facturaPorMbt.keySet()
        ]) {
            Id facturaId = facturaPorMbt.get(tn.Mov_BolsaTech__c);
            if (facturaId != null && tn.FT_RE3_Id__c != facturaId) {
                facturaPorTn.put(tn.Id, facturaId);
            }
        }

        update mbtsToUpdate;

        if (!facturaPorTn.isEmpty()) {
            List<Tonelada__c> tnsToUpdate = new List<Tonelada__c>();
            for (Id tnId : facturaPorTn.keySet()) {
                tnsToUpdate.add(new Tonelada__c(
                    Id = tnId,
                    FT_RE3_Id__c = facturaPorTn.get(tnId)
                ));
            }
            update tnsToUpdate;
        }

        for (Id expId : expedienteIds) {
            if (!updatedByExp.containsKey(expId)) {
                updatedByExp.put(expId, 0);
            }
        }
        return updatedByExp;
    }

    @TestVisible
    private static Id resolverFacturaParaMbt(Movimiento_BolsaTech__c mbt, List<TN_Regalia_Enlist__c> facts) {
        if (facts.size() == 1) {
            return facts[0].Id;
        }

        String ctg = mbt.CTG__c != null ? String.valueOf(mbt.CTG__c).trim() : null;
        if (String.isBlank(ctg)) {
            return null;
        }

        for (TN_Regalia_Enlist__c f : facts) {
            String ctgsRaw = f.CTGs_Involucrados_Largo__c != null
                ? f.CTGs_Involucrados_Largo__c
                : f.CTGs_Involucrados__c;
            if (String.isBlank(ctgsRaw)) {
                continue;
            }
            if (contieneCtg(ctgsRaw, ctg)) {
                return f.Id;
            }
        }
        return null;
    }

    @TestVisible
    private static Boolean contieneCtg(String ctgsRaw, String ctg) {
        String normalized = ctgsRaw.replace('[', '').replace(']', '');
        for (String part : normalized.split(',')) {
            if (part != null && part.trim() == ctg) {
                return true;
            }
        }
        return ctgsRaw.contains(ctg);
    }

    public class Request {
        @InvocableVariable(required=true label='Expediente Id')
        public Id expedienteId;
    }

    public class Resultado {
        @InvocableVariable(label='Expediente Id')
        public Id expedienteId;
        @InvocableVariable(label='MBTs actualizados')
        public Integer mbtsActualizados;
    }
}
