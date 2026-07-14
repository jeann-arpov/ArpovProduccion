@isTest
private class Test_UtilsAccount {
	
	/*
    * @description Método de Test
    */
    @isTest
    public static void testSetearPrioridadCuenta(){
        
        //Creamos una cuenta solo con el fin de asociarla al caso padre
        Account cuenta = Test_TestUtils.crearObtentor();
       
        //Creamos un caso Gestion de Cuit
        Case caso = Test_TestUtils.crearCasoGestionCUIT(cuenta);
        
        //Creamos un caso Gestionado
        Interaccion__c interaccion = Test_TestUtils.crearInteraccion(caso);
        
        //Testeamos el metodo de Seteo de Prioridades
        UtilsAccount.setearPrioridades(new List<Interaccion__c>{interaccion});

        new UtilsAccount.WrapperAccountEmail(null, null);
        UtilsAccount.insertPartialList(new List<Account>());
    }

    @isTest
    public static void test(){
        Sembra_Evolucion__c cs = new Sembra_Evolucion__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Corteva_30_Cuit__c = '30647854748'
        );
        insert cs;

        UtilsAccount.getCuitCorteva();

        UtilsAccount.getExclusionDay(Date.today());
    }

    /*
    * @description Método de Test Encargado de Testear la Generacion del Contacto Remesa
    */
    /*
    public static testmethod void testContactoRemesa(){
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        //Verificamos si se creo un contacto remesa para esta cuenta
        Integer count = [SELECT COUNT() FROM Contact WHERE AccountId = :obtentor.Id AND Contacto_Remesa__c = true];
        
        //No deberia haberse creado el contacto
        System.AssertEquals(count,0);
        
        //Ahora actualizamos el campo email
        obtentor.Direccion_de_Correo_electronico_del_CUIT__c = 'test@test.com';
        
        //Actualizamos en la DB
        update obtentor;
        
        //Verificamos si se creo un contacto remesa para esta cuenta
        count = [SELECT COUNT() FROM Contact WHERE AccountId = :obtentor.Id AND Contacto_Remesa__c = true];
        
        //Deberia haberse creado el contacto
        System.AssertEquals(count,1);

        //Ahora actualizamos el campo email
        obtentor.Direccion_de_Correo_electronico_del_CUIT__c = 'test@test.com';
        
        //Actualizamos en la DB
        update obtentor;

        //Verificamos si se creo un contacto remesa para esta cuenta
        count = [SELECT COUNT() FROM Contact WHERE AccountId = :obtentor.Id AND Contacto_Remesa__c = true];
        
        //Deberia haberse creado el contacto
        System.AssertEquals(count,1);
        
        //Actualizamos el email
        obtentor.Direccion_de_Correo_electronico_del_CUIT__c = 'testtest@test.com';
        
        //Actualizamos en la DB
        update obtentor;
        
        //Verificamos que sigue existiendo un contacto remesa para esta cuenta
        count = [SELECT COUNT() FROM Contact WHERE AccountId = :obtentor.Id AND Contacto_Remesa__c = true];
        
        //Deberia haberse creado el contacto
        System.AssertEquals(count,1);
    }
	*/
}