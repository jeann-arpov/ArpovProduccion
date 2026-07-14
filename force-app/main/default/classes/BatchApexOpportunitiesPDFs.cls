/**
* @author Maximo Martinez
* @date 10/02/2016
* @description Clase Batcheable que Genera PDFs a Partir de Opportunidades
*/
global class BatchApexOpportunitiesPDFs implements Database.Batchable<sObject>,Database.Stateful, Database.AllowsCallouts{
	
	public List<String> errors;

	global BatchApexOpportunitiesPDFs() {
		this.errors = new List<String>();
	}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator([SELECT Id,Name FROM Opportunity WHERE Generar_PDF_Factura_Electronica__c = true]);
	}

   	global void execute(Database.BatchableContext BC, List<Opportunity> scope) {
		
		Map<Id, List<String>> errorsByOpportunity = new Map<Id, List<String>>();

		Map<Id, Opportunity> opportunitiesById = new Map<Id, Opportunity>();

		List<Attachment> attachemtsToInsert = new List<Attachment>();

		Set<Id> idsOpps = new Set<Id>();

		Set<Id> idsAttachment = new Set<Id>();

        // Obtenemos los ids de las remesas
        for(Opportunity opp : scope){
            idsOpps.add(opp.Id);        
        }

		// Verificamos si las mismas tienen adjuntos
        for(Attachment a : [SELECT ParentId FROM Attachment WHERE ParentId IN :idsOpps]){

            // Si el id esta lo agreguo a la lista
            idsAttachment.add(a.ParentId);

        }

		// Recorro las oportunidades
		for(Opportunity opp : scope){

			// Si esta el PDF, no proceso
			if(idsAttachment.contains(opp.Id)){
				continue;
			}

			try{
                
                // Generamos la URL
                PageReference pdfPage = Page.printSalesElectronicInvoice;
                
                // Seteamos el Id
                pdfPage.getParameters().put('id',opp.Id);
            	
            	// Instanciamos un attachment
                Attachment pdf = new Attachment();

                // Seteamos los atributos
                pdf.Name = opp.Name + '.pdf';
                pdf.ParentId = opp.Id;
                pdf.Body = (Test.isRunningTest())?Blob.valueOf('test'):pdfPage.getContent();
                pdf.ContentType  = 'application/pdf';    
                
                attachemtsToInsert.add(pdf);

                // Agregamos la Opportunidad al map
                opportunitiesById.put(opp.Id, opp);
            
            }catch(Exception e){

            	errors.add(String.format('Error al intentar generar el PDF para la Opportunity Record Id {0}. {1}', new List<String>{opp.Id, e.getMessage()}));

            }

		}

		// Intentamos crear los PDFS
		if(!attachemtsToInsert.isEmpty()){
			
			List<Database.SaveResult> svrs = Utils.insertList(attachemtsToInsert, false);

			// Recorremos los resultados
			for(Integer i = 0; i < svrs.size(); i++){

				Database.SaveResult svr = svrs[i];
				Attachment attach = attachemtsToInsert[i];

				// Si hay error, lo marcamos
				if(!svr.isSuccess()){

	            	for(Database.Error e : svr.getErrors()){
	            		errors.add(String.format('Error al intentar insertar el PDF para la Opportunity Record Id {0}. {1}', new List<String>{attach.ParentId, e.getMessage()}));
            		}

            		// Eliminamos la oportunidad del map
            		opportunitiesById.remove(attach.ParentId);

				}else{

					if(opportunitiesById.containsKey(attach.ParentId)){
						Opportunity opp = opportunitiesById.get(attach.ParentId);
						opp.Generar_PDF_Factura_Electronica__c = false;
	        			opp.Nombre_archivo__c = opp.Name;
        			}

				}

			}

		}

		// Actualizamos las Opportunidades
		if(!opportunitiesById.isEmpty()){

			List<Database.SaveResult> svrs = Utils.updateList(opportunitiesById.values(), false);

			// Recorremos los resultados
			for(Integer i = 0; i < svrs.size(); i++){

				Opportunity opp = opportunitiesById.values()[i];
				Database.SaveResult svr = svrs[i];

				// Verificamos si hay un error
				if(!svr.isSuccess()){
					for(Database.Error e : svr.getErrors()){
	            		errors.add(String.format('Error al intentar actualizar la Opportunity Record Id {0} como procesada. {1}', new List<String>{opp.Id, e.getMessage()}));
            		}
				}

			}

		}

	}
	
	global void finish(Database.BatchableContext bctx) {

		String systemErrors = BatchErrorHelper.getBatchClassErrors(bctx);
        
        if(systemErrors != ''){
            errors.add(systemErrors);
        }
    
        if(!errors.isEmpty()){ // Si ocurrio un error se notifica via email
        
            String message = String.join(errors, '\n');

            System.debug(LoggingLevel.WARN, message);

            try{

                List<String> destinatariosErroresBatchs = BatchErrorHelper.getDestinatariosErroresBatchs();

                if(destinatariosErroresBatchs.isEmpty()){
                    return;
                }

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(destinatariosErroresBatchs);
                mail.setSubject('Errores en BatchApexOpportunitiesPDFs');
                mail.setPlainTextBody(message);
                mail.setSaveAsActivity(false);
                if(!Test.isRunningTest()){
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }
                  
            }catch(Exception e){}  

        }

	}
	
}