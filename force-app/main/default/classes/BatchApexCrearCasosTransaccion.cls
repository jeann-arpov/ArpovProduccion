global class BatchApexCrearCasosTransaccion implements Database.Batchable<sObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bctx){
        
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        //Obtenemos todas las ventas cuyo destinatario sea distinto del originante
        //Y ademas cuyo Destinatario sea Comercio o Distribuidor
        String query = 'SELECT Id, (SELECT Id, Transaccion__c FROM Item_de_DUP__r)  FROM Transaccion__c WHERE RecordTypeId ='+'\''+rtDup+'\''+'AND Estado__c = '+'\''+'Creada'+'\''+'AND Subestado__c='+'\''+'Positiva'+'\'';
        
        if(Test.isRunningTest()){
          query += ' LIMIT 100';
        }
        
        System.Debug(LoggingLevel.INFO,query);
        
        //Retornamos la query
        return Database.getQueryLocator(query);
        
        
    }
    global void execute(Database.BatchableContext bctx, List<Transaccion__c> scope){
        
        //Coleccionamos los ids de las transacciones
        
        //Set para coleccionar los ids de los item de DUP
        List<Item_de_DUP__c> itemDeDUP = new List<Item_de_DUP__c>();
        
        for(Transaccion__c transaccion : scope){
            
            //Verificamos si tenemos items
            if(transaccion.Item_de_DUP__r.size() == 1){

                Item_de_DUP__c item = transaccion.Item_de_DUP__r.get(0);

                itemDeDUP.add(item);

            }
            
        }
        
        
        if(itemDeDUP.size() > 0){
            
             UtilsCasos.crearCasosDups(itemDeDUP);
            
        }
        
        
    }
    
    global void finish(Database.BatchableContext bctx){
    
    }

}