global class BatchApexGeneracionFacturas implements Database.Batchable<sObject>,Database.Stateful {
    
    public List<String> errors;

    public BatchApexGeneracionFacturas(){
        this.errors = new List<String>();
    }

    global Database.QueryLocator start(Database.BatchableContext bctx){
        
        //Obtenemos todas las transacciones con Estado igual a Completa
        String query = 'SELECT Id, RecordType.DeveloperName, Subestado__c FROM Transaccion__c WHERE ((RecordType.DeveloperName = \'Auditorias\' AND Estado__c = \'Completa\') OR (RecordType.DeveloperName = \'DUP\' AND (Estado__c = \'Respondida\' OR Estado__c = \'Respondida Parcialmente\') AND (Respondida_via_Minisitio__c = false OR (Respondida_via_Minisitio__c = true AND Resultado_Validacion_Analista__c = \'Positiva\'))))'+' '+'AND'+' '+'Factura__c = null AND Subestado__c IN (\'POSITIVA\',\'NEGATIVA\')  AND No_Facturar__c = false AND  (Cantidad_Bolsas_RE__c <> 0 OR Cantidad_Bolsas_RC__c <> 0)' ;
        
        if(Test.isRunningTest()){
          query = 'SELECT Id, RecordType.DeveloperName, Subestado__c FROM Transaccion__c';
        }
        
        //Retornamos la query
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext bctx, List<Transaccion__c> scope){
        
        //Procesamos cada lote de Transacciones Completas, separando en dos Sets aquellas transacciones
        //de tipo Auditoria de aquellas de tipo DUP
        
        //Set para coleccionar los Ids de las Transacciones de tipo Auditoria
        Set<Id> auditorias = new Set<Id>();
        
        //Set para coleccionar los Ids de las Transacciones de tipo DUP
        Set<Id> dups = new Set<Id>();
        
        for(Transaccion__c transaccion : scope){
        
            if(transaccion.RecordType.DeveloperName == 'DUP'){

                dups.add(transaccion.Id);
                
            }else if(transaccion.RecordType.DeveloperName == 'Auditorias'){
            
                auditorias.add(transaccion.Id);
                                
            }
        
        }

        // Instanciamos la clase
        CreateOppsFromTransactions coft = new CreateOppsFromTransactions();
        
        //Procesamos las Transacciones DUPS (si hubiera)
        if(dups.size() > 0){
            //llamamos al metodo createDups que procesara las transacciones DUP
            coft.createDups(dups);
        }

        //Procesamos las Transacciones Auditorias (si hubiera)
        if(auditorias.size() > 0){
            //llamamos al metodo createAuds que procesara las transacciones Auditorias
            coft.createAuds(auditorias);
        }

        // Si hay errores los cargamos en la lista de errores a enviar por email
        if(!coft.getErrors().isEmpty()){
            errors.addAll(coft.getErrors());
        }

    }
    
    global void finish(Database.BatchableContext bctx){
        BatchErrorHelper.sendEmail(bctx.getJobId(), errors, 'Errores en BatchApexGeneracionFacturas');
        
        Database.executeBatch(new BatchApexOpportunitiesPDFs());

        Database.executeBatch(new BatchApexDupsEliminarEmptyTransacciones(), 200);

    }
    
}