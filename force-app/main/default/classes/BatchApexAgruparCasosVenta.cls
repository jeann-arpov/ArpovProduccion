global class BatchApexAgruparCasosVenta implements Database.Batchable<sObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bctx){
        
        //Obtenemos todas las transacciones con Estado igual a Completa
        String query = 'SELECT Id, ParentId, AccountId FROM Case WHERE RecordType.DeveloperName = \'Ventas\' AND ParentId = null';
        
        if(Test.isRunningTest()){
          query += ' LIMIT 100';
        }
        
        //Retornamos la query
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext bctx, List<Case> scope){
        
        
        System.Debug(LoggingLevel.INFO,scope.size());
        
        UtilsCasos.agruparCasosVentas(scope); 

    }
    
    global void finish(Database.BatchableContext bctx){
    
    }
    
}