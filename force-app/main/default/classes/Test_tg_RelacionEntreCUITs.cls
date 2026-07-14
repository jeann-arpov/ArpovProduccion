@isTest
public with sharing class Test_tg_RelacionEntreCUITs{

    @isTest static void testRelacion(){
        
        Account acc1 = Test_TestUtils.crearObtentor();
        
        Account acc2 = Test_TestUtils.crearDistribuidor();
        
        Relacion_entre_CUITS__c relacion = new Relacion_entre_CUITS__c(
            CUIT__c = acc1.id,
            CUIT_Anterior__c = acc2.id,
            Rol__c = 'Desglose (Nuevo)'
        );
        
        insert relacion;
        
        System.assertEquals([Select count() from Relacion_entre_CUITS__c where Name != null],2,'No se creó la relación inversa correctamente');
    }
    
    @isTest static void testRoles(){

        Account acc1 = Test_TestUtils.crearObtentor();
        
        Account acc2 = Test_TestUtils.crearDistribuidor();
        
        List<Relacion_entre_CUITS__c> relaciones = new List<Relacion_entre_CUITS__c>();
        Relacion_entre_CUITS__c relacion1 = new Relacion_entre_CUITS__c(
            CUIT__c = acc1.id,
            CUIT_Anterior__c = acc2.id,
            Rol__c = 'Cambio de CUIT (Nuevo)'
        );
        relaciones.add(relacion1);
        
        Relacion_entre_CUITS__c relacion2 = new Relacion_entre_CUITS__c(
            CUIT__c = acc1.id,
            CUIT_Anterior__c = acc2.id,
            Rol__c = 'Cambio de CUIT (Original)'
        );
        relaciones.add(relacion2);
        
        Relacion_entre_CUITS__c relacion3 = new Relacion_entre_CUITS__c(
            CUIT__c = acc1.id,
            CUIT_Anterior__c = acc2.id,
            Rol__c = 'Desglose (Nuevo)'
        );
        relaciones.add(relacion3);
        
        Relacion_entre_CUITS__c relacion4 = new Relacion_entre_CUITS__c(
            CUIT__c = acc1.id,
            CUIT_Anterior__c = acc2.id,
            Rol__c = 'Desglose (Originario)'
        );
        relaciones.add(relacion4);
        
        Relacion_entre_CUITS__c relacion5 = new Relacion_entre_CUITS__c(
            CUIT__c = acc1.id,
            CUIT_Anterior__c = acc2.id,
            Rol__c = 'Fusión (Nuevo)'
        );
        relaciones.add(relacion5);
        
        Relacion_entre_CUITS__c relacion6 = new Relacion_entre_CUITS__c(
            CUIT__c = acc1.id,
            CUIT_Anterior__c = acc2.id,
            Rol__c = 'Fusión (Originario)'
        );
        relaciones.add(relacion6);

        insert relaciones;
        
        System.assertEquals([Select count() from Relacion_entre_CUITS__c where Name != null],12,'No se creó la relación inversa correctamente');
    }

}