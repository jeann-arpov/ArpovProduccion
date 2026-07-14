/**
* @author Maximo Martinez
* @date 24/10/2014
* @description Clase que contiene WebServices para la Generacion de una NC
*/
global class ws_GenerarNC {

	/**
	* @author Maximo Martinez
	* @date 24/10/2014
	* @description WebService llamado desde la Vista para Generar una NC a partir de una DUP
	* @param idTransaccion : id de la Transaccion a partir de la cual se crea una NC
	*/
	@AuraEnabled
	WebService static Result generarNC(String idTransaccion){

		//Instanciamos un objeto Resultado
		Result resultado = new Result();

		//Verificamos que se ha pasado un id de transaccion
		if(idTransaccion != '' && idTransaccion != null){

			//Obtenemos los datos que necesitamos para generar la NC
			List<Transaccion__c> transacciones = [SELECT Id, RecordTypeId, Factura__r.Id, Factura__r.N_de_Comprobante__c FROM Transaccion__c WHERE Id = :idTransaccion LIMIT 1];

			if(transacciones.size() > 0){

				//Verificamos no exista una NC para esta transaccion ya creada
				Integer count = [SELECT COUNT() FROM Transaccion__c WHERE (DUP_Original__c = :idTransaccion OR Auditoria__c = :idTransaccion) AND Subestado__c = 'Negativa'];

				if(count == 0){

					//Obtenemos la transaccion
					Transaccion__c transaccion = transacciones.get(0);

					//Verificamos si la transaccion tiene una Factura
					if(transaccion.Factura__r != null){

						if(transaccion.Factura__r.N_de_Comprobante__c != null){

							try{

								//Obtenemos los RecordType de una Transaccion
								Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');

								Map<Id,List<String>> idsNCs = UtilsTransaccion.generarNCDUPS(new Set<Id>{transaccion.Id});
								
								if(idsNCs.get(transaccion.Id).isEmpty()){

									List<Transaccion__c> nc = [SELECT Id FROM Transaccion__c WHERE (DUP_Original__c = :idTransaccion OR Auditoria__c = :idTransaccion) AND Subestado__c = 'Negativa' ORDER BY CreatedDate DESC LIMIT 1];

									if(!nc.isEmpty()){
										// No ocurrio un error
										resultado.idNC = nc.get(0).Id;
									}

								}else{

									// Ocurrio un error
									resultado.error = String.join(idsNCs.get(transaccion.Id), '\n');

								}
							
							}catch(Exception e){

								resultado.error = e.getMessage();

							}	

						}else{

							resultado.error = Label.Error_Factura_Sin_Comprobante;

						}


					}else{

						resultado.error = Label.Error_Transaccion_Sin_Factura;

					}

				}else{

					resultado.error = Label.Error_Transaccion_Con_NC;

				}

			}else{

				resultado.error = Label.Error_No_Existe_la_Transaccion;

			}

		}

		return resultado;
	}


	/**
	* @author Maximo Martinez
	* @date 24/10/2014
	* @description WebService llamado desde la Vista para Generar una NC a partir de una DUP
	* @param idTransaccion : id de la Transaccion a partir de la cual se crea una NC
	*/
	webService static Result generarNCWithoutMinisiteDate(String idTransaccion){

		//Instanciamos un objeto Resultado
		Result resultado = new Result();

		//Verificamos que se ha pasado un id de transaccion
		if(String.isEmpty(idTransaccion)){
			return resultado;
		}

		//Obtenemos los datos que necesitamos para generar la NC
		List<Transaccion__c> transacciones = [SELECT Id, Subestado__c, RecordTypeId, Factura__r.Id, Factura__r.N_de_Comprobante__c FROM Transaccion__c WHERE Id = :idTransaccion LIMIT 1];

		if(transacciones.isEmpty()){
			resultado.error = Label.Error_No_Existe_la_Transaccion;
			return resultado;
		}


		//Obtenemos la transaccion
		Transaccion__c transaccion = transacciones.get(0);

		if(transaccion.Subestado__c == 'Negativa'){
			resultado.error = 'No puede generar una nota de cr�dito a partir de una transacci�n con subestado negativo.';
			return resultado;
		}

		//Verificamos no exista una NC para esta transaccion ya creada
		Integer count = [SELECT COUNT() FROM Transaccion__c WHERE (DUP_Original__c = :idTransaccion OR Auditoria__c = :idTransaccion) AND Subestado__c = 'Negativa'];

		if(count > 0){
			resultado.error = Label.Error_Transaccion_Con_NC;
			return resultado;
		}

		if(transaccion.Factura__r == null){
			resultado.error = Label.Error_Transaccion_Sin_Factura;
			return resultado;
		}

		if(transaccion.Factura__r.N_de_Comprobante__c == null){
			resultado.error = Label.Error_Factura_Sin_Comprobante;
			return resultado;
		}


		try{

			//Obtenemos los RecordType de una Transaccion
			Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');

			Map<Id,List<String>> idsNCs = UtilsTransaccion.generarNCDUPS(new Set<Id>{transaccion.Id},true);
			
			if(idsNCs.get(transaccion.Id).isEmpty()){

				List<Transaccion__c> nc = [SELECT Id FROM Transaccion__c WHERE (DUP_Original__c = :idTransaccion OR Auditoria__c = :idTransaccion) AND Subestado__c = 'Negativa' ORDER BY CreatedDate DESC LIMIT 1];

				if(!nc.isEmpty()){
					// No ocurrio un error
					resultado.idNC = nc.get(0).Id;
				}

			}else{

				// Ocurrio un error
				resultado.error = String.join(idsNCs.get(transaccion.Id), '\n');

			}
		
		}catch(Exception e){

			resultado.error = e.getMessage();

		}

		return resultado;

	}


	/**
    * @author Maximo Martinez
    * @date 24/10/2014
    * @description Clase Auxiliar que representa el resultado que envia el WebServices
    */
    global class Result{
		@AuraEnabled
        WebService String error {get; set;}
        @AuraEnabled
		WebService Id idNC {get; set;} 
    }

}