/**
* @author Maximo Martinez
* @date 13/06/2017
* @description Clase Gestion De Cuentas Controller
*/
public with sharing class GestionDeCuentasController {

	/**
	* @author Maximo Martinez
	* @date 13/06/2018
	* @description Fuentes de Interacciones
	*/
	public static String SOURCE_INTERACTION_WHATSLLY = '[Whatslly]';

	/**
	* @author Maximo Martinez
	* @date 13/06/2018
	* @description Modos de Contactos
	*/
	public static String CONTACT_MODE_WHATSAPP = 'Whatsapp';
	public static String CONTACT_MODE_EMAIL_ENTRANTE = 'Email Entrante';
	public static String CONTACT_MODE_EMAIL_SALIENTE = 'Email Saliente';

	/**
	* @author Maximo Martinez
	* @date 13/06/2018
	* @description Developer Names de RecordTypes
	*/
	public static String DOCUMENTO_GESTIONADO_DEVELOPER_NAME_FACTURA = 'Factura';
	public static String DOCUMENTO_GESTIONADO_DEVELOPER_NAME_DUP = 'DUP';
	public static String DOCUMENTO_GESTIONADO_DEVELOPER_NAME_AUDITORIA = 'Auditoria';
	public static String DOCUMENTO_GESTIONADO_DEVELOPER_NAME_VENTAS = 'Ventas';
	
	/**
	* @author Maximo Martinez
	* @date 13/06/2018
	* @description Setea en la cuenta el ultimo resultado de gestion de una tarea Gestion DUP ó Gestion Cobranza
	*/
	public void setUltimoResultadoGestion(List<Interaccion_Nueva__c> interacciones){

		Map<Id,Account> accountsByIds = new Map<Id,Account>();

		for(Interaccion_Nueva__c i : interacciones){
			if(String.isNotEmpty(i.Cuenta__c)){
				accountsByIds.put(i.Cuenta__c,new Account(Id=i.Cuenta__c, Ultimo_resultado_Gestion__c = i.Accion__c));
			}
		}

		if(accountsByIds.isEmpty()){
			return;
		}

		update accountsByIds.values();

	}

	/**
	* @author Maximo Martinez
	* @date 13/06/2018
	* @description Setea en la cuenta la fecha de ultima de gestion de una tarea Gestion DUP ó Gestion Cobranza
	*/
	public void setFechaUltimaGestion(List<Documento_Gestionado__c> documentosGestionados){

		
	 	Id rtFactura = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Factura');
        Id rtDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('DUP');
        Id rtAuditoria = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Auditoria');
        Id rtVentas = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Ventas');


		Map<Id,Account> accountsToUpdate = new Map<Id,Account>();

		Map<Id,Map<Id,Documento_Gestionado__c>> recordTypesDocsGestionadosByInteraccionIds = new Map<Id,Map<Id,Documento_Gestionado__c>>();
		
		Map<Id,Campana_Agricola__c> campanasById = new Map<Id,Campana_Agricola__c>();

		Set<Id> campanasIds = new Set<Id>();

		for(Documento_Gestionado__c dg : documentosGestionados){

			if(!recordTypesDocsGestionadosByInteraccionIds.containsKey(dg.Gestion_Nueva__c)){
				recordTypesDocsGestionadosByInteraccionIds.put(dg.Gestion_Nueva__c, new Map<Id,Documento_Gestionado__c>());
			}

			recordTypesDocsGestionadosByInteraccionIds.get(dg.Gestion_Nueva__c).put(dg.RecordTypeId,dg);

			campanasIds.add(dg.Campania_Gestion__c);

		}

		for(Campana_Agricola__c ca : [SELECT Id, Temporada__c, Name FROM Campana_Agricola__c]){
			campanasById.put(ca.Id,ca);
		}

		// Si hay tasks para procesar, entonces hacemos una query a account, porque necesitamos saber
		// la ultima fecha de gestion dup
		if(recordTypesDocsGestionadosByInteraccionIds.isEmpty()){
			return;
		}


		for(Interaccion_Nueva__c i : [SELECT Id, Fecha_y_Hora__c, Cuenta__c, Cuenta__r.Resultado_Ult_Gestion_Auditoria__c, Cuenta__r.Resultado_Ult_Gestion_Venta__c, Cuenta__r.Resultado_Ult_Gestion_Cobranza__c, Cuenta__r.Resultado_Ult_Gestion_DUP__c,  Cuenta__r.Fecha_Ultima_Gestion_Ventas__c, Cuenta__r.Fecha_Ultima_Gestion_Dup__c, Cuenta__r.Fecha_Ultima_Gestion_Cobranza__c, Cuenta__r.Fecha_Ultima_Gestion_Auditoria__c, Cuenta__r.Fec_Comp_Rpta_Campana_Verano__c, Cuenta__r.Fec_Comp_Rpta_Campana_Invierno__c, Cuenta__r.Fec_Comp_Pago_Campana_Verano__c, Cuenta__r.Fec_Comp_Pago_Campana_Invierno__c FROM Interaccion_Nueva__c WHERE Id IN :recordTypesDocsGestionadosByInteraccionIds.keySet()]){

			Account a = i.Cuenta__r;

			if(accountsToUpdate.containsKey(i.Cuenta__c)){
				a = accountsToUpdate.get(i.Cuenta__c);
			}

			Date fechaUltimaGestionDup = a.Fecha_Ultima_Gestion_Dup__c;
			Date fechaUltimaGestionCobranza = a.Fecha_Ultima_Gestion_Cobranza__c;
			Date fechaUltimaGestionVentas = a.Fecha_Ultima_Gestion_Ventas__c;
			Date fechaUltimaGestionAuditoria = a.Fecha_Ultima_Gestion_Auditoria__c;

			Date fechaComprometidaPagoCampanaInvierno = a.Fec_Comp_Pago_Campana_Invierno__c;
			Date fechaComprometidaPagoCampanaVerano = a.Fec_Comp_Pago_Campana_Verano__c;
			Date fechaComprometidaRespuestaCampanaVerano = a.Fec_Comp_Rpta_Campana_Verano__c;
			Date fechaComprometidaRespuestaCampanaInvierno = a.Fec_Comp_Rpta_Campana_Invierno__c;

			String resultadoUltimaGestionDup;
			String resultadoUltimaGestionCobranza;
			String resultadoUltimaGestionVentas;
			String resultadoUltimaGestionAuditoria;

			Map<Id,Documento_Gestionado__c> docsGestionadoByRecordType = recordTypesDocsGestionadosByInteraccionIds.get(i.Id);

			if(docsGestionadoByRecordType.containsKey(rtDUP) && (fechaUltimaGestionDup == null || fechaUltimaGestionDup < i.Fecha_y_Hora__c)){
				fechaUltimaGestionDup = Date.newinstance(i.Fecha_y_Hora__c.year(), i.Fecha_y_Hora__c.month(), i.Fecha_y_Hora__c.day());
				resultadoUltimaGestionDup = docsGestionadoByRecordType.get(rtDUP).Resultado__c;
			}else if(docsGestionadoByRecordType.containsKey(rtDUP) && fechaUltimaGestionDup == i.Fecha_y_Hora__c){
				resultadoUltimaGestionDup = docsGestionadoByRecordType.get(rtDUP).Resultado__c;
			}

			if(docsGestionadoByRecordType.containsKey(rtFactura) && (fechaUltimaGestionCobranza == null || fechaUltimaGestionCobranza < i.Fecha_y_Hora__c)){
				fechaUltimaGestionCobranza = Date.newinstance(i.Fecha_y_Hora__c.year(), i.Fecha_y_Hora__c.month(), i.Fecha_y_Hora__c.day());
				resultadoUltimaGestionCobranza = docsGestionadoByRecordType.get(rtFactura).Resultado__c;
			}else if(docsGestionadoByRecordType.containsKey(rtFactura) && fechaUltimaGestionCobranza == i.Fecha_y_Hora__c){
				resultadoUltimaGestionCobranza = docsGestionadoByRecordType.get(rtFactura).Resultado__c;
			}

			if(docsGestionadoByRecordType.containsKey(rtVentas) && (fechaUltimaGestionVentas == null || fechaUltimaGestionVentas < i.Fecha_y_Hora__c)){
				fechaUltimaGestionVentas = Date.newinstance(i.Fecha_y_Hora__c.year(), i.Fecha_y_Hora__c.month(), i.Fecha_y_Hora__c.day());
				resultadoUltimaGestionVentas = docsGestionadoByRecordType.get(rtVentas).Resultado__c;
			}else if(docsGestionadoByRecordType.containsKey(rtVentas) && fechaUltimaGestionVentas == i.Fecha_y_Hora__c){
				resultadoUltimaGestionVentas = docsGestionadoByRecordType.get(rtVentas).Resultado__c;
			}

			if(docsGestionadoByRecordType.containsKey(rtAuditoria) && (fechaUltimaGestionAuditoria == null || fechaUltimaGestionAuditoria < i.Fecha_y_Hora__c)){
				fechaUltimaGestionAuditoria = Date.newinstance(i.Fecha_y_Hora__c.year(), i.Fecha_y_Hora__c.month(), i.Fecha_y_Hora__c.day());
				resultadoUltimaGestionAuditoria = docsGestionadoByRecordType.get(rtAuditoria).Resultado__c;
			}else if(docsGestionadoByRecordType.containsKey(rtAuditoria) && fechaUltimaGestionAuditoria == i.Fecha_y_Hora__c){
				resultadoUltimaGestionAuditoria = docsGestionadoByRecordType.get(rtAuditoria).Resultado__c;
			}

			// Logica para las fecha comprometidas de pago y respuesta Verano/Invierno

			if(docsGestionadoByRecordType.containsKey(rtFactura) && campanasById.containsKey(docsGestionadoByRecordType.get(rtFactura).Campania_Gestion__c) && campanasById.get(docsGestionadoByRecordType.get(rtFactura).Campania_Gestion__c).Temporada__c == 'Invierno' && (fechaComprometidaPagoCampanaInvierno == null || fechaComprometidaPagoCampanaInvierno < docsGestionadoByRecordType.get(rtFactura).Fecha_Comprometida_Pago__c)){
				fechaComprometidaPagoCampanaInvierno = docsGestionadoByRecordType.get(rtFactura).Fecha_Comprometida_Pago__c;
			}else if(docsGestionadoByRecordType.containsKey(rtFactura) && campanasById.containsKey(docsGestionadoByRecordType.get(rtFactura).Campania_Gestion__c)  && campanasById.get(docsGestionadoByRecordType.get(rtFactura).Campania_Gestion__c).Temporada__c == 'Verano' && (fechaComprometidaPagoCampanaVerano == null || fechaComprometidaPagoCampanaVerano < docsGestionadoByRecordType.get(rtFactura).Fecha_Comprometida_Pago__c)){
				fechaComprometidaPagoCampanaVerano = docsGestionadoByRecordType.get(rtFactura).Fecha_Comprometida_Pago__c;
			}

			if(docsGestionadoByRecordType.containsKey(rtDUP) && campanasById.containsKey(docsGestionadoByRecordType.get(rtDUP).Campania_Gestion__c)  && campanasById.get(docsGestionadoByRecordType.get(rtDUP).Campania_Gestion__c).Temporada__c == 'Invierno' && (fechaComprometidaRespuestaCampanaInvierno == null || fechaComprometidaRespuestaCampanaInvierno < docsGestionadoByRecordType.get(rtDUP).Fecha_Comprometida_Respuesta__c)){
				fechaComprometidaRespuestaCampanaInvierno = docsGestionadoByRecordType.get(rtDUP).Fecha_Comprometida_Respuesta__c;
			}else if(docsGestionadoByRecordType.containsKey(rtDUP) && campanasById.containsKey(docsGestionadoByRecordType.get(rtDUP).Campania_Gestion__c)  && campanasById.get(docsGestionadoByRecordType.get(rtDUP).Campania_Gestion__c).Temporada__c == 'Verano' && (fechaComprometidaRespuestaCampanaVerano == null || fechaComprometidaRespuestaCampanaVerano < docsGestionadoByRecordType.get(rtDUP).Fecha_Comprometida_Respuesta__c)){
				fechaComprometidaRespuestaCampanaVerano = docsGestionadoByRecordType.get(rtDUP).Fecha_Comprometida_Respuesta__c;
			}


			if(a.Fecha_Ultima_Gestion_Dup__c != fechaUltimaGestionDup 
				|| a.Fecha_Ultima_Gestion_Cobranza__c != fechaUltimaGestionCobranza 
				|| a.Fecha_Ultima_Gestion_Ventas__c != fechaUltimaGestionVentas
				|| a.Fecha_Ultima_Gestion_Auditoria__c != fechaUltimaGestionAuditoria
				|| a.Resultado_Ult_Gestion_Auditoria__c != resultadoUltimaGestionAuditoria
				|| a.Resultado_Ult_Gestion_Venta__c != resultadoUltimaGestionVentas
				|| a.Resultado_Ult_Gestion_Cobranza__c != resultadoUltimaGestionCobranza
				|| a.Resultado_Ult_Gestion_DUP__c != resultadoUltimaGestionDup
				|| a.Fec_Comp_Pago_Campana_Invierno__c != fechaComprometidaPagoCampanaInvierno 
				|| a.Fec_Comp_Pago_Campana_Verano__c != fechaComprometidaPagoCampanaVerano
				|| a.Fec_Comp_Rpta_Campana_Verano__c != fechaComprometidaRespuestaCampanaVerano
				|| a.Fec_Comp_Rpta_Campana_Invierno__c != fechaComprometidaRespuestaCampanaInvierno){

				if(a.Fecha_Ultima_Gestion_Dup__c != fechaUltimaGestionDup){
					a.Fecha_Ultima_Gestion_Dup__c = fechaUltimaGestionDup;
				}

				if(a.Fecha_Ultima_Gestion_Cobranza__c != fechaUltimaGestionCobranza){
					a.Fecha_Ultima_Gestion_Cobranza__c = fechaUltimaGestionCobranza;
				}

				if(a.Fecha_Ultima_Gestion_Ventas__c != fechaUltimaGestionVentas){
					a.Fecha_Ultima_Gestion_Ventas__c = fechaUltimaGestionVentas;
				}

				if(a.Fecha_Ultima_Gestion_Auditoria__c != fechaUltimaGestionAuditoria){
					a.Fecha_Ultima_Gestion_Auditoria__c = fechaUltimaGestionAuditoria;
				}

				if(a.Resultado_Ult_Gestion_Auditoria__c != resultadoUltimaGestionAuditoria){
					a.Resultado_Ult_Gestion_Auditoria__c = resultadoUltimaGestionAuditoria;
				}

				if(a.Resultado_Ult_Gestion_Venta__c != resultadoUltimaGestionVentas){
					a.Resultado_Ult_Gestion_Venta__c = resultadoUltimaGestionVentas;
				}
				
				if(a.Resultado_Ult_Gestion_Cobranza__c != resultadoUltimaGestionCobranza){
					a.Resultado_Ult_Gestion_Cobranza__c = resultadoUltimaGestionCobranza;
				}

				if(a.Resultado_Ult_Gestion_DUP__c != resultadoUltimaGestionDup){
					a.Resultado_Ult_Gestion_DUP__c = resultadoUltimaGestionDup;
				}

				if(a.Fec_Comp_Pago_Campana_Invierno__c != fechaComprometidaPagoCampanaInvierno){
					a.Fec_Comp_Pago_Campana_Invierno__c = fechaComprometidaPagoCampanaInvierno;
				}
				
				if(a.Fec_Comp_Pago_Campana_Verano__c != fechaComprometidaPagoCampanaVerano){
					a.Fec_Comp_Pago_Campana_Verano__c = fechaComprometidaPagoCampanaVerano;
				}
				
				if(a.Fec_Comp_Rpta_Campana_Verano__c != fechaComprometidaRespuestaCampanaVerano){
					a.Fec_Comp_Rpta_Campana_Verano__c = fechaComprometidaRespuestaCampanaVerano;
				}
				
				if(a.Fec_Comp_Rpta_Campana_Invierno__c != fechaComprometidaRespuestaCampanaInvierno){
					a.Fec_Comp_Rpta_Campana_Invierno__c = fechaComprometidaRespuestaCampanaInvierno;
				}

				accountsToUpdate.put(a.Id,a);
			
			}

		}

		update accountsToUpdate.values();

	}


	/**
	* @author Maximo Martinez
	* @date 13/06/2017
	* @description Crea un objeto Gestion al crear una tarea 
	*/
	public abstract class GestionHandler{

		private List<Interaccion_Nueva__c> interaccionesToInsert = new List<Interaccion_Nueva__c>();
		private List<GestionDeCuentasController.Interaccion> interacciones;
		private Map<Id,GestionDeCuentasController.Interaccion> interaccionesBySobjectId = new Map<Id,GestionDeCuentasController.Interaccion>();
		private Map<String,DocumentoGestionadoHandler> estrategias = new Map<String,DocumentoGestionadoHandler>();

		public GestionHandler(List<GestionDeCuentasController.Interaccion> interacciones){
			this.interacciones = interacciones;
		}

		private abstract void processInteracciones();

		private virtual void processDocumentosGestionados(){

			List<Documento_Gestionado__c> docsToInsert = new List<Documento_Gestionado__c>();
			
			// Recorremos las estrategias y obtenemos los documentos gestionados a insertar
			for(DocumentoGestionadoHandler dgh : estrategias.values()){
				docsToInsert.addAll(dgh.getDocumentosGestionados());
			}

			// Insertamos los documentos gestionados
			insert docsToInsert;

		}

		public void createGestionesFromSObjects(){

			List<Campana_Agricola__c> campanaAgricolas = getCampanaAgricola();

			// Revisamos si la tarea es de gestion de cobranza ó gestion de dup
			for(GestionDeCuentasController.Interaccion inte : interacciones){
			
				// Creamos por cada SOBject, una gestion
				Interaccion_Nueva__c interaccion = new Interaccion_Nueva__c();
				interaccion.IsUpdatable__c = inte.isUpdateable;
				interaccion.Modo_de_Contacto__c = inte.modoDeContacto;
				interaccion.Cuenta__c = inte.cuenta;
				interaccion.Fecha_y_Hora__c = inte.fechaHora;
				interaccion.Id_Correo_Electronico__c = inte.idCorreoElectronico;

				interaccionesToInsert.add(interaccion);

				// Guardamos la interaccion en la clase wrapper que venimos usando
				inte.inte = interaccion;

				// Coleccionamos el id de los sobjects
				interaccionesBySobjectId.put(inte.sobj.Id,inte);

				if(inte.documentosGestionadosRecordTypes == null || inte.documentosGestionadosRecordTypes.isEmpty()){
					continue;
				}

				for(Schema.RecordTypeInfo rtInfo : inte.documentosGestionadosRecordTypes){

					if(!estrategias.containsKey(rtInfo.getDeveloperName())){
						Type t = Type.forName(String.format('GestionDeCuentasController.DocumentoGestionado{0}Handler', new List<String>{rtInfo.getDeveloperName()}));
						DocumentoGestionadoHandler dgh = (DocumentoGestionadoHandler)t.newInstance();
						dgh.setCampaniaAgricola(campanaAgricolas[0]);
						dgh.setRecordTypeInfo(rtInfo);
						estrategias.put(rtInfo.getDeveloperName(), dgh);
					}

					estrategias.get(rtInfo.getDeveloperName()).addInteraccion(interaccion);

				}
				

			}

			processInteracciones();

			processDocumentosGestionados();

		}

	}

	public class GestionEmailMessageHandler extends GestionHandler{

		public GestionEmailMessageHandler(List<GestionDeCuentasController.Interaccion> interacciones){
			super(interacciones);
		}

		private override void processInteracciones(){
			// Insertamos las Interacciones
			upsert interaccionesToInsert Interaccion_Nueva__c.Fields.Id_Correo_Electronico__c;
		}

	}

	public class GestionTaskHandler extends GestionHandler{

		public GestionTaskHandler(List<GestionDeCuentasController.Interaccion> interacciones){
			super(interacciones);
		}

		private override void processInteracciones(){

			List<SObject> sobjectToUpdate = new List<SObject>();

			// Insertamos las Interacciones
			insert interaccionesToInsert;

			// Procesamos las tareas que quedaron a fin de vincular las interacciones a las tareas
			for(GestionDeCuentasController.Interaccion inte : interacciones){

				if(String.isEmpty(inte.inte.Id)){
					continue;
				}

				sobjectToUpdate.add(new Task(Id=inte.sobj.Id,Gestion_Nueva__c=inte.inte.Id,WhatId=inte.inte.Id));

			}

			// Actualizamos las tareas
			update sobjectToUpdate;


		}


	}


	/**
	* @author Maximo Martinez
	* @date 25/09/2018
	* @description Genera Gestiones y Registros Gestionados a partir de Objetos EmailMessage
	* @param emailMessagesList lista de SObjects EmailMessage a procesar
	*/
	public void createGestionesFromSObjects(List<EmailMessage> emailMessagesList, Map<Id,EmailMessage> oldMap){

		Map<Id,EmailMessage> emailMessagesByTaskIds = new Map<Id,EmailMessage>();

		Map<Id,Set<Id>> taskIdsByContactsIds = new Map<Id,Set<Id>>();

		List<GestionDeCuentasController.Interaccion> interaccionesToProcess = new List<GestionDeCuentasController.Interaccion>();

		for(EmailMessage e : emailMessagesList){

			if(String.isNotEmpty(e.RelatedToId) && Utils.getObjectTypeById(e.RelatedToId) == Schema.Account.getSObjectType()){
				
				// Creamos una interaccion
				GestionDeCuentasController.Interaccion inte = new GestionDeCuentasController.Interaccion();
				inte.cuenta = e.RelatedToId;
				inte.sobj = e;
				inte.modoDeContacto = (e.ToAddress.contains(UserInfo.getUserEmail())) ? CONTACT_MODE_EMAIL_ENTRANTE : CONTACT_MODE_EMAIL_SALIENTE;
				inte.fechaHora = e.MessageDate;
				inte.idCorreoElectronico = e.Id;
				inte.isUpdateable = true;

				interaccionesToProcess.add(inte);

			}else if(String.isNotEmpty(e.ActivityId) && ( oldMap == null || e.ActivityId != oldMap.get(e.Id).ActivityId ) ){
				emailMessagesByTaskIds.put(e.ActivityId,e);
			}
			
		}

		if(emailMessagesByTaskIds.isEmpty() && interaccionesToProcess.isEmpty()){
			return;
		}

		for(Task t : [SELECT Id, WhoId FROM Task WHERE Id IN :emailMessagesByTaskIds.keySet()]){

			if(Utils.getObjectTypeById(t.WhoId) != Schema.Contact.getSObjectType()){
				continue;
			}

			if(!taskIdsByContactsIds.containsKey(t.WhoId)){
				taskIdsByContactsIds.put(t.WhoId, new Set<Id>());
			}

			taskIdsByContactsIds.get(t.WhoId).add(t.Id);

		}

		for(Contact c : [SELECT Id, AccountId FROM Contact WHERE Id IN :taskIdsByContactsIds.keySet()]){

			if(!taskIdsByContactsIds.containsKey(c.Id)){
				continue;
			}

			for(Id taskId : taskIdsByContactsIds.get(c.Id)){

				if(!emailMessagesByTaskIds.containsKey(taskId)){
					continue;
				}

				// Creamos una interaccion
				GestionDeCuentasController.Interaccion inte = new GestionDeCuentasController.Interaccion();
				inte.cuenta = c.AccountId;
				inte.sobj = emailMessagesByTaskIds.get(taskId).clone();
				inte.modoDeContacto = (((EmailMessage)inte.sobj).ToAddress.contains(UserInfo.getUserEmail()))?CONTACT_MODE_EMAIL_ENTRANTE:CONTACT_MODE_EMAIL_SALIENTE;
				inte.fechaHora = (Datetime)inte.sobj.get('MessageDate');
				inte.idCorreoElectronico = emailMessagesByTaskIds.get(taskId).Id;
				inte.isUpdateable = true;

				interaccionesToProcess.add(inte);

			}

		}

		if(!interaccionesToProcess.isEmpty()){
			new GestionDeCuentasController.GestionEmailMessageHandler(interaccionesToProcess).createGestionesFromSObjects();
		}

	}

	/**
	* @author Maximo Martinez
	* @date 20/12/2019
	* @description Genera Gestiones y Registros Gestionados a partir de Objetos Task
	* @param taskList lista de SObjects Task a procesar
	*/
	public void createGestionesFromSObjects(List<Task> taskList, Map<Id,Task> oldMap){

		List<GestionDeCuentasController.Interaccion> interaccionesToProcess = new List<GestionDeCuentasController.Interaccion>();

		Map<Id,List<Task>> taskByContactId = new Map<Id,List<Task>>();

		// Set para coleccionar los subjects de las tareas
		Set<String> subjectTasks = new Set<String>();

		System.debug(LoggingLevel.WARN,taskList);

		// Recorremos las task y de momento nos quedamos solo con aquellas que tienen como asunto [Whatslly]
		for(Task t : taskList){

			if(Utils.getObjectTypeById(t.WhoId) != Schema.Contact.getSObjectType()){
				continue;
			}

			if(!(String.isNotEmpty(t.Subject) && t.Subject.contains(SOURCE_INTERACTION_WHATSLLY))){ // Si el asunto tiene incluida la palabra [Whatslly] la incluyo
				continue;
			}

			if(!taskByContactId.containsKey(t.WhoId)){
				taskByContactId.put(t.WhoId,new List<Task>());
			}

			subjectTasks.add(t.Subject);

			taskByContactId.get(t.WhoId).add(t);

		}

		if(taskByContactId.isEmpty()){
			return;
		}

		// Tenemos que obtener 
		Map<String,Set<Schema.RecordTypeInfo>> recordTypesBySubject = getDocumentosGestionadosRecordTypesByString(subjectTasks);

		for(Contact c : [SELECT Id, AccountId FROM Contact WHERE Id IN :taskByContactId.keySet()]){

			if(!taskByContactId.containsKey(c.Id)){
				continue;
			}

			for(Task t : taskByContactId.get(c.Id)){

				// Creamos una interaccion
				GestionDeCuentasController.Interaccion inte = new GestionDeCuentasController.Interaccion();
				inte.cuenta = c.AccountId;
				inte.sobj = t;
				inte.modoDeContacto = CONTACT_MODE_WHATSAPP;
				inte.fechaHora = t.CreatedDate;
				inte.isUpdateable = true;
				inte.documentosGestionadosRecordTypes = recordTypesBySubject.get(t.Subject);
				inte.isUpdateable = true;
				interaccionesToProcess.add(inte);

			}

		}

		if(!interaccionesToProcess.isEmpty()){
			new GestionDeCuentasController.GestionTaskHandler(interaccionesToProcess).createGestionesFromSObjects();
		}


	}


	/**
	* @author Maximo Martinez
	* @date 26/09/2018
	* @description A partir de un set de accounts devuelve un map con la campaña que iria para DUP y para cobranza
	* @param idsAccounts Set con los ids de las cuentas de las cuales necesitamos obtener sus transacciones y oportunidades
	* @return Map de ids de cuentas y por cada entrada un map con las claves dup y cobranza
	*/
	public static List<Campana_Agricola__c> getCampanaAgricola(){
        return [SELECT Id FROM Campana_Agricola__c WHERE Estado__c = 'Activa' AND (Cultivo__r.Name = 'SOJA' OR Cultivo__r.Name = 'TRIGO') ORDER BY Fecha_de_Inicio__c DESC NULLS LAST LIMIT 1];
    }  

	/**
	* @author Maximo Martinez
	* @date 20/12/2019
	* @description Devuelve los Developer Names de los Docs Gestionados que se piden en una string
	*/
	public static Map<String,Set<Schema.RecordTypeInfo>> getDocumentosGestionadosRecordTypesByString(Set<String> inputs){

		Map<String,Set<Schema.RecordTypeInfo>> results = new Map<String,Set<Schema.RecordTypeInfo>> ();

		// Ciclamos en busqueda de las palabras que podemos buscar y hacemos el mapping con el record type
		for(Mapeo_Documento_Gestionado__mdt mdg : [SELECT Id, Label, Tipo_Documento_Gestionado__c FROM Mapeo_Documento_Gestionado__mdt]){

			for(String input : inputs){

				if(!input.toLowerCase().contains(mdg.Label.toLowerCase())){
					continue;
				}

				if(!results.containsKey(input)){
					results.put(input,new Set<Schema.RecordTypeInfo>());
				}

				results.get(input).add(Documento_Gestionado__c.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get(mdg.Tipo_Documento_Gestionado__c));
			
			}
		}

		return results;

	}

	/**
	* @author Maximo Martinez
	* @date 26/12/2019
	* @description Metodo para el manejo de archivos que deben ser adjuntados a interacciones
	*/
	public void attachToInteracciones(List<Attachment> attachmentList, Map<Id,Attachment> oldMap){

		List<Attachment> attachmentsToInsert = new List<Attachment>();

		Map<Id,List<Attachment>> attachmentByParentId = new Map<Id,List<Attachment>>();

		for(Attachment att : attachmentList){

			if(Utils.getObjectTypeById(att.ParentId) != Task.SObjectType){
				continue;
			}

			if(!attachmentByParentId.containsKey(att.ParentId)){
				attachmentByParentId.put(att.ParentId,new List<Attachment>());
			}

			attachmentByParentId.get(att.ParentId).add(att);

		}

		// Reviso si las task que estan asociadas a los adjuntos tienen interacciones asociadas
		for(Task t : [SELECT Id, WhatId FROM Task WHERE Id IN :attachmentByParentId.keySet()]){

			if(!attachmentByParentId.containsKeY(t.Id)){
				continue;
			}

			if(Utils.getObjectTypeById(t.WhatId) != Interaccion_Nueva__c.SObjectType){
				continue;
			}

			for(Attachment att : attachmentByParentId.get(t.Id)){

				Attachment cloned = att.clone();
				cloned.ParentId = t.WhatId;
				attachmentsToInsert.add(cloned);

			}

		}

		insert attachmentsToInsert;

	}

	
	/**
	* @author Maximo Martinez
	* @date 20/12/2019
	* @description Clase Abstracta para el manejo de documentos gestionados
	*/
	public abstract class DocumentoGestionadoHandler {

		public Campana_Agricola__c campania {get; set;}
		public List<Interaccion_Nueva__c> interacciones = new List<Interaccion_Nueva__c>();
		public Schema.RecordTypeInfo recordType {get; set;}
		public Set<Id> accountIds = new Set<Id>();

		public abstract List<Documento_Gestionado__c> getDocumentosGestionados();

		public abstract void setDocumentoGestionadoFieldsByType(Documento_Gestionado__c doc, SObject sobj);

		public void setCampaniaAgricola(Campana_Agricola__c campania){
			this.campania = campania;
		}

		public void setRecordTypeInfo(Schema.RecordTypeInfo recordType){
			this.recordType = recordType;
		}

		public void addInteraccion(Interaccion_Nueva__c inte){
			interacciones.add(inte);
			accountIds.add(inte.Cuenta__c);
		}

		public List<Documento_Gestionado__c> createDocumentosGestionados(Sobject sobj){
			
			List<Documento_Gestionado__c> docsGestionados = new List<Documento_Gestionado__c>();

			for(Interaccion_Nueva__c inte : this.interacciones){

				// Revisamos si la interaccion fue creada, si no fue creada no damos de alta su Documento Gestionado
				if(String.isEmpty(inte.Id)){
					continue;
				}

				Documento_Gestionado__c dc = new Documento_Gestionado__c();
				dc.RecordTypeId = this.recordType.getRecordTypeId();
				dc.Campania_Gestion__c = this.campania.Id;
				dc.Gestion_Nueva__c = inte.Id;
				setDocumentoGestionadoFieldsByType(dc, sobj);
				docsGestionados.add(dc);
			
			}

			return docsGestionados;

		}

	}

	/**
	* @author Maximo Martinez
	* @date 20/12/2019
	* @description Clase Abstracta para el manejo de documentos gestionados
	*/
	public class DocumentoGestionadoFacturaHandler extends DocumentoGestionadoHandler{
		
		public override void setDocumentoGestionadoFieldsByType(Documento_Gestionado__c dc, SObject sobj){
			dc.Factura__c = sobj.Id;
		}

		public override List<Documento_Gestionado__c> getDocumentosGestionados(){
			
			List<Documento_Gestionado__c> result = new List<Documento_Gestionado__c>();

			for(Opportunity op : [SELECT Id FROM Opportunity WHERE AccountId IN :accountIds AND N_de_Comprobante__c != null AND Tipo_de_Comprobante__c != 'NC' AND Saldo_a_gestionar__c > 0]){
				result.addAll(createDocumentosGestionados(op));
			}

			return result;

		}

	}

	/**
	* @author Maximo Martinez
	* @date 20/12/2019
	* @description Clase Abstracta para el manejo de documentos gestionados a partir de Dups
	*/
	public class DocumentoGestionadoDUPHandler extends DocumentoGestionadoHandler{


		public override void setDocumentoGestionadoFieldsByType(Documento_Gestionado__c dc, SObject sobj){
			dc.Transaccion__c = sobj.Id;
		}

		public override List<Documento_Gestionado__c> getDocumentosGestionados(){

			List<Documento_Gestionado__c> result = new List<Documento_Gestionado__c>();
			
			for(Transaccion__c tr : [SELECT Id FROM Transaccion__c WHERE Nombre_de_la_cuenta__c IN :accountIds AND Subestado__c = 'Positiva' AND Estado__c = 'Creada' AND RecordType.DeveloperName = 'DUP']){
				result.addAll(createDocumentosGestionados(tr));
			}

			return result;

		}

	}

	/**
	* @author Maximo Martinez
	* @date 20/12/2019
	* @description Clase Abstracta para el manejo de documentos gestionados a partir de Dups
	*/
	public class DocumentoGestionadoAuditoriaHandler extends DocumentoGestionadoHandler{

		public override void setDocumentoGestionadoFieldsByType(Documento_Gestionado__c dc, SObject sobj){
			dc.Transaccion__c = sobj.Id;
		}

		public override List<Documento_Gestionado__c> getDocumentosGestionados(){

			List<Documento_Gestionado__c> result = new List<Documento_Gestionado__c>();

			for(Transaccion__c tr : [SELECT Id FROM Transaccion__c WHERE Nombre_de_la_cuenta__c IN :accountIds AND Gestionada__c = false AND Estado__c = 'Completa' AND RecordType.DeveloperName = 'Auditorias']){
				result.addAll(createDocumentosGestionados(tr));
			}

			return result;

		}

	}

	/**
	* @author Maximo Martinez
	* @date 20/12/2019
	* @description Clase Abstracta para el manejo de documentos gestionados a partir de Ventas
	*/
	public class DocumentoGestionadoVentasHandler extends DocumentoGestionadoHandler{

		public override void setDocumentoGestionadoFieldsByType(Documento_Gestionado__c dc, SObject sobj){}

		public override List<Documento_Gestionado__c> getDocumentosGestionados(){
			return createDocumentosGestionados(null);
		}

	} 


	/**
	* @author Maximo Martinez
	* @date 20/12/2019
	* @description Clase Auxiliar para hacer un wrapper entre los distintos tipos de interacciones
	*/
	public class Interaccion{
		public Interaccion_Nueva__c inte {get; set;}
		public String modoDeContacto {get; set;}
		public Id cuenta {get; set;}
		public Datetime fechaHora {get; set;}
		public SObject sobj {get; set;}
		public Id idCorreoElectronico {get; set;}
		public Boolean isUpdateable {get; set;}
		public Set<Schema.RecordTypeInfo> documentosGestionadosRecordTypes {get; set;}
	}

}