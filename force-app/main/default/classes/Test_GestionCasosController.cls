/**
* @author Maximo Martinez
* @date 2/6/2014
* @description Clase de Test de la Clase GestionCasosController
*/
@isTest
public class Test_GestionCasosController{
    
    /*
    * @description Método de Test
    */
    public static testmethod void test(){
        
        Id rtObtentor = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor'); 
        
        //Creamos una cuenta solo con el fin de asociarla al caso padre
        Account cuenta = Test_TestUtils.crearObtentor();
       
        //Creamos un caso Padre
        Case casoPadre = Test_TestUtils.crearCasoGestionCUIT(cuenta);  
        
        //Obtenemos los recordtype de dos de los tres tipos de casos
        Id casoDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP'); 
        Id casoCobranza = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas'); 
        
        
        //Creamos un caso hijo de tipo DUP
        Case casoHijoDUP = new Case();
        casoHijoDUP.ParentId = casoPadre.Id;
        casoHijoDUP.RecordTypeId = casoDUP;
        
        //Guardamos en la DB
        insert casoHijoDUP; 
        
        
        //Creamos un caso hijo de tipo Cobranza
        Case casoHijoCobranza = new Case();
        casoHijoCobranza.ParentId = casoPadre.Id;
        casoHijoCobranza.RecordTypeId = casoCobranza;
        
        //Guardamos en la DB
        insert casoHijoCobranza; 
        
        //Instanciamos un controladore standard  
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(casoPadre);
        
        //Itanciamos el controlador custom
        GestionCasosController ctrl = new GestionCasosController(stdCtrl);
        
        //Obtenemos info de la venta
        GestionCasosController.getDatosVenta(casoHijoCobranza.Id);
        
        //Creamos una interaccion
        Interaccion__c i = GestionCasosController.crearInteraccion(casoPadre.Id, 'Email').interaccion;
        
        //Obtenemos la lista de nodos hijos del padre
        List<GestionCasosController.Nodo> listaNodos = GestionCasosController.getNodos('#', null, casoPadre.Id, i, new List<Task>());
        
        //Deberian ser exactamente un nodo que es el nodo padre
        System.Debug(LoggingLevel.INFO,listaNodos);
        
        //System.AssertEquals(listaNodos.size(),1);
        ctrl.interaccion = new Interaccion__c();
        
        //Obtenemos los nodos hijos de este nodo
        if(listaNodos.size() > 0){
            
            GestionCasosController.Nodo nodo = listaNodos.get(0);
            
            //Verificamos si el nodo es el nodo padre
            //System.AssertEquals(nodo.Id,casoPadre.Id);
            
            listaNodos = GestionCasosController.getNodos(nodo.Id, nodo.parent, casoPadre.Id, i, new List<Task>());
            
            //Deberian ser exactamente dos nodos uno por cada tipo de caso que hemos agregado (agregamos dos tipos de casos)
            System.Debug(LoggingLevel.INFO,listaNodos);
            
            //System.AssertEquals(listaNodos.size(),2);
            
            //Obtendremos los hijos de uno de los dos nodos que obtuvimos
            if(listaNodos.size() > 0){
                
                nodo = listaNodos.get(0);
                
                listaNodos = GestionCasosController.getNodos(nodo.Id, nodo.parent, casoPadre.Id, i, new List<Task>());
                
                //Deberian ser exactamente un nodo, puesto que creamos uno de cada tipo
                System.Debug(LoggingLevel.INFO,listaNodos);
            
                //System.AssertEquals(listaNodos.size(),1);
                
                //Creamos una lista de ids de casos
                List<String> idsCasos = new List<String>{casoHijoDUP.Id,casoHijoCobranza.Id};
                
                //Creamos una lista de comentarios codificados
                List<String> comentariosCodificados = new List<String>{'1 - Hable con Responsable','CC 2'};
                
                //Creamos un objeto DatoProcesar
                
                GestionCasosController.DatosProcesar dp = new GestionCasosController.DatosProcesar();
                
                //Seteamos los datos que pasamos al metodo
                dp.idsCasos = idsCasos;
                dp.tareas  = new List<Task>();
                dp.comentariosCodificados = comentariosCodificados;
                dp.parentCase = casoPadre.Id;
                dp.interaccion = i;
                dp.fechaRespuesta  = Date.today();
                dp.fechaPago = Date.today();
                dp.taskType = 'Visita';
                
                //Creamos una Task y un Caso Gestionado
                GestionCasosController.procesarCasos(dp);
                
                //Verificamos si se crearon dos casos gestionados (uno por cada caso que pasamos en la lista de Ids de Casos)
                List<Caso_Gestionado__c> cg = [SELECT Id FROM Caso_Gestionado__c];
                
                //System.AssertEquals(cg.size(),2);
                
                //Verificamos si se crearon dos task (una por cada caso que pasamos en la lista de Ids de Casos)
                List<Task> tasks = [SELECT Id,WhatId FROM Task WHERE WhatId IN : idsCasos];
                
                System.Debug(LoggingLevel.INFO,tasks);
                
                System.Debug(LoggingLevel.INFO,idsCasos);
                
                //System.AssertEquals(tasks.size(),2);
                
                //Verifamos la Gestion de Emails
                GestionCasosController.enviarEmail(dp);
                
                //Ejecutamos el metodo cancel
                ctrl.cancel();
                
                //Ejecutamos el metodo agregar recordatorio
                ctrl.addRecordatorio();
                
                //Creamos una GestionCaso__c
                GestionCaso__c gc = Test_TestUtils.crearGestionCaso('DUP_Campana','Campana__r.Name', 'Campaña', true, true, 'Gestion_Caso_Campana_Agricola', 1, 'DUP');
                
                //Insertamos en la BD
                insert gc;

                //Ejecutamos el metodo getCaseDataByRecordType
                GestionCasosController.getCaseDataByRecordType(new List<GestionCaso__c>{gc},casoHijoDUP);

            }
            
        }

        GestionCasosController.getComentariosEmail();

        GestionCasosController.getComentariosTelefono();    
        
    }
    
    
}