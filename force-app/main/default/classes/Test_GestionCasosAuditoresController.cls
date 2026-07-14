/**
* @author Maximo Martinez
* @date 01/08/2017
* @description Clase de Test de la Clase GestionCasosAuditoresController
*/
@isTest
public class Test_GestionCasosAuditoresController {

	@TestSetup 
    static void setup(){
        List <ERPvs__Datos_Generales__c> dg_insertar = new List<ERPvs__Datos_Generales__c> ();
        
        for (RecordType rtID :[select id, name from RecordType where SobjectType = 'ERPvs__Datos_Generales__c' order by name]) {
            if (rtID.Name == 'General') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'Común a todas las aplicaciones', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Compras') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Compras', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Contabilidad') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Contabilidad', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Ventas') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Facturación', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Fondos') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Fondos', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Stock') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Inventarios', RecordTypeId = rtID.id));
            }
        }
        insert dg_insertar;

        //Una moneda sera de la compania
        List<Moneda__c> monedas = new List<Moneda__c>();

        monedas.add(Test_TestUtils.crearMoneda('TEST1','TEST1',true, false));
        monedas.add(Test_TestUtils.crearMoneda('TEST2','TEST2',false, false));

        List <ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

        ERPvs__Moneda__c mon = new ERPvs__Moneda__c();
        mon.Name = '1';
        mon.ERPvs__Denominacion__c = 'moneda';
        mon.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        mon.ERPvs__Moneda_Nacional__c = false;
        mon.ERPvs__Moneda_Traducida__c = true;
        insert mon;

        monedas[0].Moneda_ERP__c = mon.Id;
        monedas[1].Moneda_ERP__c = mon.Id;

        insert monedas;

    }   
	
	/*
    * @description Método de Test
    */
    public static testmethod void test(){
        Test_TestUtils.disableFlows();

        Account obtentor = Test_TestUtils.crearObtentor();
        
        Account productor = Test_TestUtils.crearProductor();

    	Id rtObtentor = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor'); 
       
        //Creamos un caso Padre
        Case casoPadre = Test_TestUtils.crearCasoGestionCUIT(productor);  
        
        //Obtenemos los recordtype de dos de los tres tipos de casos
        Id casoDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP'); 
        Id casoCobranza = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas'); 
        
        
        //Creamos un caso hijo de tipo DUP
        Case casoHijoDUP = new Case();
        casoHijoDUP.ParentId = casoPadre.Id;
        casoHijoDUP.RecordTypeId = casoDUP;
        
        //Guardamos en la DB
        insert casoHijoDUP; 

        Event e = new Event();
        e.WhatId = productor.Id;
        e.DurationInMinutes = 10;
        e.ActivityDateTime = System.now();
        insert e;
       
        // Creamos una Auditoria
        //Obtenemos la lista de precios standard del sitio
        Id idPricebook2 = Utils.getPricebook2Id();

        Pricebook2 listaPrecios = new Pricebook2(Id = idPricebook2);

        //RecordType que usamos en el Test
        Id rtAuditorias = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');
        
        //Variable que contendra la moneda de la compania
        Moneda__c moneda1 = null;
        Moneda__c moneda2 = null;
        
        for(Moneda__c moneda : [SELECT Codigo_Univoco__c,Moneda_de_la_compania__c FROM Moneda__c]){
            if(moneda.Moneda_de_la_compania__c == true){
                moneda1 = moneda;
            }else{
                moneda2 = moneda;
            }
        }
        
        //Obtenemos la fechaActual
        Date fechaActual = Date.today();
    
        //Creamos un tipo de cambio para la moneda extranjera
        Tipo_de_Cambio__c tipoCambio = Test_TestUtils.crearTipodeCambio(moneda2,2,fechaActual);
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        //Creamos un par de productos
        List<Product2> productos = new List<Product2>();
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor);
        
        Product2 producto2= Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor);
        
        productos.add(producto1);
        
        productos.add(producto2);

        //Creamos una transaccion de tipo Auditoria 
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtAuditorias),'00000001', obtentor, cultivo, null, productor, 'Creada', hoy, true);
        
        Test.startTest();

        //Instanciamos un controladore standard  
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(e);
        
        //Itanciamos el controlador custom
        GestionCasosAuditoresController ctrl = new GestionCasosAuditoresController(stdCtrl);
        
        //Creamos una interaccion
        Interaccion__c i = GestionCasosAuditoresController.crearInteraccion(casoPadre.Id, 'Email').interaccion;
        
        //Obtenemos la lista de nodos hijos del padre
        List<GestionCasosController.Nodo> listaNodos = GestionCasosAuditoresController.getNodos('#', null, casoPadre.Id, i, new List<Task>());
        
        //Deberian ser exactamente un nodo que es el nodo padre
        System.Debug(LoggingLevel.INFO,listaNodos);
        
        System.AssertEquals(listaNodos.size(),1);
        
        //Obtenemos los nodos hijos de este nodo
        if(listaNodos.size() > 0){
            
            GestionCasosController.Nodo nodo = listaNodos.get(0);
            
            //Verificamos si el nodo es el nodo padre
            //System.AssertEquals(nodo.Id,casoPadre.Id);
            
            listaNodos = GestionCasosAuditoresController.getNodos(nodo.Id, nodo.parent, casoPadre.Id, i, new List<Task>());
            
            //Deberian ser exactamente dos nodos uno por cada tipo de caso que hemos agregado (agregamos dos tipos de casos)
            System.Debug(LoggingLevel.INFO,listaNodos);

            System.AssertEquals(listaNodos.size(),2);
            
            //Obtendremos los hijos de uno de los dos nodos que obtuvimos
            if(listaNodos.size() > 0){
                
                GestionCasosController.Nodo nodo0 = listaNodos.get(0);

                GestionCasosController.Nodo nodo1 = listaNodos.get(1);
                
                listaNodos = GestionCasosAuditoresController.getNodos(nodo0.Id, nodo0.parent, casoPadre.Id, i, new List<Task>());

                listaNodos = GestionCasosAuditoresController.getNodos(nodo1.Id, nodo1.parent, casoPadre.Id, i, new List<Task>());
                
                //Deberian ser exactamente un nodo, puesto que creamos uno de cada tipo
                System.Debug(LoggingLevel.INFO,listaNodos);
            
                //System.AssertEquals(listaNodos.size(),1);
                
                //Creamos una lista de ids de casos
                List<String> idsCasos = new List<String>{casoHijoDUP.Id,t.Id};
                
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
                GestionCasosAuditoresController.procesarCasos(dp);
                
                //Verificamos si se crearon dos casos gestionados (uno por cada caso que pasamos en la lista de Ids de Casos)
                List<Caso_Gestionado__c> cg = [SELECT Id FROM Caso_Gestionado__c];
                
                //System.AssertEquals(cg.size(),2);
                
                //Verificamos si se crearon dos task (una por cada caso que pasamos en la lista de Ids de Casos)
                List<Task> tasks = [SELECT Id,WhatId FROM Task WHERE WhatId IN : idsCasos];
                
                System.Debug(LoggingLevel.INFO,tasks);
                
                System.Debug(LoggingLevel.INFO,idsCasos);
                
                //System.AssertEquals(tasks.size(),2);
                
                //Verifamos la Gestion de Emails
                GestionCasosAuditoresController.enviarEmail(dp);
                
                //Ejecutamos el metodo cancel
                ctrl.cancel();
                
                //Ejecutamos el metodo agregar recordatorio
                ctrl.addRecordatorio();
                
                //Creamos una GestionCaso__c
                GestionCaso__c gc = Test_TestUtils.crearGestionCaso('DUP_Campana','Campana__r.Name', 'Campaña', true, true, 'Gestion_Caso_Campana_Agricola', 1, 'DUP');
                
                //Insertamos en la BD
                insert gc;

                 //Ejecutamos el metodo getCaseDataByRecordType
                GestionCasosAuditoresController.getTransaccionDataByRecordType(new List<GestionCaso__c>{gc},t);

                dp = new GestionCasosController.DatosProcesar();
                
                //Seteamos los datos que pasamos al metodo
                dp.idsCasos = new List<String>();
                dp.tareas  = new List<Task>();
                dp.comentariosCodificados = comentariosCodificados;
                dp.parentCase = casoPadre.Id;
                dp.interaccion = i;
                dp.fechaRespuesta  = Date.today();
                dp.fechaPago = Date.today();
                dp.taskType = 'Visita';
                
                //Creamos una Task y un Caso Gestionado
                GestionCasosAuditoresController.procesarCasos(dp);
                GestionCasosAuditoresController.enviarEmail(dp);

            }
            
        }

        GestionCasosAuditoresController.getComentariosGestionCasosAuditores();  

        //Ejecutamos el metodo getCaseDataByRecordType
        GestionCasosAuditoresController.getListaGestionCasoAuditores(rtAuditorias);

        Test.stopTest();

    }


}