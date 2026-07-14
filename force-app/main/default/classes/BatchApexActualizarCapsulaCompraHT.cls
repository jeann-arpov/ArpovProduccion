global class BatchApexActualizarCapsulaCompraHT implements Database.Batchable<sObject>, Database.Stateful{
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
        String query = 'SELECT Id, Licencia__r.Id_Obtentor__c, Compra_Ht__c FROM Linea_de_Compra_HT__c WHERE Licencia__c != \'\'';
        return (Database.getQueryLocator(query));
    }

    global void execute(Database.BatchableContext bctx, List<Linea_de_Compra_HT__c> scope){

        Map<String, String> idObtentoByCompra = new Map<String, String>();
        for(Linea_de_Compra_HT__c linea : scope) {
            if(!idObtentoByCompra.containsKey(linea.Compra_HT__c)){
                idObtentoByCompra.put(linea.Compra_HT__c, linea.Licencia__r.Id_Obtentor__c);
            }

            linea.Capsula__c = capsulasByIdObtentor.get(linea.Licencia__r.Id_Obtentor__c);
        }

        List<Compra_HT__c> compraToUpdate = new List<Compra_HT__c>();
        for(String key : idObtentoByCompra.keySet()){
            Compra_HT__c compraActualizada = new Compra_HT__c(
                Id = key,
                Capsula__c = capsulasByIdObtentor.get(idObtentoByCompra.get(key))
            );
            compraToUpdate.add(compraActualizada);
        }

        List<Database.SaveResult> results = new List<Database.SaveResult>();
        results.addAll(Database.update(scope, false));
        results.addAll(Database.update(compraToUpdate, false));
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()){
                this.errors.add(String.format('Record {0} : Error {1}', new List<String>{result.getId(),result.getErrors()[0].getMessage()}));
            }
        }
    }
    
    global void finish(Database.BatchableContext bctx){
        system.debug(errors);
        BatchErrorHelper.sendEmail(bctx.getJobId(), errors, 'Arpov: Errores en BatchApexActualizarCapsulaCompraHT');
    }
}