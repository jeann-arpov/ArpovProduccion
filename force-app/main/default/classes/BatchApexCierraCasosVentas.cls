global class BatchApexCierraCasosVentas implements Database.Batchable<sObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bctx){
        
        //Obtenemos todas ventas que se 
        
        Date today = Date.today();

        Integer dia = today.day();
        
        Integer mes = today.month();
        
        Integer anio = today.year();
        
        String query = 'SELECT Id, CreatedDate FROM Venta__c WHERE CALENDAR_YEAR(CreatedDate) = :anio AND DAY_IN_MONTH(CreatedDate) = :dia AND CALENDAR_MONTH(CreatedDate) = :mes';
        
        if(Test.isRunningTest()){
          query += ' LIMIT 100';
        }
        
        System.Debug(LoggingLevel.INFO, query);
        
        System.Debug(LoggingLevel.INFO, today);
        
        //Retornamos la query
        return (Database.getQueryLocator(query));
    }
    
    global void execute(Database.BatchableContext bctx, List<Venta__c> scope){
        
        System.Debug(LoggingLevel.INFO,scope.size());
        
        UtilsCasos.cerrarCasosFromVentas(scope);
    }
    
    global void finish(Database.BatchableContext bctx){
    
    }
    
}