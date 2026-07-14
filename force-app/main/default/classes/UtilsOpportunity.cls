/**
* @author Maximo Martinez
* @date 27/10/2014
* @description Clase Auxiliar del Objecto Opportunity
*/
public with sharing class UtilsOpportunity {

	
	/**
	* @author Maximo Martinez
	* @date 06/06/2014
	* @description Metodo que a partir de una Opportunidad FC la asocia a la NC correspondiente
	*/
	public static void asociaNCToFC(Set<Id> idsOpps){

		//RecordType de una Transaccion DUP
		Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');

		//RecordType de una Transaccion Aud
		Id rtAud = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');

		//Lista de Facturas a actualizar
		List<Opportunity> toUpdate = new List<Opportunity>();

		// Set para comprobar que no se procesa ya la pareja NC/FC
		Set<Id> idsProcesedOpps = new Set<Id>();

		//Obtengo los ids de las transacciones que cuyo subestado es 'Positiva'
		for(Transaccion__c transaccion : [SELECT Id, RecordTypeId, Auditoria__r.Factura__r.Id, DUP_Original__r.Factura__r.Id, Factura__r.Id FROM Transaccion__c WHERE ( ( RecordTypeId =:rtDup OR RecordTypeId =:rtAud ) AND Subestado__c = 'Negativa' AND ( ( DUP_Original__r.Factura__c IN :idsOpps AND DUP_Original__r.Factura__r.Tipo_de_Comprobante__c = 'FC' ) OR ( Auditoria__r.Factura__c IN :idsOpps AND Auditoria__r.Factura__r.Tipo_de_Comprobante__c = 'FC' ) ) AND Factura__r.Tipo_de_Comprobante__c = 'NC' ) OR ( ( RecordTypeId =:rtDup OR RecordTypeId =:rtAud ) AND Subestado__c = 'Negativa' AND Factura__c IN :idsOpps AND ( DUP_Original__r.Factura__r.Tipo_de_Comprobante__c = 'FC' OR  Auditoria__r.Factura__r.Tipo_de_Comprobante__c = 'FC' ) AND Factura__r.Tipo_de_Comprobante__c = 'NC' AND ( DUP_Original__r.Factura__c != null OR Auditoria__r.Factura__c != null ))]){
			
			Opportunity oppFC = null;

			Opportunity oppNC = transaccion.Factura__r;

			// Si ya se proceso la NC 
			if(idsProcesedOpps.contains(oppNC.Id))continue;

			// Si es una DUP se hace el siguiente procesamiento	
			if(transaccion.RecordTypeId == rtDup){

				//Obtengo la Factura FC de la DUP Original original
				oppFC = transaccion.DUP_Original__r.Factura__r;

			}else{ // Si es una AUD se procesa asi

				//Obtengo la Factura FC de la DUP Original original
				oppFC = transaccion.Auditoria__r.Factura__r;

			}

			//Relaciono la NC con la FC
			oppNC.Factura__c = oppFC.Id;

			//Cambio el saldo a cobrar comprobante de la factura fc a "0"
			//oppFC.Saldo_a_Gestionar__c = 0;

			oppFC.Saldo_a_Cobrar_Comprobante__c = 0;

			oppFC.Saldo_a_Gestionar__c = 0;

			toUpdate.add(oppFC);

			toUpdate.add(oppNC);

			idsProcesedOpps.add(oppNC.Id);

		}


		if(toUpdate.size() > 0)
			Utils.updateList((List<SObject>)toUpdate);

	}

}