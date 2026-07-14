global with sharing class BatchApexPriorizacionVentasUpdate implements Database.Batchable<sObject>, Database.Stateful {
    
    global Integer accountNumber;
    global Integer groupNumber;
    global Campana_Agricola__c campana;
    global String temporada;
    global List<Campana_Agricola__c> campanas;
    
    global BatchApexPriorizacionVentasUpdate(Integer accountNumber, Integer groupNumber, List<Campana_Agricola__c> campanas){
        this.accountNumber = accountNumber;
        this.groupNumber = groupNumber;
        this.campanas = campanas;
        campana = campanas.get(0);
        this.temporada = campana.Temporada__c;
    }
    
    /**
    * @author Maximo Martinez
    * @date 21/07/2014
    * @description Metodo que construye la query necesaria a partir de los parametros pasados
    */
    public String buildQuery(){

        String qry;
        String campoEstado;
        String campoSaldo;
        String campoDiasVencido;
        if(temporada == PriorizacionesUtil.INVIERNO){
            campoEstado = 'Cuenta__r.Estado_Segun_Patron_Venta_Invierno__c';
            campoSaldo = 'Saldo_Total_Ventas_Invierno__c';
            campoDiasVencido = 'Dias_desde_Vencido_Ventas_Invierno__c';
        } else {
            campoEstado = 'Cuenta__r.Estado_Segun_Patron_Venta_Verano__c';
            campoSaldo = 'Saldo_Total_Ventas_Verano__c';
            campoDiasVencido = 'Dias_desde_Vencido_Ventas_Verano__c';
        }
        qry = 'SELECT Cuenta__c FROM Orden_Intragrupo__c';
        String orderBy;
        if(groupNumber == 1){
            orderBy = campoSaldo + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VEN + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 2){
            orderBy = campoSaldo + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoEstado + ' = \'' + PriorizacionesUtil.NO_GESTIONADO + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 3){
            orderBy = campoSaldo + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VIG + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 4){
            orderBy = campoSaldo + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoEstado + ' = \'' + PriorizacionesUtil.NO_RESPONDIERON + '\' ORDER BY ' + orderBy;
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
        for(Orden_Intragrupo__c oi : scope){
            a = new Account(ID = oi.Cuenta__c);
            if(temporada == PriorizacionesUtil.INVIERNO){
                a.Prioridad_Venta_Invierno_Original__c = accountNumber;
                a.Prioridad_Venta_Invierno_Recalculada__c = accountNumber;
            } else {
                a.Prioridad_Venta_Verano_Original__c = accountNumber;
                a.Prioridad_Venta_Verano_Recalculada__c = accountNumber;
            }
            accountNumber++;
            cuentas.add(a);
        }
        update cuentas;
    }
    
    global void finish(Database.BatchableContext BC){
        
        if(groupNumber == 4){
            groupNumber = 1;
        } else {
            groupNumber++;
        }
        if(groupNumber == 1 && campanas.size() == 1){
            BatchApexPriorizacionDeleteTemporal batch = new BatchApexPriorizacionDeleteTemporal(false);
            Database.executeBatch(batch, 2000);
        } else {
            if(groupNumber == 1 && campanas.size() > 1){
                campanas.remove(0);
                accountNumber = 100000;
            }
            BatchApexPriorizacionVentasUpdate batch = new BatchApexPriorizacionVentasUpdate(accountNumber, groupNumber, campanas);
            Database.executeBatch(batch, 500);
        }
        
    }
    
}