public without sharing class GestionCasosAuditoresController{
	//Atributo que contendra el caso
    public Case caso {get; set;}
    public ID eventId {get;set;}
    
    //Atributo que contendra la tarea que usamos como plantilla
    public Task tarea {get; set;}

    //Atributo que contendra los comentarios
    public List<String> comentarios {get; set;}

    public String keyPrefixAuditoria {get; set;}

    public Id idRecordTypeAuditoria {get; set;}

    public Interaccion__c interaccion {get; set;}

    public GestionCasosAuditoresController(ApexPages.StandardController controller) {
        // Obtengo el evento que invocó a la pantalla.
        eventId = controller.getId();
        Event evento = [Select WhatId from Event where id = :eventId];
        // Me quedo con el id de la cuenta.
        ID AccountId = evento.WhatId;
        // Ahora voy a buscar un caso abierto que el tipo de registro sea Gestion de CUIT
        Id rtGestionCUITId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');
        
        caso = [Select Subject, AccountId From Case where Subject = 'Gestion de CUIT' AND AccountId = :AccountId and RecordTypeId = :rtGestionCUITId LIMIT 1];
        
        tarea = new Task();
        comentarios = GestionCasosController.populateSelect();

        keyPrefixAuditoria = Transaccion__c.sobjecttype.getDescribe().getKeyPrefix();

        idRecordTypeAuditoria = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');

    }

    /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo que retorna los comentarios validos para la Gestion Telefonica
    */
    public static List<String> getComentariosGestionCasosAuditores() {

        //Lista que contendra los comentarios validos para la Gestión Telefonica
        List<String> comentarios = new List<String>();

        //Consulto por los comentarios en la DB
        for (Comentarios_Codificados__c comentario : [SELECT Id, Comentarios_Codificados__c FROM Comentarios_Codificados__c WHERE GestionCasoTelefonico__c = true OR GestionCasosAuditores__c = true ORDER BY Orden__c]) {

            comentarios.add(comentario.Comentarios_Codificados__c);

        }


        return comentarios;

    }

    //Metodo para crear una interaccion al momento de crear la pagina
    @RemoteAction
    public static GestionCasosController.Resultado crearInteraccion(Id parentId, String modoContacto) {
        return GestionCasosController.crearInteraccion(parentId,modoContacto);
    }


    //Accion Remota que ira llenado el arbol a demanda
    @RemoteAction
    public static List<GestionCasosController.Nodo> getNodos(String idNodo, String parentId, String nodoPrincipal, Interaccion__c interaccion, List<Task> tareas) {

        //Obtenemos el RecordType de un Caso DUP
        Id rtDUPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');

        //Obtenemos el RecordType de una Cobranza
        Id rtCobId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');

        // Obtenemos el RecordType de Auditoria
        Id rtAuditorias = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');

        Case casoPadre = [Select Id, AccountId, Subject From Case where Id = : nodoPrincipal];

        Set<Id> idsTransacciones = getTransaccionesByInteraccion(interaccion);

        //Lista que contendra los nodos a devolver
        List<GestionCasosController.Nodo> nodos = new List<GestionCasosController.Nodo>();

        //Consultamos si es el primer nodo
        if (idNodo == '#' && parentId == null) {

            //Generamos el map del WhereList
            Map<String, String> whereList = new Map<String, String>();

            whereList.put('Nombre_de_la_cuenta__c', casoPadre.AccountId);

            //Obtenemos los datos del caso principal
            List<Transaccion__c> transacciones = getDinamicQUery(whereList, 1, idsTransacciones);

            whereList.clear();

            whereList.put('Id',nodoPrincipal);

            //Obtenemos los datos del caso principal
            List<Case> casos = GestionCasosController.getDinamicQUery(whereList, 1);

            if (casos.size() > 0) {

                //Obtenemos el caso
                Case c = casos.get(0);

                //Creamos un nodo
                GestionCasosController.Nodo n = new GestionCasosController.Nodo();
                n.id = c.id;
                n.parent = idNodo;
                n.text = c.Subject;
                n.setChildren(GestionCasosController.hasChildrens(c.Id));
                n.state = new GestionCasosController.State();
                n.state.opened = true;

                //Obtenemos el nombre de la cuenta
                List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id = :c.AccountId LIMIT 1];

                if (accounts.size() > 0) {

                    //Lista que contendra los datos
                    List<GestionCasosController.Data> datos = new List<GestionCasosController.Data>();

                    //Obtenemos la cuenta
                    Account cuenta = accounts.get(0);

                    //Seteamos los datos de la cuenta al nodo
                    GestionCasosController.Data dato = new GestionCasosController.Data();

                    dato.label = '';
                    dato.valor = cuenta.Name;
                    dato.isLink = true;
                    dato.id = cuenta.Id;

                    //Agregamos el dato a la lista de datos
                    datos.add(dato);

                    //Seteamos los datos al nodo
                    n.datos = datos;
                }

                //Agregamos el nodo a la lista de nodos
                nodos.add(n);
            }

        }else {

            //Verificamos si es un id valido de salesforce (sino sabemos que se esta abriendo un tipo)

            System.debug(LoggingLevel.WARN,idNodo);

            if (GestionCasosController.validateId(idNodo) == null) {

                //Hacemos un split del id
                List<String> ids = idNodo.split('_');

                //Separamos los ids

                //Id del RecordType
                String rtId = (ids.get(0) == 'null') ? null : ids.get(0);

                //Id del Nodo
                String nodoId = ids.get(1);

                //Set para contener los ids de los casos consultados
                Set<Id> idsCasos = new Set<Id>();


                // Si es Auditoria
                if(rtId == rtAuditorias){

                    //Generamos el map del WhereList
                    Map<String, String> whereList = new Map<String, String>();

                    whereList.put('Nombre_de_la_cuenta__c', casoPadre.AccountId);

                    //Ciclamos sobre los casosy obtenemos sus recordtypeids

                    //Map para coleccionar sus recordtype y por cada RT los campos de su custom settings
                    Map<Id, List<GestionCaso__c>> camposByRT = new Map<Id, List<GestionCaso__c>>();

                    for (Transaccion__c transaccion : getDinamicQUery(whereList, null,idsTransacciones)) {

                        if (!camposByRT.containsKey(transaccion.RecordTypeId)) {

                            //Llamamos a la puncion que nos da la lista de campos
                            camposByRT.put(transaccion.RecordTypeId, getListaGestionCasoAuditores(transaccion.RecordTypeId));

                        }

                    }

                    System.debug(LoggingLevel.WARN, camposByRT);

                    //Ciclamos sobre los casos
                    for (Transaccion__c transaccion : getDinamicQUery(whereList, null, idsTransacciones)) {

                        //Coleccionamos el id
                        idsCasos.add(transaccion.Id);

                        //Creamos un Nodo
                        GestionCasosController.Nodo n = new GestionCasosController.Nodo();

                        //Seteamos los datos
                        n.id = transaccion.id;
                        n.parent = idNodo;
                        //n.text = 'Auditoria'+' '+transaccion.Name;
                        n.setChildren(false);

                        if (camposByRT.containsKey(transaccion.RecordTypeId)) {

                            List<GestionCaso__c> campos = camposByRT.get(transaccion.RecordTypeId);

                            n.datos = getTransaccionDataByRecordType(campos, transaccion);

                        }

                        n.a_attr = new GestionCasosController.Atributo();

                        n.a_attr.href = '/' + transaccion.Id;

                        n.a_attr.data_type = 'node-link';

                        //Seteamos el tipo del caso
                        n.type = 'Auditoria';

                        //Agregamos el nodo a la lista de nodos
                        nodos.add(n);

                    }

                }else{ // Son casos

                    //Generamos el map del WhereList
                    Map<String, String> whereList = new Map<String, String>();

                    whereList.put('ParentId', nodoId);
                    whereList.put('RecordTypeId', rtId);

                    //Ciclamos sobre los casosy obtenemos sus recordtypeids

                    //Map para coleccionar sus recordtype y por cada RT los campos de su custom settings
                    Map<Id, List<GestionCaso__c>> camposByRT = new Map<Id, List<GestionCaso__c>>();

                    for (Case caso : GestionCasosController.getDinamicQUery(whereList, null)) {

                        if (!camposByRT.containsKey(caso.RecordTypeId)) {

                            //Llamamos a la puncion que nos da la lista de campos
                            camposByRT.put(caso.RecordTypeId, GestionCasosController.getListaGestionCaso(caso.RecordTypeId));

                        }

                    }

                    //Ciclamos sobre los casos
                    for (Case caso : GestionCasosController.getDinamicQUery(whereList, null)) {

                        //Coleccionamos el id
                        idsCasos.add(caso.Id);

                        //Creamos un Nodo
                        GestionCasosController.Nodo n = new GestionCasosController.Nodo();

                        //Seteamos los datos
                        n.id = caso.id;
                        n.parent = idNodo;
                        //n.text = 'Caso'+' '+caso.CaseNumber;
                        n.setChildren(GestionCasosController.hasChildrens(caso.Id));

                        if (camposByRT.containsKey(caso.RecordTypeId)) {

                            List<GestionCaso__c> campos = camposByRT.get(caso.RecordTypeId);

                            n.datos = GestionCasosController.getCaseDataByRecordType(campos, caso);

                        }

                        n.a_attr = new GestionCasosController.Atributo();

                        n.a_attr.href = '/' + caso.Id;

                        n.a_attr.data_type = 'node-link';

                        //Seteamos el tipo del caso
                        n.type = (caso.RecordTypeId == rtDUPId) ? 'DUP' : ((caso.RecordTypeId == rtCobId) ? 'Cobranza' : 'Venta');



                        //En base al tipo de caso seteamos una fecha
                        if (caso.RecordTypeId == rtDUPId && caso.Fecha_Comprometida_Respuesta__c != null) {

                            //Creamos un Dato mas que sera la fecha comprometida de respuesta
                            GestionCasosController.Data dato = new GestionCasosController.Data();

                            //Seteamos algunos valores
                            dato.label = 'Fecha Comprometida Respuesta';
                            dato.valor =  GestionCasosController.formatDate(caso.Fecha_Comprometida_Respuesta__c, 'dd/MM/yyyy');

                            //Agregamos el dato al nodo
                            n.fecha = dato;

                        } else if (caso.RecordTypeId == rtCobId && caso.Fecha_Comprometida_Pago__c != null) {

                            //Creamos un Dato mas que sera la fecha comprometida de respuesta
                            GestionCasosController.Data dato = new GestionCasosController.Data();

                            //Seteamos algunos valores
                            dato.label = 'Fecha Comprometida de Pago';
                            dato.valor =  GestionCasosController.formatDate(caso.Fecha_Comprometida_Pago__c, 'dd/MM/yyyy');

                            //Agregamos el dato al nodo
                            n.fecha = dato;

                        }

                        //Agregamos el nodo a la lista de nodos
                        nodos.add(n);

                    }

                }

                if (interaccion != null) {

                    //Obtenemos el caso gestionado (si lo hay)
                    for (Caso_Gestionado__c cg : [SELECT Id, Caso__c, Comentario_Codificado__c, Transaccion__c FROM Caso_Gestionado__c WHERE (Caso__c IN :idsCasos OR Transaccion__c IN :idsCasos ) AND Interaccion__c = :interaccion.Id]) {

                        //Buscamos el nodo en la lista de nodos
                        for (GestionCasosController.Nodo nodo : nodos) {

                            if (nodo.Id == cg.Caso__c || nodo.Id == cg.Transaccion__c) {

                                //Creamos un Dato mas que son los comentarios codificados
                                GestionCasosController.Data dato = new GestionCasosController.Data();

                                //Seteamos algunos valores
                                dato.label = 'Comentario Codificado';
                                dato.valor =  (cg.Comentario_Codificado__c == null) ? '' : cg.Comentario_Codificado__c;

                                //Agregamos el dato a la lista de datos
                                nodo.comentario_codificado = dato;

                            }

                        }

                    }


                    //Obtenemos las tareas (si las hay)
                    Set<Id> idsTasks = new Set<Id>();

                    for (Task tarea : tareas) {
                        idsTasks.add(tarea.Id);
                    }

                    for (Task tarea : [SELECT Id, WhatId, Description FROM Task WHERE Id IN :idsTasks]) {
                        //Buscamos el nodo en la lista de nodos
                        for (GestionCasosController.Nodo nodo : nodos) {

                            if (nodo.Id == tarea.WhatId) {

                                //Creamos un Dato mas que son los comentarios codificados
                                GestionCasosController.Data dato = new GestionCasosController.Data();

                                //Seteamos algunos valores
                                dato.label = 'Comentario';
                                dato.valor =  (tarea.Description == null) ? '' : tarea.Description;

                                //Agregamos el dato a la lista de datos
                                nodo.descripcion = dato;
                            }

                        }
                    }

                }

            } else {

                //Si se hace una request es porque tiene hijos, hacemos un ordenamiento por RecordType

                //Map para coleccionar los RecordType
                Map<Id, String> rtById = new Map<Id, String>();

                //Generamos el map del WhereList
                Map<String, String> whereList = new Map<String, String>();

                whereList.put('Nombre_de_la_cuenta__c', casoPadre.AccountId);

                //Recorremos los casos que hay y coleccionamos los RecordType que existen
                for (Transaccion__c transaccion : getDinamicQUery(whereList, null, idsTransacciones)) {
                    if (!rtById.containsKey(transaccion.RecordTypeId)) {
                        rtById.put(transaccion.RecordTypeId, GestionCasosController.getRecordTypeNameById(transaccion.RecordTypeId));
                    }
                }

                whereList.clear();

                whereList.put('ParentId', idNodo);

                //Recorremos los casos que hay y coleccionamos los RecordType que existen
                for (Case caso : GestionCasosController.getDinamicQUery(whereList, null)) {
                    if (!rtById.containsKey(caso.RecordTypeId)) {
                        rtById.put(caso.RecordTypeId, GestionCasosController.getRecordTypeNameById(caso.RecordTypeId));
                    }
                }

                //Recorremos el Map y vamos a crear un Nodo por cada RecordType
                for (Id rtId : rtById.keySet()) {

                    //Creamos un nodo
                    GestionCasosController.Nodo n = new GestionCasosController.Nodo();

                    //Seteamos los datos
                    if (rtId != null) {
                        n.id = rtId + '_' + idNodo;
                        n.parent = idNodo;
                        n.text = rtById.get(rtId);
                    } else {
                        n.id = rtId + '_' + idNodo;
                        n.parent = idNodo;
                        n.text = 'Ninguno';
                    }
                    //Como el RecordType es el RecordType de un Case indicamos que hay hijos
                    //Porque al menos sabemos que un case tiene ese RecordType
                    n.setChildren(true);

                    //Insertamos el nodo en la lista
                    nodos.add(n);
                }

            }

        }

        return nodos;
    }

    //Acion remota que permite obtener los datos del caso que necesitamos para el popup de ventas
    @RemoteAction
    public static GestionCasosController.DatosVentas getDatosVenta(String idCaso) {

        return GestionCasosController.getDatosVenta(idCaso);
        
    }

    //Accion remota que procesara todos los datos que se han pasado
    @RemoteAction
    public static GestionCasosController.Resultado procesarCasos(GestionCasosController.DatosProcesar dp) {

        //Conjunto de validaciones previas
        if (dp.parentCase == null)
            return null;


        if (dp.interaccion == null)
            return null;

        //Obtenemos las tareas a actualizar (si las hay)
        Set<Id> idsTasks = new Set<Id>();

        for (Task tarea : dp.tareas) {
            idsTasks.add(tarea.Id);
        }

        //Creamos un objeto resultado
        GestionCasosController.Resultado resultado = new GestionCasosController.Resultado();

        //Seteamos los dos valores a devolver
        resultado.tareas = dp.tareas;
        resultado.casosProcesados = 0;

        //Mensaje que contendra los errores de validacion
        String errorMsg = '';

        Set<Id> casosAPreProcesar = GestionCasosController.getCasosHijos(dp.idsCasos);

        Set<Id> transaccionesAPreProcesar = getTransaccionesHijos(dp.idsCasos);

        //Set que contendra los ids de los casos que ya fueron gestionados
        Set<Id> casosGestionados = GestionCasosController.getCasosGestionadosByInteraccion(dp.interaccion.Id);

        //Lista que contendra las Task a insertar
        List<Task> tareasToInsert = new List<Task>();

        //Lista que contendra los casos gestionados
        List<Caso_Gestionado__c> casosGestionadosToInsert = new List<Caso_Gestionado__c>();

        //Cadena que contendra los comentarios codificados
        String comentarios = '';

        //Ciclamos sobre los comentarios codificados
        for (Integer i = 0; i < dp.comentariosCodificados.size() ; i++) {
            if (i == 0){
                comentarios += dp.comentariosCodificados[i];
            }else{
                comentarios += ';' + dp.comentariosCodificados[i];
            }
        }

        //Obtenemos el RecordType de un Caso DUP
        Id rtDUPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');

        //Obtenemos el RecordType de una Cobranza
        Id rtCobId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');

        //Recorremos los casos que se han pasado y actualizamos las fechas si es que se paso alguna

        //Lista de casos a actualizar
        Set<Case> casosToUpdate = new Set<Case>();

        //Lista de transacciones a actualizar
        List<Transaccion__c> transaccionesToUpdate = new List<Transaccion__c>();

        Case casoPadre = [SELECT Id, AccountId FROM Case WHERE Id = :dp.parentCase];

        // Verificamos si es el caso de nada seleccionado
        // Creamos un caso gestionado con su task
        if(dp.idsCasos.isEmpty()){

            //Creamos un caso gestionado
            Caso_Gestionado__c casoGestionado = new Caso_Gestionado__c();

            //Seteamos algunos datos
            casoGestionado.Interaccion__c = dp.interaccion.Id;
            casoGestionado.Comentario_Codificado__c = comentarios;
            casoGestionado.Comentarios__c = dp.descripcion;
            casoGestionado.Cuenta__c = casoPadre.AccountId;
            casoGestionado.Tipo_de_actividad__c = dp.taskType;
            casoGestionado.Caso__c = casoPadre.Id;

            //Creamos una Task
            Task t = new Task();

            //Seteamos algunos valores
            t.WhatId = casoPadre.AccountId;
            t.Comentario_Codificado__c = comentarios;
            t.Status = 'Cerrada';
            t.Subject = dp.taskType;
            t.ActivityDate = Date.today();
            t.Description = dp.descripcion;
            t.Generada_desde_Pagina_Gestion_de_Casos__c = true;
            t.Type = dp.taskType;

            t.Gestion_Telefonica__c = (dp.interaccion.Modo_de_Contacto__c == 'Email Entrante') ? false : true;

            //Insertamos el caso gestionado a la lista de casos a insertar
            casosGestionadosToInsert.add(casoGestionado);
            //Insertamos la tarea a la lista de tareas a insertar
            tareasToInsert.add(t);

        }

        //Procesamos los datos de los casos que todavia no fueron gestionados
        for (Case caso : [SELECT Id, RecordType.Name, Fecha_Comprometida_Respuesta__c, Fecha_Comprometida_Pago__c, RecordTypeId, AccountId, CaseNumber, Subject, DUP__c, Factura__c FROM Case WHERE Id IN :casosAPreProcesar AND Id NOT IN :casosGestionados AND Status != 'Cerrado']) {

            //Contamos el caso procesado
            resultado.casosProcesados++;

            //Creamos un caso gestionado
            Caso_Gestionado__c casoGestionado = new Caso_Gestionado__c();

            //Seteamos algunos datos
            casoGestionado.Caso__c = caso.Id;
            casoGestionado.Interaccion__c = dp.interaccion.Id;
            casoGestionado.Comentario_Codificado__c = comentarios;
            casoGestionado.Comentarios__c = dp.descripcion;
            casoGestionado.Cuenta__c = caso.AccountId;
            casoGestionado.Tipo_de_actividad__c = dp.taskType;

            //Si el caso es una DUP seteamos la transaccion, si es una cobranza la factura
            if (rtDUPId == caso.RecordTypeId) {
                casoGestionado.Transaccion__c = caso.DUP__c;
            } else if (rtCobId == caso.RecordTypeId ) {
                casoGestionado.Factura__c = caso.Factura__c;
            }


            //Creamos una Task
            Task t = new Task();

            //Seteamos algunos valores
            t.WhatId = caso.Id;
            t.Comentario_Codificado__c = comentarios;
            t.Status = 'Cerrada';
            t.Subject = dp.taskType;
            t.ActivityDate = Date.today();
            t.Description = dp.descripcion;
            t.Generada_desde_Pagina_Gestion_de_Casos__c = true;
            t.Type = dp.taskType;

            t.Gestion_Telefonica__c = (dp.interaccion.Modo_de_Contacto__c == 'Email Entrante') ? false : true;

            //Validacion de Fecha de Compromiso
            if (dp.fechaRespuesta == null && caso.RecordTypeId == rtDUPId && (comentarios.contains('Promesa de Respuesta') || comentarios.contains('Solicita tiempo de Respuesta'))) {

                if (!errorMsg.contains('No se ha cargado la fecha comprometida de respuesta. En el caso asociado.')) {
                    errorMsg += '\n' + 'No se ha cargado la fecha comprometida de respuesta. En el caso asociado.';
                }

            } else if (dp.fechaPago == null && caso.RecordTypeId == rtCobId && (comentarios.contains('Promesa de Pago') || comentarios.contains('Solicita Plazo de pago'))) {

                if (!errorMsg.contains('No se ha cargado la fecha comprometida de pago. En el caso asociado.')) {
                    errorMsg += '\n' + 'No se ha cargado la fecha comprometida de pago. En el caso asociado.';
                }

            } else {

                if (caso.RecordTypeId == rtDUPId && (comentarios.contains('Promesa de Respuesta') || comentarios.contains('Solicita tiempo de Respuesta')) && dp.fechaRespuesta != null) {

                    //Actualizamos el caso
                    caso.Fecha_Comprometida_Respuesta__c = dp.fechaRespuesta;

                    //Agregamos a la lista
                    casosToUpdate.add(caso);

                } else if (caso.RecordTypeId == rtCobId && (comentarios.contains('Promesa de Pago') || comentarios.contains('Solicita Plazo de pago')) && dp.fechaPago != null) {

                    //Actualizamos el caso
                    caso.Fecha_Comprometida_Pago__c = dp.fechaPago;

                    //Agregamos a la lista
                    casosToUpdate.add(caso);
                }


                //Insertamos el caso gestionado a la lista de casos a insertar
                casosGestionadosToInsert.add(casoGestionado);
                //Insertamos la tarea a la lista de tareas a insertar
                tareasToInsert.add(t);

            }

        }


        System.debug(LoggingLevel.WARN, transaccionesAPreProcesar);
        System.debug(LoggingLevel.WARN, casosGestionados);


        // Procesamos las transacciones
        for (Transaccion__c transaccion : [SELECT Id, RecordType.Name, RecordTypeId, Nombre_de_la_cuenta__c  FROM Transaccion__c WHERE Id IN :transaccionesAPreProcesar AND Id NOT IN :casosGestionados AND Gestionada__c = false]) {

            //Contamos el caso procesado
            resultado.casosProcesados++;

            // Seteamos la transacciones como gestionada
            transaccion.Gestionada__c = true;

            //Insertamos la transaccion a la lista de transacciones a insertar
            transaccionesToUpdate.add(transaccion);

            //Creamos un caso gestionado
            Caso_Gestionado__c casoGestionado = new Caso_Gestionado__c();

            //Seteamos algunos datos
            casoGestionado.Interaccion__c = dp.interaccion.Id;
            casoGestionado.Comentario_Codificado__c = comentarios;
            casoGestionado.Comentarios__c = dp.descripcion;
            casoGestionado.Cuenta__c = transaccion.Nombre_de_la_cuenta__c;
            casoGestionado.Z9_Asunto__c = 'Temas de AUD';
            casoGestionado.Transaccion__c = transaccion.Id;
            casoGestionado.Tipo_de_actividad__c = dp.taskType;
            casoGestionado.Caso__c = casoPadre.Id;


            //Creamos una Task
            Task t = new Task();

            //Seteamos algunos valores
            t.WhatId = transaccion.Id;
            t.Comentario_Codificado__c = comentarios;
            t.Status = 'Cerrada';
            t.Subject = dp.taskType;
            t.ActivityDate = Date.today();
            t.Description = dp.descripcion;
            t.Generada_desde_Pagina_Gestion_de_Casos__c = true;
            t.Type = dp.taskType;

            t.Gestion_Telefonica__c = (dp.interaccion.Modo_de_Contacto__c == 'Email Entrante') ? false : true;

            //Insertamos el caso gestionado a la lista de casos a insertar
            casosGestionadosToInsert.add(casoGestionado);
            
            //Insertamos la tarea a la lista de tareas a insertar
            tareasToInsert.add(t);

        }

        System.debug(LoggingLevel.WARN, casosGestionadosToInsert);


        //Lista que contendra las tareas a actualizar
        List<Task> tareasToUpdate = new List<Task>();

        //Lista que contendra los casos gestionados a actualizar
        List<Caso_Gestionado__c> casosGestionadosToUpdate = new List<Caso_Gestionado__c>();

        //Recorremos los casos preprocesados
        for (Case caso : [SELECT Id, RecordTypeId, Fecha_Comprometida_Pago__c, Fecha_Comprometida_Respuesta__c, (SELECT Id FROM Tasks WHERE Id IN :idsTasks), (SELECT Id FROM Casos_Gestionados__r WHERE Interaccion__c = :dp.interaccion.Id) FROM Case WHERE Id IN :casosAPreProcesar AND Id IN :casosGestionados]) {

            //Contamos el caso procesado
            resultado.casosProcesados++;

            //Validacion de Fecha de Compromiso
            if (dp.fechaRespuesta == null && caso.RecordTypeId == rtDUPId && (comentarios.contains('Promesa de Respuesta') || comentarios.contains('Solicita tiempo de Respuesta'))) {

                if (!errorMsg.contains('No se ha cargado la fecha comprometida de respuesta. En el caso asociado.'))
                    errorMsg += '\n' + 'No se ha cargado la fecha comprometida de respuesta. En el caso asociado.';

            } else if (dp.fechaPago == null && caso.RecordTypeId == rtCobId && (comentarios.contains('Promesa de Pago') || comentarios.contains('Solicita Plazo de pago'))) {

                if (!errorMsg.contains('No se ha cargado la fecha comprometida de pago. En el caso asociado.'))
                    errorMsg += '\n' + 'No se ha cargado la fecha comprometida de pago. En el caso asociado.';

            } else {

                if (caso.RecordTypeId == rtDUPId && (comentarios.contains('Promesa de Respuesta') || comentarios.contains('Solicita tiempo de Respuesta')) && dp.fechaRespuesta != null) {
                    //Actualizamos el caso
                    caso.Fecha_Comprometida_Respuesta__c = dp.fechaRespuesta;
                    //Agregamos a la lista
                    casosToUpdate.add(caso);
                } else if (caso.RecordTypeId == rtCobId && (comentarios.contains('Promesa de Pago') || comentarios.contains('Solicita Plazo de pago')) && dp.fechaPago != null) {
                    //Actualizamos el caso
                    caso.Fecha_Comprometida_Pago__c = dp.fechaPago;
                    //Agregamos a la lista
                    casosToUpdate.add(caso);
                }

                //Recorremos las tareas
                for (Task tarea : caso.Tasks) {

                    tarea.Comentario_Codificado__c = comentarios;
                    tarea.Description = dp.descripcion;
                    tareasToUpdate.add(tarea);

                }

                //Recorremos los comentarios codificados
                for (Caso_Gestionado__c cg : caso.Casos_Gestionados__r) {

                    cg.Comentario_Codificado__c = comentarios;
                    cg.Comentarios__c = dp.descripcion;
                    casosGestionadosToUpdate.add(cg);

                }

            }

        }

        //Verificamos si hay errores de las validaciones
        if (errorMsg.length() > 0) {

            //Enviamos los mensajes de error para corregir

            //Ocurrio un error
            resultado.error = true;
            resultado.msg = errorMsg;
            resultado.interaccionDeleted = GestionCasosController.deleteInteraccion(dp.interaccion.Id);



        } else {

            Savepoint sp = Database.setSavepoint();

            try {

                //Actualizamos los casos si hay
                if (casosToUpdate.size() > 0) {

                    List<Case> toUpdate = new List<Case>();

                    toUpdate.addAll(casosToUpdate);

                    Utils.updateList(toUpdate);

                }

                // Actualizamos las transacciones si hay
                if(transaccionesToUpdate.size() > 0){
                    Utils.updateList(transaccionesToUpdate);
                }

                //Insertamos las tareas (si hay)
                if (tareasToInsert.size() > 0) {

                    //Agregamos las tareas a la lista de tareas creadas en la interaccion hasta el momento
                    for (Task tarea : tareasToInsert) {
                        resultado.tareas.add(tarea);
                    }

                    //Insertamos las tareas en la BD
                    Utils.insertList(tareasToInsert);

                }

                //Actualizamos las tareas si las hay
                if (tareasToUpdate.size() > 0) {

                    Utils.updateList(tareasToUpdate);

                }

                //Actualizamos los casos si los hay
                if (casosGestionadosToUpdate.size() > 0) {

                    //Actualizamos los casos gestionados
                    Utils.updateList(casosGestionadosToUpdate);

                }


                if (casosGestionadosToInsert.size() > 0) {

                    //Actualizamos los casos gestionados
                    Utils.insertList(casosGestionadosToInsert);

                }


                //No ocurrieron error
                resultado.error = false;

            } catch (Exception e) {

                //Ocurrio un error
                resultado.error = true;

                //Hacemos un rollback
                Database.rollback(sp);

                //Seteamos el mensaje de error
                ApexPages.addMessages(e);

                resultado.msg = ApexPages.getMessages()[0].getSummary();

                resultado.interaccionDeleted = GestionCasosController.deleteInteraccion(dp.interaccion.Id);

            }

        }

        return resultado;


    }


    public static Set<Id> getTransaccionesHijos(List<String> idsTransacciones) {

        //Set para coleccionar los casos a pre procesar
        Set<Id> transacciones = new Set<Id>();

        //Recorremos la lista de ids
        for (String id : idsTransacciones) {

            //Si se selecciono una agrupacion por tipo,obtenemos los casos involucrados
            if (GestionCasosController.validateId(id) == null) {

                //Hacemos un split del id
                List<String> ids = id.split('_');

                //Separamos los ids

                //Id del RecordType
                String rtId = (ids.get(0) == 'null') ? null : ids.get(0);

                //Id del Nodo
                String nodoId = ids.get(1);

                System.Debug(LoggingLevel.INFO, rtId);

                System.Debug(LoggingLevel.INFO, nodoId);

                 // Obtenemos el RecordType de Auditoria
                Id rtAuditorias = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');

                Case casoPadre = [Select Id, AccountId, Subject From Case where Id = : nodoId];

                //Obtenemos las auditorias
                for (Transaccion__c t : [SELECT Id FROM Transaccion__c WHERE RecordTypeId = :rtId AND Nombre_de_la_cuenta__c = :casoPadre.AccountId AND Gestionada__c = false]) {
                    transacciones.add(t.Id);
                }

            } else {
                
                transacciones.add(Id);

            }

        }


        return transacciones;
    }

    @RemoteAction
    public static GestionCasosController.Resultado enviarEmail(GestionCasosController.DatosProcesar dp) {

        //Conjunto de validaciones previas

        if (dp.parentCase == null)
            return null;

        if (dp.interaccion == null)
            return null;


        //Instanciamos un resultado
        GestionCasosController.Resultado resultado = new GestionCasosController.Resultado();

        Set<Id> casosAPreProcesar = GestionCasosController.getCasosHijos(dp.idsCasos);

        Set<Id> transaccionesAPreProcesar = getTransaccionesHijos(dp.idsCasos);

        //Lista que contendra las Task a insertar
        List<Task> tareasToInsert = new List<Task>();

        //Lista que contendra los casos gestionados
        List<Caso_Gestionado__c> casosGestionadosToInsert = new List<Caso_Gestionado__c>();

        //Obtenemos el RecordType de un Caso DUP
        Id rtDUPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');

        //Obtenemos el RecordType de una Cobranza
        Id rtCobId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');

        //Lista de transacciones a actualizar
        List<Transaccion__c> transaccionesToUpdate = new List<Transaccion__c>();

        //Cadena que contendra los comentarios codificados
        String comentarios = '';

        //Ciclamos sobre los comentarios codificados
        for (Integer i = 0; i < dp.comentariosCodificados.size() ; i++) {
            if (i == 0)
                comentarios += dp.comentariosCodificados[i];
            else
                comentarios += ';' + dp.comentariosCodificados[i];
        }


        Case casoPadre = [SELECT Id, AccountId FROM Case WHERE Id = :dp.parentCase];

        // Verificamos si es el caso de nada seleccionado
        // Creamos un caso gestionado con su task
        if(dp.idsCasos.isEmpty()){

            //Creamos un caso gestionado
            Caso_Gestionado__c casoGestionado = new Caso_Gestionado__c();

            //Seteamos algunos datos
            casoGestionado.Interaccion__c = dp.interaccion.Id;
            casoGestionado.Comentario_Codificado__c = comentarios;
            casoGestionado.Comentarios__c = dp.descripcion;
            casoGestionado.Cuenta__c = casoPadre.AccountId;
            casoGestionado.Tipo_de_actividad__c = dp.taskType;
            casoGestionado.Caso__c = casoPadre.Id;

            //Creamos una Task
            Task t = new Task();

            //Seteamos algunos valores
            t.WhatId = casoPadre.AccountId;
            t.Comentario_Codificado__c = comentarios;
            t.Status = 'Cerrada';
            t.Subject = 'Email';
            t.ActivityDate = Date.today();
            t.Description = dp.descripcion;
            t.Generada_desde_Pagina_Gestion_de_Casos__c = true;
            t.Type = dp.taskType;

            t.Gestion_Telefonica__c = (dp.interaccion.Modo_de_Contacto__c == 'Email Entrante') ? false : true;

            //Insertamos el caso gestionado a la lista de casos a insertar
            casosGestionadosToInsert.add(casoGestionado);
            //Insertamos la tarea a la lista de tareas a insertar
            tareasToInsert.add(t);

        }

        //Por cada caso vamos a crear una actividad y una interaccion pero a nivel caso padre
        for (Case caso : [SELECT Id, RecordType.Name, RecordTypeId, AccountId, CaseNumber, Subject, DUP__c, Factura__c FROM Case WHERE Id IN :casosAPreProcesar AND Status != 'Cerrado']) {

            //Creamos un caso gestionado
            Caso_Gestionado__c casoGestionado = new Caso_Gestionado__c();

            //Seteamos algunos datos
            casoGestionado.Caso__c = caso.id;

            casoGestionado.Interaccion__c = dp.interaccion.Id;

            casoGestionado.Comentario_Codificado__c = comentarios;
            casoGestionado.Tipo_de_actividad__c = dp.taskType;

            //Si el caso es una DUP seteamos la transaccion, si es una cobranza la factura
            if (rtDUPId == caso.RecordTypeId) {
                casoGestionado.Transaccion__c = caso.DUP__c;
            } else if (rtCobId == caso.RecordTypeId ) {
                casoGestionado.Factura__c = caso.Factura__c;
            }

            //Insertamos el caso gestionado a la lista de casos a insertar
            casosGestionadosToInsert.add(casoGestionado);


            //Creamos una Task
            Task t = new Task();

            //Seteamos algunos valores
            t.WhatId = caso.id;
            t.Status = 'Cerrada';
            t.Subject = 'Email';
            t.ActivityDate = Date.today();
            t.Generada_desde_Pagina_Gestion_de_Casos__c = true;
            t.Comentario_Codificado__c = comentarios;
            t.Type = dp.taskType;

            //Insertamos la tarea a la lista de tareas a insertar
            tareasToInsert.add(t);

        }

        // Procesamos las transacciones
        for (Transaccion__c transaccion : [SELECT Id, RecordType.Name, RecordTypeId, Nombre_de_la_cuenta__c  FROM Transaccion__c WHERE Id IN :transaccionesAPreProcesar AND Gestionada__c = false]) {

            //Contamos el caso procesado
            resultado.casosProcesados++;

            // Seteamos la transacciones como gestionada
            transaccion.Gestionada__c = true;

            //Insertamos la transaccion a la lista de transacciones a insertar
            transaccionesToUpdate.add(transaccion);

            //Creamos un caso gestionado
            Caso_Gestionado__c casoGestionado = new Caso_Gestionado__c();

            //Seteamos algunos datos
            casoGestionado.Interaccion__c = dp.interaccion.Id;
            casoGestionado.Comentario_Codificado__c = comentarios;
            casoGestionado.Cuenta__c = transaccion.Nombre_de_la_cuenta__c;
            casoGestionado.Z9_Asunto__c = 'Temas de AUD';
            casoGestionado.Transaccion__c = transaccion.Id;
            casoGestionado.Tipo_de_actividad__c = dp.taskType;
            casoGestionado.Caso__c = casoPadre.Id;


            //Creamos una Task
            Task t = new Task();

            //Seteamos algunos valores
            t.WhatId = transaccion.id;
            t.Status = 'Cerrada';
            t.Subject = 'Email';
            t.ActivityDate = Date.today();
            t.Generada_desde_Pagina_Gestion_de_Casos__c = true;
            t.Comentario_Codificado__c = comentarios;
            t.Type = dp.taskType;

            //Insertamos la tarea a la lista de tareas a insertar
            tareasToInsert.add(t);

            //Insertamos el caso gestionado a la lista de casos a insertar
            casosGestionadosToInsert.add(casoGestionado);

        }

        if (casosAPreProcesar.size() > 0) {

            try {

                //Insertamos las tareas (si hay)
                if (tareasToInsert.size() > 0) {
                    Utils.insertList(tareasToInsert);
                }

                if (casosGestionadosToInsert.size() > 0) {
                    Utils.insertList(casosGestionadosToInsert);
                }

                // Actualizamos las transacciones si hay
                if(transaccionesToUpdate.size() > 0){
                    Utils.updateList(transaccionesToUpdate);
                }

                //Indicamos que no ocurrio error
                resultado.error = false;

            } catch (Exception e) {

                //Indicamos que ocurrio un error
                resultado.error = true;
                ApexPages.addMessages(e);
                resultado.msg = ApexPages.getMessages()[0].getSummary();
                resultado.interaccionDeleted = GestionCasosController.deleteInteraccion(dp.interaccion.Id);

            }

        }

        return resultado;

    }

    @TestVisible
    private static List<GestionCaso__c> getListaGestionCasoAuditores(Id rtId) {

        //Obtenemos el developer name
        List<RecordType> rts = [SELECT Id, DeveloperName FROM RecordType WHERE  SobjectType = 'Transaccion__c' AND Id = :rtId LIMIT 1];

        //Lista con los record de GestionCaso
        List<GestionCaso__c> records = new List<GestionCaso__c>();

        if (rts.size() > 0) {
            //Obtenemos el RT
            RecordType rt = rts.get(0);

            for (GestionCaso__c campo : [SELECT Campo__c, RecordType__c, Label__c, Agregar_Link__c, Mostrar_Popup__c, FieldSet__c FROM GestionCaso__c WHERE RecordType__c = :rt.DeveloperName AND Tipo__c = 'Transaccion' ORDER BY Orden__c ASC]) {
                records.add(campo);
            }

        }

        return records;

    }

    @TestVisible 
    private static List<GestionCasosController.Data> getTransaccionDataByRecordType(List<GestionCaso__c> lista, Transaccion__c transaccion) {


        if (lista.size() > 0) {

            //Lista de datos del nodo
            List<GestionCasosController.Data> datos = new List<GestionCasosController.Data>();

            //Obtenemos los campos del CustomSettings para ese RecordType
            for (GestionCaso__c campo : lista) {

                //Creamos un nuevo objeto Dato
                GestionCasosController.Data dato = new GestionCasosController.Data();

                //Seteamos algunos valores
                dato.label = campo.Label__c;
                dato.isLink = campo.Agregar_Link__c;
                dato.showPopUp = campo.Mostrar_Popup__c;
                dato.conjunto = campo.FieldSet__c;

                if (campo.Campo__c.indexOf('.') != -1) {
                    List<String> valores = campo.Campo__c.split('\\.');
                    sObject o = transaccion;
                    for (Integer i = 0; i < valores.size(); i++) {
                        if (o == null)
                            break;
                        if ((i + 1) == valores.size()) {
                            dato.valor = String.valueOf(o.get(valores[i]));
                            dato.id = String.valueOf(o.get('Id'));
                        } else {
                            o = o.getSObject(valores[i]);
                        }
                    }

                } else {
                    dato.valor = String.valueOf(transaccion.get(campo.Campo__c));
                    dato.id = String.valueOf(transaccion.get('Id'));
                }

                //Hacemos un checkeo para verificar que el valor no sea null
                if (dato.valor == null) {

                    //Borramos el valor
                    dato.valor = '';

                    //Borramos el id
                    dato.id = '';

                    //Indicamos que no es linkeable
                    dato.isLink = false;

                    //Indicamos que no muestre popup
                    dato.showPopUp = false;

                }

                //Insertamos el Dato en la lista
                datos.add(dato);
            }

            return datos;
        }

        return null;
    }

    private static List<Transaccion__c> getDinamicQUery(Map<String, String> whereList, Integer limite, Set<Id> idsTransacciones) {

        //Obtenemos los campos que se setearon por custom settings
        Set<String> camposCS = new Set<String>();

        //Recorremos la Custom Setting
        for (GestionCaso__c campo : [SELECT Campo__c FROM GestionCaso__c WHERE Tipo__c = 'Transaccion']) {
            camposCS.add(campo.Campo__c);
        }

        //Obtenemos todos los campos de un objeto Transaccion
        SObjectType transaccionType = Schema.getGlobalDescribe().get('Transaccion__c');
        
        Map<String, Schema.SObjectField> mfields = transaccionType.getDescribe().fields.getMap();

        //String que contendra la query
        String query = 'SELECT';

        //Set que contendra todos los campos que necesitamos traer
        Set<String> fieldSet = new Set<String>();

        //Agregamos el set de campos del sObject Case
        for (String field : mfields.keySet()) {
            fieldSet.add(field.trim().toLowerCase());
        }

        //Agregamos el set de campos que viene por Custom Settings
        for (String field : camposCS) {
            fieldSet.add(field.trim().toLowerCase());
        }

        //Ciclamos por los campos
        for (String field : fieldSet) {
            if (query == 'SELECT')
                query += ' ' + field;
            else
                query += ' ,' + field;
        }

        //Agregamos la clausula FROM
        query += ' ' + 'FROM' + ' ' + 'Transaccion__c';

        //Armamos el WHERE
        query += ' ' + 'WHERE RecordType.DeveloperName = \'Auditorias\' AND (  Id IN :idsTransacciones OR Gestionada__c = ' + 'false)';

        Integer i = 0;

        for (String s : whereList.keySet()) {

            query += ' ' + 'AND' + ' ' + s + ' ' + '=' + ' ';

            if (whereList.get(s) == null) {
                query += 'null';
            } else {
                query += '\'' + whereList.get(s) + '\'';
            }
            i++;
        }

        if (limite != null) {
            query += ' ' + 'LIMIT' + ' ' + limite;
        }


        return Database.query(query);
    }

    private static Set<Id> getTransaccionesByInteraccion(Interaccion__c interaccion){

        Set<Id> idsTransacciones = new Set<Id>();

        if(interaccion == null){
            return idsTransacciones;
        }

        for(Caso_Gestionado__c cg : [SELECT Id, Transaccion__c FROM Caso_Gestionado__c WHERE Interaccion__c = :interaccion.Id]){
            idsTransacciones.add(cg.Transaccion__c);
        }

        return idsTransacciones;

    }

    public PageReference cancel() {
        //Redirigimos al caso principal
        PageReference prRef = new PageReference('/' + caso.AccountId);
        prRef.setRedirect(true);
        return prRef;
    }

    public PageReference addRecordatorio() {

        String url = '/00U/e?who_id=001J000001FcqXl&what_id=' + caso.AccountId + '&retURL=/' + caso.AccountId;

        PageReference prRef = new PageReference(url);
        prRef.setRedirect(true);
        return prRef;
    }

}