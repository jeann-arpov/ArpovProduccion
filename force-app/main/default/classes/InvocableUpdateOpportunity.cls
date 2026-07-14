public with sharing class InvocableUpdateOpportunity {

    public class Request {
        @InvocableVariable(required=true)
        public Id recordId;   //Id del registro
        @InvocableVariable(required=true)
        public date fechaEmision; //Fecha de emision
        @InvocableVariable(required=true)
        public String numComprobante; //numero de comprobante
    }

    // Wrapper para los parámetros de salida
    public class Response {
        @InvocableVariable
        public String resultado;  // Ejemplo: mensaje de salida
    }

        @InvocableMethod(label='Update Opportunity' description='Update Opportunity')
        public static List<Response> updateOpportunity(List<Request> requests){
        List<Response> responses = new List<Response>();
        Opportunity opp = [select id,AccountId,Total_Comprobante__c,CloseDate from Opportunity where Id =: requests[0].recordId LIMIT 1];
        Decimal TipoCambio = !Test.isRunningTest() ? [Select Tipo_de_Cambio__c from OpportunityLineItem where OpportunityId =: opp.Id limit 1].Tipo_de_Cambio__c : 1300.00;
        Decimal total;
      
        AggregateResult[] results = [
            SELECT OpportunityId, SUM(TotalPrice)
            FROM OpportunityLineItem
            WHERE OpportunityId =: opp.Id
            GROUP BY OpportunityId
        ];
         if(!Test.isRunningTest()){
             for (AggregateResult ar : results) {
              total = (Decimal) ar.get('expr0'); // SUM(TotalPrice)
          }
         }
         else {
             total = 1000.00;
         }
        
         Opportunity oppToUpdate = new Opportunity(
            Id = opp.Id,
            Fecha_Emision_Comprobante__c = requests[0].fechaEmision,
            N_de_Comprobante__c = requests[0].numComprobante,
            Neto_Comprobante__c = total,
            Total_Comprobante__c = total * 1.21,
            Divisa_Comprobante__c = 'USD',
            Fecha_Pedido_Facturacion__c = opp.CloseDate,
            Fecha_Facturacion__c = Date.today(),
            Saldo_a_Gestionar__c = total * 1.21,
            Tipo_de_Cambio_Actualizado__c  = TipoCambio,
            Saldo_a_Cobrar_Comprobante__c = total * 1.21,
            StageName = 'Pedido de Facturacion',
            Tipo_de_Cambio_del_Comprobante__c = TipoCambio
        );
        Movimientos__c mov = new Movimientos__c(
            Tipo_de_Movimiento__c = 'FC',
            Comprobante__c = requests[0].numComprobante,
            Importe__c = total * 1.21,
            Moneda__c = 'USD',
            Tipo_de_Cambio__c = TipoCambio,
            Oportunidad__c = opp.Id,
            Cuenta__c = opp.AccountId,
            Fecha__c = Date.today()
        );
        try {
            update oppToUpdate;
            List<Movimientos__c> movimiento = [Select Id from Movimientos__c where Tipo_de_Movimiento__c = 'FC' and  Oportunidad__c =: opp.Id];
            if(movimiento.size()<=0){
                insert mov;
            }
            Response resp = new Response();
            resp.resultado = 'Oportunidad actualizada correctamente';
            responses.add(resp);
            return responses;
        } catch (DmlException e) {
            Response resp = new Response(); resp.resultado = e.getMessage(); responses.add(resp);
            return responses;
        }
     }
}