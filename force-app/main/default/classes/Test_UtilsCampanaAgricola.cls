/**
* @author Maximo Martinez
* @date 16/07/2014
* @description Clase de Test de la Clase UtilsCampanaAgricola
*/
@isTest
public class Test_UtilsCampanaAgricola{
    
     /**
    * @description Método de Test
    */
    public static testmethod void testSetearCampanaAnteriorACompleta(){
        
        //Creamos datos de test
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c ca1 = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        //Creamos otra campaña agricola
        Campana_Agricola__c ca2 = Test_TestUtils.crearCampanaAgricola('2013', cultivo, hoy, manana, '2014 - Test');
        
        //Seteamos la campaña agricola anterior de la ca1
        ca1.Nombre_de_Campana_Anterior__c = ca2.Id;
        
        //Seteamos el Estado de la ca1 a Activa
        ca1.Estado__c = 'Activa';
        
        //Actualizamos la BD
        update ca1;
        
        UtilsCampanaAgricola.setearCampanaAnteriorACompleta(new List<Campana_Agricola__c>{ca1});
                
    }
    
}