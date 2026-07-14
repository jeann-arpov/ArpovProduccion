/**
* @author Maximo Martinez
* @date 16/09/2018
* @description Clase Batcheable que Genera Avisos de Vencimientos de Facturas
*/
public with sharing class BatchApexSetCamposTransEnCuenta implements Database.Batchable<sObject>, Database.Stateful{
    
    public List<String> errors = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Id idRecordId = Schema.SObjectType.Transaccion__c.getRecordTypeInfosByDeveloperName().get('DUP').getRecordTypeId();
        return Database.getQueryLocator('SELECT Id, Descripcion_del_Lote__c, Nombre_de_la_cuenta__c, Campana__r.Temporada__c FROM Transaccion__c WHERE RecordTypeId = :idRecordId AND Campana__r.Estado__c = \'Activa\' ORDER BY Nombre_de_la_cuenta__c');
    }

    public void execute(Database.BatchableContext BC, List<Transaccion__c> scope) {

        Map<Id,Wrapper> wrappersByAccountId = new Map<Id,Wrapper>();

        List<Account> accountsToUpdate = new List<Account>();

        for(Transaccion__c t : scope){
            
            Wrapper wp = (!wrappersByAccountId.containsKey(t.Nombre_de_la_cuenta__c)) ? new Wrapper() : wrappersByAccountId.get(t.Nombre_de_la_cuenta__c);
            wp.transaccionesDeDUPSInviernoCreadas += (String.isNotEmpty(t.Campana__r.Temporada__c) && t.Campana__r.Temporada__c.toLowerCase() == 'invierno') ? 1 : 0;
            wp.transaccionesDeDUPSVeranoCreadas += (String.isNotEmpty(t.Campana__r.Temporada__c) && t.Campana__r.Temporada__c.toLowerCase() == 'verano') ? 1 : 0;
            wp.transaccionesLoteCaidosVerano += (String.isNotEmpty(t.Descripcion_del_Lote__c) && t.Descripcion_del_Lote__c.toLowerCase().contains('caidos') && t.Campana__r.Temporada__c.toLowerCase() == 'verano') ? 1 : 0;
            wp.transaccionesLoteCaidosInvierno += (String.isNotEmpty(t.Descripcion_del_Lote__c) && t.Descripcion_del_Lote__c.toLowerCase().contains('caidos') && t.Campana__r.Temporada__c.toLowerCase() == 'invierno') ? 1 : 0;
            
            wrappersByAccountId.put(t.Nombre_de_la_cuenta__c,wp);

        }

        for(Account acc : [SELECT Id, DUPs_creadas_camp_Invierno__c, DUPs_creadas_camp_Verano__c, DUPs_Lote_Caidos_Invierno__c,  DUPs_Lote_Caidos_Verano__c FROM Account WHERE Id IN :wrappersByAccountId.keySet()]){
            
            if(!wrappersByAccountId.containsKey(acc.Id)){
                continue;
            }

            Wrapper wp = wrappersByAccountId.get(acc.Id);

            acc.DUPs_creadas_camp_Invierno__c = (acc.DUPs_creadas_camp_Invierno__c  == null) ? wp.transaccionesDeDUPSInviernoCreadas : acc.DUPs_creadas_camp_Invierno__c + wp.transaccionesDeDUPSInviernoCreadas;
            acc.DUPs_creadas_camp_Verano__c = (acc.DUPs_creadas_camp_Verano__c == null) ? wp.transaccionesDeDUPSVeranoCreadas : acc.DUPs_creadas_camp_Verano__c + wp.transaccionesDeDUPSVeranoCreadas;
            acc.DUPs_Lote_Caidos_Invierno__c = (acc.DUPs_Lote_Caidos_Invierno__c == null) ? wp.transaccionesLoteCaidosInvierno : acc.DUPs_Lote_Caidos_Invierno__c + wp.transaccionesLoteCaidosInvierno;
            acc.DUPs_Lote_Caidos_Verano__c = (acc.DUPs_Lote_Caidos_Verano__c == null) ? wp.transaccionesLoteCaidosVerano : acc.DUPs_Lote_Caidos_Verano__c + wp.transaccionesLoteCaidosVerano;

            accountsToUpdate.add(acc);

        }

        List<Database.SaveResult> svsrs = Database.update(accountsToUpdate,false);

        for(Database.SaveResult svr : svsrs){

            if(!svr.isSuccess()){
                this.errors.add(svr.getErrors()[0].getMessage());
            }
                
        }

    }

    public class Wrapper{

        public Integer transaccionesDeDUPSInviernoCreadas = 0;
        public Integer transaccionesDeDUPSVeranoCreadas = 0;
        public Integer transaccionesLoteCaidosInvierno = 0;
        public Integer transaccionesLoteCaidosVerano = 0;

    }

    public void finish(Database.BatchableContext BC) {

        List<String> destinatariosErroresBatchs = BatchErrorHelper.getDestinatariosErroresBatchs();

        String systemErrors = BatchErrorHelper.getBatchClassErrors(BC);
        
        if(systemErrors != ''){
            errors.add(systemErrors);
        }
    
        if(!errors.isEmpty()){ // Si ocurrio un error se notifica via email
        
            String message = String.join(errors, '\n');

            System.debug(LoggingLevel.INFO,message);

            try{

                if(destinatariosErroresBatchs.isEmpty()){
                    return;
                }

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(destinatariosErroresBatchs);
                mail.setSubject('Arpov: Errores en BatchApexSetearCamposTransaccionesEnCuenta');
                mail.setPlainTextBody(message);
                mail.setSaveAsActivity(false);
                if(!Test.isRunningTest()){
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }
                  
            }catch(Exception e){}  


        }


    }


}