/**
* @author Maximo Martinez
* @date 10/07/2014
* @description Clase de Test del Trigger tg_Interaccion
*/
@isTest
public class Test_tg_Interaccion{
    
    /*
    * @description Método de Test
    */
    public static testmethod void testSetearPrioridadCuenta(){
        
        //Creamos una cuenta solo con el fin de asociarla al caso padre
        Account cuenta = Test_TestUtils.crearObtentor();
       
        //Creamos un caso Gestion de Cuit
        Case caso = Test_TestUtils.crearCasoGestionCUIT(cuenta);
        
        //Creamos un caso Gestionado
        Interaccion__c interaccion = Test_TestUtils.crearInteraccion(caso);
        
        //Testeamos el metodo de Seteo de Prioridades
        UtilsAccount.setearPrioridades(new List<Interaccion__c>{interaccion});
        
    }


}