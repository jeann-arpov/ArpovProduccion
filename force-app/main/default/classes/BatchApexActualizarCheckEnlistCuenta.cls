global without sharing class BatchApexActualizarCheckEnlistCuenta implements Database.Batchable<sObject>, Database.Stateful{
    public List<String> errors = new List<String>();

    global Database.QueryLocator start(Database.BatchableContext bctx){
        String query = 'SELECT Id FROM Account';
        return (Database.getQueryLocator(query));
    }

    global void execute(Database.BatchableContext bctx, List<Account> scope){
        Map<String, List<Licencia__c>> licenciasByAccountId = new Map<String, List<Licencia__c>>();
        for(Account ac : scope){
            licenciasByAccountId.put(ac.Id, new List<Licencia__c>());
        }

        for(Licencia__c lic : [
            SELECT Id, Cuenta_Productor__c 
            FROM Licencia__c 
            WHERE Tecnologia__c = 'Enlist' 
                AND Tipo_de_Licencia__c = 'Productor' 
                AND Estado__c = 'Aprobada'
                AND Cuenta_Productor__c IN :licenciasByAccountId.keySet()
                AND Fecha_de_Vencimiento__c > TODAY
        ]) {
            licenciasByAccountId.get(lic.Cuenta_Productor__c).add(lic);
        }

        for(Account ac : scope){
            ac.Usuario_Enlist__c = licenciasByAccountId.get(ac.Id).size() > 0;
        }

        List<Database.SaveResult> results = Database.update(scope, false);
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()){
                this.errors.add(String.format('Record {0} : Error {1}', new List<String>{result.getId(),result.getErrors()[0].getMessage()}));
            }
        }

    }
    
    global void finish(Database.BatchableContext bctx){
        system.debug(errors);
        BatchErrorHelper.sendEmail(bctx.getJobId(), errors, 'Arpov: Errores en BatchApexActualizarCheckEnlistCuenta');
    }
}