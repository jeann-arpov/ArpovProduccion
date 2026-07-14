global with sharing class BatchApexPriorizacionDUPSUpdate implements Database.Batchable<sObject>, Database.Stateful {
    
    global Integer accountNumber;
    global Integer groupNumber;
    global Campana_Agricola__c campana;
    global String temporada;
    global List<Campana_Agricola__c> campanas;
    
    global BatchApexPriorizacionDUPSUpdate(Integer accountNumber, Integer groupNumber, List<Campana_Agricola__c> campanas){
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
        String campoSegmentacion;
        String campoEstado;
        String campoTamano;
        String campoDiasVencido;
        String campoDiasVencimiento;
        String campoDiasUtimoContacto;
        if(temporada == PriorizacionesUtil.INVIERNO){
            campoSegmentacion = 'Cuenta__r.Segmentacion_Productor_Invierno__c';
            campoEstado = 'Cuenta__r.Estado_Segun_Patron_DUP_Invierno__c';
            campoTamano = 'Tamano_DUP_Invierno__c';
            campoDiasVencido = 'Dias_desde_Vencido_DUP_Invierno__c';
            campoDiasVencimiento = 'Dias_al_Vencimiento_DUP_Invierno__c';
            campoDiasUtimoContacto =  'Dias_desde_Ultimo_Contacto_DUP_Invierno__c';
        } else {
            campoSegmentacion = 'Cuenta__r.Segmentacion_Productor_Verano__c';
            campoEstado = 'Cuenta__r.Estado_Segun_Patron_DUP_Verano__c';
            campoTamano = 'Tamano_DUP_Verano__c';
            campoDiasVencido = 'Dias_desde_Vencido_DUP_Verano__c';
            campoDiasVencimiento = 'Dias_al_Vencimiento_DUP_Verano__c';
            campoDiasUtimoContacto =  'Dias_desde_Ultimo_Contacto_DUP_Verano__c';
        }
        qry = 'SELECT Cuenta__c FROM Orden_Intragrupo__c';
        String orderBy;
        if(groupNumber == 1){
            orderBy = campoTamano + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_A + '\' AND ' + campoEstado + ' IN (\'' + PriorizacionesUtil.VEN_CAMP_ANT + '\', \'' + PriorizacionesUtil.NO_RESPONDIERON + '\') ORDER BY ' + orderBy;
        } else if(groupNumber == 2){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_A + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VEN + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 3){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencimiento + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_A + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.VIG_CAMP_ANT + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 4){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_B + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.VEN_CAMP_ANT + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 5){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST,' + campoDiasUtimoContacto + ' ASC';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_B + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VEN + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 6){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencimiento + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_B + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.VIG_CAMP_ANT + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 7){
            orderBy = campoTamano + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_B + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NO_RESPONDIERON + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 8){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_C + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.VEN_CAMP_ANT + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 9){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencimiento + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_C + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VEN + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 10){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST,' + campoDiasUtimoContacto + ' ASC';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_C + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.VIG_CAMP_ANT + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 11){
            orderBy = campoTamano + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_C + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NO_RESPONDIERON + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 12){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_D + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.VEN_CAMP_ANT + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 13){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencimiento + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_D + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VEN + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 14){
            orderBy = campoTamano + ' DESC NULLS LAST,' + campoDiasVencido + ' DESC NULLS LAST,' + campoDiasUtimoContacto + ' ASC';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_D + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.VIG_CAMP_ANT + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 15){
            orderBy = campoTamano + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_D + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NO_RESPONDIERON + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 16){
            orderBy = 'Cuenta__r.N_CUIT__c ASC';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_Z + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.SIN_FECHA_CAMP_ANTERIOR + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 17){
            orderBy = campoTamano + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_A + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VIG + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 18){
            orderBy = campoTamano + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_B + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VIG + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 19){
            orderBy = campoTamano + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_C + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VIG + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 20){
            orderBy = campoTamano + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_D + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VIG + '\' ORDER BY ' + orderBy;
        } else if(groupNumber == 21){
            orderBy = campoTamano + ' DESC NULLS LAST';
            qry += ' WHERE ' + campoSegmentacion + ' = \'' + PriorizacionesUtil.TIPO_PROD_Z + '\' AND ' + campoEstado + ' = \'' + PriorizacionesUtil.NEG_VIG + '\' ORDER BY ' + orderBy;
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
                a.Prioridad_DUP_Invierno_Original__c = accountNumber;
                a.Prioridad_DUP_Invierno_Recalculada__c = accountNumber;
            } else {
                a.Prioridad_DUP_Verano_Original__c = accountNumber;
                a.Prioridad_DUP_Verano_Recalculada__c = accountNumber;
            }
            accountNumber++;
            cuentas.add(a);
        }
        update cuentas;
    }
    
    global void finish(Database.BatchableContext BC){
        if(!Test.isRunningTest()){
            if(groupNumber == 21){
                groupNumber = 1;
            } else {
                groupNumber++;
            }
            if(groupNumber == 1 && campanas.size() == 1){
                BatchApexPriorizacionCobranzasUpdate batch = new BatchApexPriorizacionCobranzasUpdate(100000, groupNumber);
                Database.executeBatch(batch, 500);
            } else {
                if(groupNumber == 1 && campanas.size() > 1){
                    campanas.remove(0);
                    accountNumber = 100000;
                }
                BatchApexPriorizacionDUPSUpdate batch = new BatchApexPriorizacionDUPSUpdate(accountNumber, groupNumber, campanas);
                Database.executeBatch(batch, 500);
            }
        }
    }
    
}