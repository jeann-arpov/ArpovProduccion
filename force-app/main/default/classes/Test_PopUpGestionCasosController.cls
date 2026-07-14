/**
* @author Maximo Martinez
* @date 2/6/2014
* @description Clase de Test de la Clase PopUpGestionCasosController
*/
@isTest
public class Test_PopUpGestionCasosController{
    /*
    * @description Método de Test
    */
    public static testmethod void test(){
        
        //Creamos los datos de test
        
         //Creamos una cuenta de tipo Obtentor
        Account obtentor = Test_TestUtils.crearObtentor();
        
        //Seteamos los parametros de la pagina
        
        //Seteamos el id del objeto a visualizar en el popup
        ApexPages.currentPage().getParameters().put('idObjeto',obtentor.Id);
        
        //Seteamos el FieldSet de donde obtendra los datos
        ApexPages.currentPage().getParameters().put('conjunto','Campos_PopUp_Cuenta');
        
        //Instanciamos el controller
        PopUpGestionCasosController ctrl = new PopUpGestionCasosController();
        
    }
    
}