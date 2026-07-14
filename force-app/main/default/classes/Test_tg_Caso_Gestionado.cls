/**
* @author Maximo Martinez
* @date 04/06/2014
* @description Clase encargada de testear el Trigger tg_Caso_Gestionado
*/
@isTest
private class Test_tg_Caso_Gestionado {
	

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

	}
	
}