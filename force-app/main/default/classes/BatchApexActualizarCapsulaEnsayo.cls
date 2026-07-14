global class BatchApexActualizarCapsulaEnsayo implements Database.Batchable<sObject>, Database.Stateful{
    public List<String> errors = new List<String>();
    private Map<String, String> capsulasByIdObtentor = new Map<String, String>{
        '03' => 'GRUPO DON MARIO',
        '14' => 'GRUPO DON MARIO',
        '85' => 'GRUPO DON MARIO',
        '13' => 'CORTEVA',
        '87' => 'CORTEVA',
        '90' => 'CORTEVA',
        '04' => 'SYNGENTA',
        '23' => 'SYNGENTA',
        '24' => 'STINE',
        '26' => 'A.C.A.',
        '19' => 'BIOCERES',
        '05' => 'BUCK',
        '12' => 'LG',
        '15' => 'LDC',
        '16' => 'LDC',
        '06' => 'KLEIN',
        '51' => 'QUILMES',
        '77' => 'BASF'
    };

    global Database.QueryLocator start(Database.BatchableContext bctx){
        String query = 'SELECT Id, Licencia__r.Id_Obtentor__c FROM Ensayo__c WHERE Licencia__c  != \'\'';
        return (Database.getQueryLocator(query));
    }

    global void execute(Database.BatchableContext bctx, List<Ensayo__c> scope){
        system.debug(scope);
        for(Ensayo__c ensayo : scope){
            ensayo.Capsula__c = capsulasByIdObtentor.get(ensayo.Licencia__r.Id_Obtentor__c);
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
        BatchErrorHelper.sendEmail(bctx.getJobId(), errors, 'Arpov: Errores en BatchApexActualizarCapsulaEnsayo');
    }
}