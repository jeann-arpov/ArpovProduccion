/**
* @author Maximo Martinez
* @date 12/06/2018
* @description Clase controladora de la EmailTemplateFacturasProximasAVencer
*/
public with sharing class EmailTemplateFacturasProximasAVencerCtrl {
	
	private Id accountId;
	public Date dueDate {get; set;}
	public String cultivoName {get; set;}

	public EmailTemplateFacturasProximasAVencerCtrl() {
		
		accountId = ApexPages.currentPage().getParameters().get('accountId');
		dueDate = Date.valueOf(ApexPages.currentPage().getParameters().get('dueDate'));
		cultivoName = ApexPages.currentPage().getParameters().get('nameCultivo');

		System.debug(LoggingLevel.WARN,accountId);
		System.debug(LoggingLevel.WARN,dueDate);
		System.debug(LoggingLevel.WARN,cultivoName);

	}

	public List<Wrapper> getOpportunities(){
		
		List<Wrapper> result = new List<Wrapper>();
		
		for(Opportunity o : [SELECT Id, Divisa_Comprobante__c, Fecha_Emision_Comprobante__c, Obtentor__r.Name, N_de_Comprobante__c, Tipo_de_Comprobante__c, Saldo_a_Cobrar_Comprobante__c, Total_Comprobante__c, Fecha_Vencimiento_Comprobante__c FROM Opportunity WHERE ( Tipo_de_Comprobante__c = 'FC' OR Tipo_de_Comprobante__c = 'ND') AND Fecha_Vencimiento_Comprobante__c = :dueDate AND AccountId = :accountId AND Cultivo__c = :cultivoName AND Saldo_a_Cobrar_Comprobante__c > 0]){

			if(o.Saldo_a_Cobrar_Comprobante__c  !=  o.Total_Comprobante__c){
                continue;
            }

            result.add(new Wrapper(o));

		}

		return result;

	}

	public Account getAccount(){
		return [SELECT Id, Name FROM Account WHERE Id = :accountId];
	}

	public class Wrapper{
		public String formatedSaldoACobrarComprobante {get; set;}
		public String formatedTotalComprobante {get; set;}
		public Opportunity o {get; set;}

		public Wrapper(Opportunity o){
			this.o = o;
			this.formatedTotalComprobante = o.Divisa_Comprobante__c +' '+ Utils.doFormatting(o.Total_Comprobante__c, 2, '.', ',');
			this.formatedSaldoACobrarComprobante = o.Divisa_Comprobante__c +' '+ Utils.doFormatting(o.Saldo_a_Cobrar_Comprobante__c, 2, '.', ',');
		}

	}

}