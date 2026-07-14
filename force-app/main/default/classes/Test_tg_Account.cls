/**
* @author Maximo Martinez
* @date 6/6/2014
* @description Clase de Test del Trigger tg_Account
*/
@isTest
public with sharing class Test_tg_Account{
    
    /*
    * @description Método de Test
    */
    @isTest static void testGeneral(){
    
        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account productor = Test_TestUtils.crearProductor();
        
        Account distribuidor = Test_TestUtils.crearDistribuidor();
        
        System.AssertNotEquals([Select count() from Account where Name != null],5,'No se crearon las cuentas que debieron');
    }
    
    /*
    * @description Método de Test Encargado de Testear la Generacion del Contacto Remesa
    */
    public static testmethod void testContactoRemesa(){
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        //Verificamos si se creo un contacto remesa para esta cuenta
        Integer count = [SELECT COUNT() FROM Contact WHERE AccountId = :obtentor.Id AND Contacto_Remesa__c = true];
        
        //No deberia haberse creado el contacto
        //System.AssertEquals(count,0);
        
        //Ahora actualizamos el campo email
        obtentor.Direccion_de_Correo_electronico_del_CUIT__c = 'test@test.com';
        
        //Actualizamos en la DB
        update obtentor;
        
        //Verificamos si se creo un contacto remesa para esta cuenta
        count = [SELECT COUNT() FROM Contact WHERE AccountId = :obtentor.Id AND Contacto_Remesa__c = true];
        
        //Deberia haberse creado el contacto
        //System.AssertEquals(count,1);
        
        //Actualizamos el email
        obtentor.Direccion_de_Correo_electronico_del_CUIT__c = 'testtest@test.com';
        
        //Actualizamos en la DB
        update obtentor;
        
        //Verificamos que sigue existiendo un contacto remesa para esta cuenta
        count = [SELECT COUNT() FROM Contact WHERE AccountId = :obtentor.Id AND Contacto_Remesa__c = true];
        
        //Deberia haberse creado el contacto
        //System.AssertEquals(count,1);
    }

}