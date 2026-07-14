global class BatchApexCrearCasosVenta implements Database.Batchable<sObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bctx){
        
        //Obtenemos el RecordType para un Distribuidor
        Id rtD = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Distribuidor');
        
        //Obtenemos el RecordType para un Comercio
        Id rtC = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Comercio');
        
        //Obtenemos todas las ventas cuyo destinatario sea distinto del originante
        //Y ademas cuyo Destinatario sea Comercio o Distribuidor
        String query = 'SELECT Id  FROM Venta__c WHERE (Destinatario__r.RecordTypeId ='+'\''+rtC+'\''+' OR Destinatario__r.RecordTypeId = '+'\''+rtD+'\''+') ';
        
        if(Test.isRunningTest()){
          query += ' LIMIT 100';
        }
        
        System.Debug(LoggingLevel.INFO,query);
        
        //Retornamos la query
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext bctx, List<Venta__c> scope){
        
        
        System.Debug(LoggingLevel.INFO,scope.size());
        
        UtilsCasos.crearCasosFromVentas(scope); 

    }
    
    global void finish(Database.BatchableContext bctx){
    
    }
    
}