/**
* @author Maximo Martinez
* @date 28/08/2014
* @description Clase que testea los metodos de la clase UtilsCasoGestionado
*/
@isTest
private class Test_UtilsCasoGestionado {
	

	/**
	* @author Maximo Martinez
	* @date 28/08/2014
	* @description Metodo que testea el metodo ValidarFechas de la clase UtilsCasoGestionado
	*/
	@isTest static void testPostGestionTT() {

		//Creamos los datos de prueba

		//Creamos una cuenta
		Account obtentor = Test_TestUtils.crearObtentor();

		//Creamos un caso Padre
        Case casoPadre = Test_TestUtils.crearCasoGestionCUIT(obtentor);

        //Creamos una interaccion
        Interaccion__c interaccion = Test_TestUtils.crearInteraccion(casoPadre);

	    //Creamos un caso de tipo DUP
	    Case casoDUP = Test_TestUtils.crearCasoDUP(obtentor,casoPadre);

	    //Creamos un caso de tipo Cobranza
	    Case casoCobranza = Test_TestUtils.crearCasoCobranza(obtentor,casoPadre);

	    //Insertamos los caso en la BD
	    insert new List<Case>{casoDUP, casoCobranza};

	    //Creamos un comentario Gestionado para el Caso DUP
	    Caso_Gestionado__c casoGestionadoDUP = Test_TestUtils.crearCasoGestionado(casoDUP, '6 - Promesa de Respuesta', interaccion, obtentor);

	    //Creamos un comentario Gestionado para el Caso Cobranza
	    Caso_Gestionado__c casoGestionadoCobranza = Test_TestUtils.crearCasoGestionado(casoCobranza, '9 - Solicita Plazo de pago', interaccion, obtentor);

	    //Insertamos en la BD
	    Utils.insertList(new List<Caso_Gestionado__c>{casoGestionadoDUP, casoGestionadoCobranza},true);

	    System.debug(LoggingLevel.WARN, [SELECT Id, Temas_de_AUD__c, Temas_de_Cobranza__c, Temas_de_DUP__c, Caso__r.AccountId, Gestion_de_Cobranza__c, Gestion_de_Respuestas__c, Gestion_de_Auditoria__c FROM Interaccion__c WHERE Id = :interaccion.Id]);
 
	}
	
}