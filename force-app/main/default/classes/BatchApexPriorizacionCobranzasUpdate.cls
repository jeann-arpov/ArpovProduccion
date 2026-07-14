global with sharing class BatchApexPriorizacionCobranzasUpdate implements Database.Batchable<sObject>, Database.Stateful {
    
    global Integer accountNumber;
    global Integer groupNumber;
    
    global BatchApexPriorizacionCobranzasUpdate(Integer accountNumber, Integer groupNumber){
        this.accountNumber = accountNumber;
        this.groupNumber = groupNumber;
    }
    
    /**
    * @author Maximo Martinez
    * @date 21/07/2014
    * @description Metodo que construye la query necesaria a partir de los parametros pasados
    */
    public String buildQuery(){

        String qry;
        String campoEstado = 'Cuenta__r.Estado_Segun_Patron_Cobranzas__c';
        String campoDeuda = 'Deuda_Total_Cobranzas__c';
        String campoDiasVencido = 'Dias_desde_Vencido_Cobranzas__c';
        
        qry = 'SELECT Cuenta__c FROM Orden_Intragrupo__c';
        String orderBy;
        if(groupNumber == 1){
            orderBy = campoDeuda + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoEstado + ' IN ' +'('+'\''+ PriorizacionesUtil.VENCIDO +'\''+', '+ '\''+ PriorizacionesUtil.NEG_VEN +'\''+')'+' ORDER BY ' + orderBy;
        }else if(groupNumber == 2){
            orderBy = campoDeuda + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VIG + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 3){
            orderBy = campoDeuda + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoEstado + ' = \'' + PriorizacionesUtil.NO_VENCIDO + '\' ORDER BY ' + orderBy;
        } 
        if(Test.isRunningTest()){
            qry += ' LIMIT 100';
        }

        return qry;

    }


    global Database.QueryLocator start(Database.BatchableContext BC){
        
        //Invocamos al metodo que construye la query
        String query = buildQuery();

        System.debug(LoggingLevel.INFO, 'qry: ' + query); 
        
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<Orden_Intragrupo__c> scope){
        
        Account a;
        List<Account> cuentas = new List<Account>();
        Set<Id> idsCuentas = new Set<Id>();
        for(Orden_Intragrupo__c oi : scope){
            if(!idsCuentas.contains(oi.Cuenta__c)){
                a = new Account(ID = oi.Cuenta__c);
                a.Prioridad_Cobranzas_Original__c = accountNumber;
                a.Prioridad_Cobranzas_Recalculada__c = accountNumber;
                accountNumber++;
                cuentas.add(a);
            }
        }
        update cuentas;
    }
    
    global void finish(Database.BatchableContext BC){
        if(!Test.isRunningTest()){
            if(groupNumber == 3){
                List<Campana_Agricola__c> campanas = [SELECT Temporada__c FROM Campana_Agricola__c WHERE Estado__c = 'Activa'];
                BatchApexPriorizacionVentasUpdate batch = new BatchApexPriorizacionVentasUpdate(100000, 1, campanas);
                Database.executeBatch(batch, 500);
            } else {
                groupNumber++;
                BatchApexPriorizacionCobranzasUpdate batch = new BatchApexPriorizacionCobranzasUpdate(accountNumber, groupNumber);
                Database.executeBatch(batch, 500);
            }
        }
    }
    
}