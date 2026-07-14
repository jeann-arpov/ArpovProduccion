/**
* @author Maximo Martinez
* @date 28/08/2014
* @description Clase con metodos auxiliares para la clase CasoGestionado
*/
public with sharing class UtilsCasoGestionado {

	/**
	* @author Maximo Martinez
	* @date 18/05/2016
	* @description Metodo que setea el resultado de la gestion en la cuenta
	*/
	public static void postGestionTT(List<Caso_Gestionado__c> lista) {

		Map<Id, List<CasoGestionadoWrapper>> casosGestionadosByAccount = new Map<Id, List<CasoGestionadoWrapper>>();

		// Set de interacciones
		Set<Id> idsInteracciones = new Set<Id>();

		// Recorremos la lista de casos gestionados, y ordenamos por cuenta
		for (Caso_Gestionado__c cg : [SELECT Id, Z9_Asunto__c, Cuenta__c, Interaccion__c, CreatedDate, Resultado_de_la_Actividad__c FROM Caso_Gestionado__c WHERE Id IN :lista]) {

			System.debug(LoggingLevel.WARN, cg.Z9_Asunto__c);

			idsInteracciones.add(cg.Interaccion__c);

			if (!casosGestionadosByAccount.containsKey(cg.Cuenta__c)) {
				casosGestionadosByAccount.put(cg.Cuenta__c, new List<CasoGestionadoWrapper>());
			}

			casosGestionadosByAccount.get(cg.Cuenta__c).add(new CasoGestionadoWrapper(cg));

		}

		Map<Id, Account> toUpdate = new Map<Id, Account>();

		// Recorremos las cuentas y si alguno de los valores cambio, la actualizamos
		for (Account a : [SELECT Id, Fecha_Ultima_Gestion_Cobranza__c, Fecha_Ultima_Gestion_Respuesta__c, Fecha_Ultima_Visita__c, Resultado_Ultima_Gestion_Flow__c, Ultima_Gestion_Efectiva__c, Ultima_Gestion_No_Efectiva__c  FROM Account WHERE Id IN :casosGestionadosByAccount.keySet()]) {

			// Verificamos si la cuenta tiene Casos Getionados en el map
			if (!casosGestionadosByAccount.containsKey(a.Id)) {
				continue;
			}

			// Obtenemos la lista
			List<CasoGestionadoWrapper> casos = casosGestionadosByAccount.get(a.Id);

			// Ordenamos la lista, que se va a ordenar por fechas
			casos.sort();

			// Verificamos los resultados
			for (CasoGestionadoWrapper cgw : casos) {

				Caso_Gestionado__c cg = cgw.cg;

				System.debug(LoggingLevel.DEBUG, cg.CreatedDate);

				Date cgDate = Date.newinstance(cg.CreatedDate.year(), cg.CreatedDate.month(), cg.CreatedDate.day());

				if (cg.Resultado_de_la_Actividad__c.toLowerCase() == 'efectiva' && (a.Ultima_Gestion_Efectiva__c < cgDate || a.Ultima_Gestion_Efectiva__c == null) ) {

					a.Ultima_Gestion_Efectiva__c = cgDate;
					toUpdate.put(a.Id, a);

				} else if (cg.Resultado_de_la_Actividad__c.toLowerCase() == 'no efectiva'  && ( a.Ultima_Gestion_No_Efectiva__c < cgDate || a.Ultima_Gestion_No_Efectiva__c == null) ) {

					a.Ultima_Gestion_No_Efectiva__c = cgDate;
					toUpdate.put(a.Id, a);

				}

			}

			// Si hay que actualiza
			if (toUpdate.containsKey(a.Id)) {

				// Dependiendo cual es de mayor fecha, seteo efectiva o no efectiva
				if ( ( a.Ultima_Gestion_Efectiva__c >= a.Ultima_Gestion_No_Efectiva__c ) || ( a.Ultima_Gestion_Efectiva__c != null && a.Ultima_Gestion_No_Efectiva__c == null) ) {
					a.Resultado_Ultima_Gestion_Flow__c = 'efectiva'.toUpperCase();
				} else{
					a.Resultado_Ultima_Gestion_Flow__c = 'no efectiva'.toUpperCase();
				}


			}

		}

		if (!toUpdate.isEmpty()) {
			Utils.updateList(toUpdate.values());
		}

		if(!idsInteracciones.isEmpty()){
			calculateAccountFieldsFromGestion(idsInteracciones);
		}
	}

	@future
	private static void calculateAccountFieldsFromGestion(Set<Id> idsInteracciones){

		Date today = Date.today();

		Map<Id, Account> toUpdate = new Map<Id, Account>();

		// Map de ultima interaccion por cuenta
		Map<Id, List<Interaccion__c>> interaccionesByAccountId = new Map<Id, List<Interaccion__c>>();

		for(Interaccion__c interaccion : [SELECT Id, Temas_de_AUD__c, Temas_de_Cobranza__c, Temas_de_DUP__c, Caso__r.AccountId, Gestion_de_Cobranza__c, Gestion_de_Respuestas__c, Gestion_de_Auditoria__c FROM Interaccion__c WHERE Id IN :idsInteracciones ORDER BY CreatedDate DESC]){
			
			if(!interaccionesByAccountId.containsKey(interaccion.Caso__r.AccountId)){
				interaccionesByAccountId.put(interaccion.Caso__r.AccountId,new List<Interaccion__c>());
			}

			interaccionesByAccountId.get(interaccion.Caso__r.AccountId).add(interaccion);

		}

		System.debug(LoggingLevel.WARN, interaccionesByAccountId);

		for(Account a : [SELECT Id, Fecha_Ultima_Gestion_Cobranza__c, Fecha_Ultima_Gestion_Respuesta__c, Fecha_Ultima_Visita__c, Resultado_Ultima_Gestion_Flow__c, Ultima_Gestion_Efectiva__c, Ultima_Gestion_No_Efectiva__c  FROM Account WHERE Id IN :interaccionesByAccountId.keySet()]){

			// Verificamos si la cuenta tiene interaccion
			if(interaccionesByAccountId.containsKey(a.Id)){

				// Seteamos los campos de la cuenta segun las ultimas interacciones
				for(Interaccion__c interaccion : interaccionesByAccountId.get(a.Id)){

					if(interaccion.Gestion_de_Cobranza__c){
						a.Fecha_Ultima_Gestion_Cobranza__c = today;
						toUpdate.put(a.Id, a);
					}

					if(interaccion.Gestion_de_Respuestas__c){
						a.Fecha_Ultima_Gestion_Respuesta__c = today;
						toUpdate.put(a.Id, a);
					}

					if(interaccion.Gestion_de_Auditoria__c){
						a.Fecha_Ultima_Visita__c = today;
						toUpdate.put(a.Id, a);
					}

				}

			}

		}

		if (!toUpdate.isEmpty()) {
			Utils.updateList(toUpdate.values());
		}

	}

	/**
	* @author Maximo Martinez
	* @date 18/05/2016
	* @description Clase Auxiliar para comparar Casos Gestionados por fecha de creacion
	*/
	public class CasoGestionadoWrapper implements Comparable {

		public Caso_Gestionado__c cg {get; set;}

		// Constructor
		public CasoGestionadoWrapper(Caso_Gestionado__c cg) {
			this.cg = cg;
		}

		// Compara casos gestionados a partir de su fecha de creacion
		public Integer compareTo(Object compareTo) {

			// Casteamos el objeto a comparar a CasoGestionadoWrapper
			CasoGestionadoWrapper compareToCG = (CasoGestionadoWrapper)compareTo;

			// El 0 indica que ambos elementos son iguales
			Integer returnValue = 0;

			if (cg.CreatedDate > compareToCG.cg.CreatedDate) {
				returnValue = 1;
			} else if (cg.CreatedDate < compareToCG.cg.CreatedDate) {
				returnValue = -1;
			}

			return returnValue;
		}
	}

}