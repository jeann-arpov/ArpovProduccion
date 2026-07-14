global class LicenciaBatch implements Database.Batchable<SObject> {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Consulta directa sobre Linea_de_Compra_HT__c
        return Database.getQueryLocator([
            SELECT Id,
                   Compra_HT__r.Oportunidad__r.Id,
                   Compra_HT__r.Oportunidad__r.hasLicence__c
            FROM Linea_de_Compra_HT__c
            WHERE Licencia__r.Estado__c = 'Aprobada'
              AND Licencia__r.Fecha_de_Vencimiento__c >= :System.today()
            ]);
    }

    global void execute(Database.BatchableContext bc, List<Linea_de_Compra_HT__c> scope) {
        if (scope.isEmpty()) return;

        Map<Id, Opportunity> oppsToUpdate = new Map<Id, Opportunity>();

        for (Linea_de_Compra_HT__c linea : scope) {
            Opportunity opp = linea.Compra_HT__r.Oportunidad__r;
            if (opp != null && opp.hasLicence__c == false) {
                oppsToUpdate.put(opp.Id, new Opportunity(
                    Id = opp.Id,
                    hasLicence__c = true
                ));
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            Database.update(oppsToUpdate.values(), false);
        }
    }

    global void finish(Database.BatchableContext bc) {
        // Aquí podrías loguear resultados o enviar un email si lo necesitas
    }
}