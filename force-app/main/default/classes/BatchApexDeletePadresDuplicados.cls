/**
* @author Maximo Martinez
* @date 07/01/2014
* @description Proceso Batch que verifica si hay cuentas con Casos Gestion de Venta y Gestion de CUIT
* @description duplicados. A fin de generar un solo caso de dichos tipos por Cuenta.
*/
global class BatchApexDeletePadresDuplicados implements Database.Batchable<sObject> {
	
	String query;
	
	global BatchApexDeletePadresDuplicados() {

	}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
		
		// Obtenemos el RecordType de Caso Padre Gestion de CUIT
        Id rtGestionCUIT = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');

        // Obtenemos el RecordType de Caso Padre Gestion de CUIT
        Id rtGestionVenta = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_Venta');

        query = 'SELECT Id, (SELECT Id, RecordTypeId, CreatedDate FROM Cases WHERE RecordTypeId =: rtGestionCUIT OR RecordTypeId =:rtGestionVenta) FROM Account'; 	

		return Database.getQueryLocator(query);
	}

   	global void execute(Database.BatchableContext BC, List<Account> scope) {

   		// Map que sirve para indicar cual es el original de casa caso
   		Map<Id, Id> originalByDuplicado = new Map<Id, Id>();
		
		// Recorremos las cuentas
		for(Account a : scope){

			// Verificamos si hay mas de un Caso por tipo de registro
			Map<Id, List<Case>> casosPorRT = new Map<Id, List<Case>>();

			for(Case c : a.Cases){	

				if(!casosPorRT.containsKey(c.RecordTypeId))
					casosPorRT.put(c.RecordTypeId, new List<Case>());

				casosPorRT.get(c.RecordTypeId).add(c);	

			}

			for(Id rtId : casosPorRT.keySet()){

				List<Case> casos = casosPorRT.get(rtId);

				// Verificamos si hay casos Gestion de CUIT ó Gestion de Ventas Duplicados
				if(casos.size() > 1){

					WrapperCasos wc = new WrapperCasos();

					wc.casosDuplicados = new List<Case>();

					for(Case c : casos){

						if(wc.casoOriginal == null){
						
							wc.casoOriginal = c;
						
						}else if(wc.casoOriginal.CreatedDate > c.CreatedDate){
							
							wc.casosDuplicados.add(wc.casoOriginal);

							wc.casoOriginal = c;	

						}else{

							wc.casosDuplicados.add(c);
						
						}

					}

					for(Case c : wc.casosDuplicados){

						originalByDuplicado.put(c.id, wc.casoOriginal.Id);

					}


				}

			}

		}	

		System.debug(LoggingLevel.INFO, originalByDuplicado);

		// Verificamos si en esta iteracion tenemos casos duplicados

		if(!originalByDuplicado.isEmpty()){

			// Procedemos a obtener los datos 

			// Obtenemos todos los casos asociados a los casos padres
			for(List<Case> cs: [SELECT Id, ParentId FROM Case WHERE ParentId IN :originalByDuplicado.keySet()]){

				for(Case c : cs){

					// Obtenemos el original del parent del case
					if(originalByDuplicado.containsKey(c.ParentId)){

						// Obtenemos el original
						Id originalId = originalByDuplicado.get(c.ParentId);

						// Seteamos el parent del case
						c.ParentId = originalId;

					}

				}

				// Hacemos el update
				update cs;

			}

			// Obtenemos todas las Interacciones asociados a los casos padres
			for(List<Interaccion__c> its: [SELECT Id, Caso__c FROM Interaccion__c WHERE Caso__c IN :originalByDuplicado.keySet()]){

				for(Interaccion__c i : its){

					// Obtenemos el original del parent del case
					if(originalByDuplicado.containsKey(i.Caso__c)){

						// Obtenemos el original
						Id originalId = originalByDuplicado.get(i.Caso__c);

						// Seteamos el parent del case
						i.Caso__c = originalId;

					}

				}

				// Hacemos el update
				update its;

			}

			// Obtenemos todas las Task asociados a los casos padres
			for(List<Task> tks: [SELECT Id, WhatId FROM Task WHERE WhatId IN :originalByDuplicado.keySet()]){

				for(Task t : tks){

					// Obtenemos el original del parent del case
					if(originalByDuplicado.containsKey(t.WhatId)){

						// Obtenemos el original
						Id originalId = originalByDuplicado.get(t.WhatId);

						// Seteamos el parent del case
						t.WhatId = originalId;

					}

				}

				// Hacemos el update
				update tks;

			}


			// Obtenemos todos los Event asociados a los casos padres
			for(List<Event> evts: [SELECT Id, WhatId FROM Event WHERE WhatId IN :originalByDuplicado.keySet()]){

				for(Event evt : evts){

					// Obtenemos el original del parent del case
					if(originalByDuplicado.containsKey(evt.WhatId)){

						// Obtenemos el original
						Id originalId = originalByDuplicado.get(evt.WhatId);

						// Seteamos el parent del case
						evt.WhatId = originalId;

					}

				}

				// Hacemos el update
				update evts;

			}

			// Obtenemos todos los Attachment asociados a los casos padres
			for(List<Attachment> ats: [SELECT Body,ContentType,Description,Id, IsPrivate,Name,ParentId FROM Attachment WHERE ParentId IN :originalByDuplicado.keySet()]){

				List<Attachment> atsClones = new List<Attachment>();

				for(Attachment at : ats){

					// Obtenemos el original del parent del case
					if(originalByDuplicado.containsKey(at.ParentId)){

						// Obtenemos el original
						Id originalId = originalByDuplicado.get(at.ParentId);

						// Clonamos el atacchment
						Attachment atsClon = at.clone(false, false);

						atsClon.ParentId = originalId;

						atsClones.add(atsClon);

					}

				}

				// Hacemos el update
				insert atsClones;

				// Eliminamos los viejos archivos
				delete ats;
			}


			// Verificamos que los casos duplicados ya no tengan una relacion con alguno d elos objetos
			// que transferimos al padre y los eliminamos
			for(List<Case> cs : [SELECT Id, (SELECT Id FROM Tasks LIMIT 1), (SELECT Id FROM Events LIMIT 1), (SELECT Id FROM Attachments LIMIT 1), (SELECT Id FROM Cases LIMIT 1), (SELECT Id FROM Interacciones__r LIMIT 1) FROM Case WHERE Id IN :originalByDuplicado.keySet()]){

				List<Case> casesToDelete = new List<Case>();

				for(Case c : cs){

					if(c.Tasks.size() != 0) continue;
					if(c.Events.size() != 0) continue;
					if(c.Attachments.size() != 0) continue;
					if(c.Cases.size() != 0) continue;
					if(c.Interacciones__r.size() != 0) continue;

					// Si esta todo en 0 agregamos el caso a la lista de casos a eliminar
					casesToDelete.add(c);

				}

				// Eliminamos los casos
				delete casesToDelete;

			}

		}

	}
	
	global void finish(Database.BatchableContext BC) {
		
	}

	/**
	* @author Maximo Martinez
	* @date 07/01/2015
	* @description Clase Auxiliar
	*/
	public class WrapperCasos{

		public Case casoOriginal {get; set;}
		public List<Case> casosDuplicados {get; set;}

	}

	
}