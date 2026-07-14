public without sharing class GestionCasosController {

    //Atributo que contendra el caso
    public Case caso {get; set;}

    //Atributo que contendra la tarea que usamos como plantilla
    public Task tarea {get; set;}

    //Atributo que contendra los comentarios
    public List<String> comentarios {get; set;}

    public Interaccion__c interaccion {get; set;}

    public GestionCasosController(ApexPages.StandardController controller) {
        caso = (Case)controller.getRecord();
        tarea = new Task();
        comentarios = populateSelect();
    }

    /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo que retorna los comentarios validos para la Gestion Telefonica
    */
    public static List<String> getComentariosTelefono() {

        //Lista que contendra los comentarios validos para la Gestión Telefonica
        List<String> comentarios = new List<String>();

        //Consulto por los comentarios en la DB
        for (Comentarios_Codificados__c comentario : [SELECT Id, Comentarios_Codificados__c FROM Comentarios_Codificados__c WHERE GestionCasoTelefonico__c = true ORDER BY Orden__c]) {

            comentarios.add(comentario.Comentarios_Codificados__c);

        }


        return comentarios;

    }

    /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo que retorna los comentarios validos para la Gestion via Email
    */
    public static List<String> getComentariosEmail() {

        //Lista que contendra los comentarios validos para la Gestión Telefonica
        List<String> comentarios = new List<String>();

        //Consulto por los comentarios en la DB
        for (Comentarios_Codificados__c comentario : [SELECT Id, Comentarios_Codificados__c FROM Comentarios_Codificados__c WHERE GestionCasoEmail__c = true ORDER BY Orden__c]) {

            comentarios.add(comentario.Comentarios_Codificados__c);

        }


        return comentarios;

    }

    public static List<String> populateSelect() {

        //Obtenemos el Descriptor del Campo
        Schema.DescribeFieldResult fieldResult = Task.Comentario_Codificado__c.getDescribe();

        //Obtenemos los valores de la pick list
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();

        //Instanciamos la lista de opciones
        List<String> options = new List<String>();

        //Recorremos los valores del picklist y armamos las opciones
        for ( Schema.PicklistEntry f : ple) {
            options.add(f.getLabel());
        }

        return options;
    }

    //Metodo para crear una interaccion al momento de crear la pagina
    @RemoteAction
    public static Resultado crearInteraccion(Id parentId, String modoContacto) {

        //Creamos una interaccion
        Interaccion__c interaccion = new Interaccion__c();

        interaccion.Caso__c = parentId;
        interaccion.Modo_de_Contacto__c = modoContacto;
        interaccion.Fecha_y_Hora__c =  system.now();
        interaccion.Operador__c = UserInfo.getUserId();

        //Instanciamos un resultado
        Resultado resultado = new Resultado();

        try {

            //Insertamos la interaccion
            insert interaccion;

            //Seteamos la interaccion en el resultado
            resultado.interaccion = interaccion;

            //No ocurrio un error
            resultado.error = false;

        } catch (Exception e) {

            //Ocurrio un error
            resultado.error = true;

            ApexPages.addMessages(e);
            resultado.msg = ApexPages.getMessages()[0].getSummary();

        }

        //Devolvemos la interaccion
        return resultado;
    }


    //Accion Remota que ira llenado el arbol a demanda
    @RemoteAction
    public static List<Nodo> getNodos(String idNodo, String parentId, String nodoPrincipal, Interaccion__c interaccion, List<Task> tareas) {

        //Obtenemos el RecordType de un Caso DUP
        Id rtDUPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');

        //Obtenemos el RecordType de una Cobranza
        Id rtCobId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');

        //Lista que contendra los nodos a devolver
        List<Nodo> nodos = new List<Nodo>();

        //Consultamos si es el primer nodo
        if (idNodo == '#' && parentId == null) {

            //Generamos el map del WhereList
            Map<String, String> whereList = new Map<String, String>();

            whereList.put('Id', nodoPrincipal);

            //Obtenemos los datos del caso principal
            List<Case> casos = getDinamicQUery(whereList, 1);

            if (casos.size() > 0) {
                //Obtenemos el caso
                Case c = casos.get(0);

                //Creamos un nodo
                Nodo n = new Nodo();
                n.id = c.id;
                n.parent = idNodo;
                n.text = c.Subject;
                n.setChildren(hasChildrens(c.Id));
                n.state = new State();
                n.state.opened = true;

                //Obtenemos el nombre de la cuenta
                List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id = :c.AccountId LIMIT 1];

                if (accounts.size() > 0) {

                    //Lista que contendra los datos
                    List<Data> datos = new List<Data>();

                    //Obtenemos la cuenta
                    Account cuenta = accounts.get(0);

                    //Seteamos los datos de la cuenta al nodo
                    Data dato = new Data();

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

        } else {

            //Verificamos si es un id valido de salforce (sino sabemos que se esta abriendo un tipo)

            if (validateId(idNodo) == null) {

                //Hacemos un split del id
                List<String> ids = idNodo.split('_');

                //Separamos los ids

                //Id del RecordType
                String rtId = (ids.get(0) == 'null') ? null : ids.get(0);

                //Id del Nodo
                String nodoId = ids.get(1);

                //Set para contener los ids de los casos consultados
                Set<Id> idsCasos = new Set<Id>();

                //Generamos el map del WhereList
                Map<String, String> whereList = new Map<String, String>();

                whereList.put('ParentId', nodoId);
                whereList.put('RecordTypeId', rtId);

                //Ciclamos sobre los casosy obtenemos sus recordtypeids

                //Map para coleccionar sus recordtype y por cada RT los campos de su custom settings
                Map<Id, List<GestionCaso__c>> camposByRT = new Map<Id, List<GestionCaso__c>>();

                for (Case caso : getDinamicQUery(whereList, null)) {

                    if (!camposByRT.containsKey(caso.RecordTypeId)) {

                        //Llamamos a la puncion que nos da la lista de campos
                        camposByRT.put(caso.RecordTypeId, getListaGestionCaso(caso.RecordTypeId));

                    }

                }

                //Ciclamos sobre los casos
                for (Case caso : getDinamicQUery(whereList, null)) {

                    //Coleccionamos el id
                    idsCasos.add(caso.Id);

                    //Creamos un Nodo
                    Nodo n = new Nodo();

                    //Seteamos los datos
                    n.id = caso.id;
                    n.parent = idNodo;
                    //n.text = 'Caso'+' '+caso.CaseNumber;
                    n.setChildren(hasChildrens(caso.Id));

                    if (camposByRT.containsKey(caso.RecordTypeId)) {

                        List<GestionCaso__c> campos = camposByRT.get(caso.RecordTypeId);

                        n.datos = getCaseDataByRecordType(campos, caso);

                    }

                    n.a_attr = new Atributo();

                    n.a_attr.href = '/' + caso.Id;

                    n.a_attr.data_type = 'node-link';

                    //Seteamos el tipo del caso
                    n.type = (caso.RecordTypeId == rtDUPId) ? 'DUP' : ((caso.RecordTypeId == rtCobId) ? 'Cobranza' : 'Venta');



                    //En base al tipo de caso seteamos una fecha
                    if (caso.RecordTypeId == rtDUPId && caso.Fecha_Comprometida_Respuesta__c != null) {

                        //Creamos un Dato mas que sera la fecha comprometida de respuesta
                        Data dato = new Data();

                        //Seteamos algunos valores
                        dato.label = 'Fecha Comprometida Respuesta';
                        dato.valor =  formatDate(caso.Fecha_Comprometida_Respuesta__c, 'dd/MM/yyyy');

                        //Agregamos el dato al nodo
                        n.fecha = dato;

                    } else if (caso.RecordTypeId == rtCobId && caso.Fecha_Comprometida_Pago__c != null) {

                        //Creamos un Dato mas que sera la fecha comprometida de respuesta
                        Data dato = new Data();

                        //Seteamos algunos valores
                        dato.label = 'Fecha Comprometida de Pago';
                        dato.valor =  formatDate(caso.Fecha_Comprometida_Pago__c, 'dd/MM/yyyy');

                        //Agregamos el dato al nodo
                        n.fecha = dato;

                    }

                    //Agregamos el nodo a la lista de nodos
                    nodos.add(n);

                }

                if (interaccion != null) {

                    //Obtenemos el caso gestionado (si lo hay)
                    for (Caso_Gestionado__c cg : [SELECT Id, Caso__c, Comentario_Codificado__c FROM Caso_Gestionado__c WHERE Caso__c IN :idsCasos AND Interaccion__c = :interaccion.Id]) {

                        //Buscamos el nodo en la lista de nodos
                        for (Nodo nodo : nodos) {

                            if (nodo.Id == cg.Caso__c) {

                                //Creamos un Dato mas que son los comentarios codificados
                                Data dato = new Data();

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
                        for (Nodo nodo : nodos) {

                            if (nodo.Id == tarea.WhatId) {

                                //Creamos un Dato mas que son los comentarios codificados
                                Data dato = new Data();

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

                whereList.put('ParentId', idNodo);

                //Recorremos los casos que hay y coleccionamos los RecordType que existen
                for (Case caso : getDinamicQUery(whereList, null)) {
                    if (!rtById.containsKey(caso.RecordTypeId)) {
                        rtById.put(caso.RecordTypeId, getRecordTypeNameById(caso.RecordTypeId));
                    }
                }

                //Recorremos el Map y vamos a crear un Nodo por cada RecordType
                for (Id rtId : rtById.keySet()) {

                    //Creamos un nodo
                    Nodo n = new Nodo();

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

    //Metodo Auxiliar para formato de fecha
    public static String formatDate(Date fecha, String format) {

        return Datetime.newInstance(fecha, time.newInstance(0, 0, 0, 0)).format(format);

    }

    //Acion remota que permite obtener los datos del caso que necesitamos para el popup de ventas
    @RemoteAction
    public static DatosVentas getDatosVenta(String idCaso) {

        DatosVentas dv = new DatosVentas();

        //Obtenemos los datos necesarios para mostrar el popup de ventas
        List<Case> casos = [SELECT AccountId, Campana__r.Ano__c, Campana__r.Cultivo__r.Name, Obtentor__r.Id_Obtentor__c FROM Case WHERE Id = :idCaso LIMIT 1];

        //Si obtuvimos datos los cargamos en el objeto a retornar
        if (casos.size() > 0) {

            Case caso = casos.get(0);

            dv.idCuenta = caso.AccountId;
            dv.idObtentor = caso.Obtentor__r.Id_Obtentor__c;
            dv.anoCampana = caso.Campana__r.Ano__c;
            dv.cultivo = caso.Campana__r.Cultivo__r.Name;

        }

        return dv;
    }

    //Accion remota que procesara todos los datos que se han pasado
    @RemoteAction
    public static Resultado procesarCasos(DatosProcesar dp) {

        //Conjunto de validaciones previas

        if (dp.idsCasos.size() == 0)
            return null;

        if (dp.comentariosCodificados.size() == 0 && dp.descripcion.trim() == '')
            return null;

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
        Resultado resultado = new Resultado();

        //Seteamos los dos valores a devolver
        resultado.tareas = dp.tareas;
        resultado.casosProcesados = 0;

        //Mensaje que contendra los errores de validacion
        String errorMsg = '';

        Set<Id> casosAPreProcesar = getCasosHijos(dp.idsCasos);

        //Set que contendra los ids de los casos que ya fueron gestionados
        Set<Id> casosGestionados = getCasosGestionadosByInteraccion(dp.interaccion.Id);

        //Lista que contendra las Task a insertar
        List<Task> tareasToInsert = new List<Task>();

        //Lista que contendra los casos gestionados
        List<Caso_Gestionado__c> casosGestionadosToInsert = new List<Caso_Gestionado__c>();

        //Cadena que contendra los comentarios codificados
        String comentarios = '';

        //Ciclamos sobre los comentarios codificados
        for (Integer i = 0; i < dp.comentariosCodificados.size() ; i++) {
            if (i == 0)
                comentarios += dp.comentariosCodificados[i];
            else
                comentarios += ';' + dp.comentariosCodificados[i];
        }

        //Obtenemos el RecordType de un Caso DUP
        Id rtDUPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');

        //Obtenemos el RecordType de una Cobranza
        Id rtCobId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');

        //Recorremos los casos que se han pasado y actualizamos las fechas si es que se paso alguna

        //Lista de casos a actualizar
        Set<Case> casosToUpdate = new Set<Case>();

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
            t.Subject = (dp.interaccion.Modo_de_Contacto__c == 'Email Entrante') ? 'Email Entrante' : 'Llamada';
            t.ActivityDate = Date.today();
            t.Description = dp.descripcion;
            t.Generada_desde_Pagina_Gestion_de_Casos__c = true;

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
            resultado.interaccionDeleted = deleteInteraccion(dp.interaccion.Id);



        } else {

            Savepoint sp = Database.setSavepoint();

            try {

                //Actualizamos los casos si hay
                if (casosToUpdate.size() > 0) {

                    List<Case> toUpdate = new List<Case>();

                    toUpdate.addAll(casosToUpdate);

                    Utils.updateList(toUpdate);

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

                resultado.interaccionDeleted = deleteInteraccion(dp.interaccion.Id);

            }

        }

        return resultado;


    }

    public static Boolean deleteInteraccion(Id idInteraccion) {

        //Obtenemos los casos gestionados de la interaccion
        Set<Id> idsCasos = getCasosGestionadosByInteraccion(idInteraccion);

        //Si no hay casos gestionados, eliminamos la interaccion
        if (idsCasos.size() == 0) {

            //Obtenemos la interaccion
            List<Interaccion__c> interacciones = [SELECT Id FROM Interaccion__c WHERE Id = :idInteraccion LIMIT 1];

            //Si obtuvimos la interaccion, la eliminamos
            if (interacciones.size() == 1) {

                try {
                    delete interacciones;
                    return true;
                } catch (Exception e) {
                    return false;
                }
            }

        }

        return false;

    }

    @RemoteAction
    public static Resultado enviarEmail(DatosProcesar dp) {

        //Conjunto de validaciones previas

        if (dp.idsCasos.size() == 0)
            return null;

        if (dp.parentCase == null)
            return null;

        if (dp.interaccion == null)
            return null;


        //Instanciamos un resultado
        Resultado resultado = new Resultado();

        Set<Id> casosAPreProcesar = getCasosHijos(dp.idsCasos);

        //Lista que contendra las Task a insertar
        List<Task> tareasToInsert = new List<Task>();

        //Lista que contendra los casos gestionados
        List<Caso_Gestionado__c> casosGestionadosToInsert = new List<Caso_Gestionado__c>();

        //Obtenemos el RecordType de un Caso DUP
        Id rtDUPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');

        //Obtenemos el RecordType de una Cobranza
        Id rtCobId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');


        //Cadena que contendra los comentarios codificados
        String comentarios = '';

        //Ciclamos sobre los comentarios codificados
        for (Integer i = 0; i < dp.comentariosCodificados.size() ; i++) {
            if (i == 0)
                comentarios += dp.comentariosCodificados[i];
            else
                comentarios += ';' + dp.comentariosCodificados[i];
        }

        //Por cada caso vamos a crear una actividad y una interaccion pero a nivel caso padre
        for (Case caso : [SELECT Id, RecordType.Name, RecordTypeId, AccountId, CaseNumber, Subject, DUP__c, Factura__c FROM Case WHERE Id IN :casosAPreProcesar AND Status != 'Cerrado']) {

            //Creamos un caso gestionado
            Caso_Gestionado__c casoGestionado = new Caso_Gestionado__c();

            //Seteamos algunos datos
            casoGestionado.Caso__c = caso.id;

            casoGestionado.Interaccion__c = dp.interaccion.Id;

            casoGestionado.Comentario_Codificado__c = comentarios;

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

            //Insertamos la tarea a la lista de tareas a insertar
            tareasToInsert.add(t);

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



                //Indicamos que no ocurrio error
                resultado.error = false;

            } catch (Exception e) {

                //Indicamos que ocurrio un error
                resultado.error = true;
                ApexPages.addMessages(e);
                resultado.msg = ApexPages.getMessages()[0].getSummary();
                resultado.interaccionDeleted = deleteInteraccion(dp.interaccion.Id);

            }

        }

        return resultado;

    }

    public static Set<Id> getCasosGestionadosByInteraccion(Id interaccionId) {

        //Set que contendra los casos que ya han sido gestionados para la interaccion actual
        Set<Id> casosGestionados = new Set<Id>();

        for (Caso_Gestionado__c caso : [SELECT Id, Caso__c, Transaccion__c FROM Caso_Gestionado__c WHERE Interaccion__c = :interaccionId]) {
            Id idSObject = (String.isNotEmpty(caso.Caso__c))?caso.Caso__c:caso.Transaccion__c;
            casosGestionados.add(idSObject);
        }

        return casosGestionados;
    }

    public static Set<Id> getCasosHijos(List<String> idsCasos) {
        //Set para coleccionar los casos a pre procesar
        Set<Id> casosAPreProcesar = new Set<Id>();

        //Set para coleccionar los casos a los que vamos a crearles una actividad
        Set<Id> casosAProcesar = new Set<Id>();


        //Recorremos la lista de ids
        for (String id : idsCasos) {

            //Si se selecciono una agrupacion por tipo,obtenemos los casos involucrados
            if (validateId(id) == null) {

                //Hacemos un split del id
                List<String> ids = id.split('_');

                //Separamos los ids

                //Id del RecordType
                String rtId = (ids.get(0) == 'null') ? null : ids.get(0);

                //Id del Nodo
                String nodoId = ids.get(1);

                System.Debug(LoggingLevel.INFO, rtId);

                System.Debug(LoggingLevel.INFO, nodoId);

                //Obtenemos los casos
                for (Case c : [SELECT Id FROM Case WHERE RecordTypeId = :rtId AND ParentId = :nodoId AND Status != 'Cerrado']) {
                    casosAPreProcesar.add(c.Id);
                }

            } else {
                casosAPreProcesar.add(Id);
            }

        }


        //Proceso para obtener todos los casos hijos
        Boolean hasParent = true;

        //Set que contendra los hijos de estos casos que estamos procesando (si los hay)
        Set<Id> casosHijos = new Set<Id>();

        while (hasParent) {
            for (Case c : [SELECT Id, ParentId FROM Case WHERE ParentId IN :casosAPreProcesar]) {
                //Coleccionamos los hijos
                casosHijos.add(c.Id);
                //Si hay padres en el Set de preprocesamiento los eliminamos (siempre nos quedamos con los hijos)
                casosAPreProcesar.remove(c.ParentId);
            }
            //El corte se produce cuando ya no hay mas hijos (ya obtuve todos los casos hijos)
            hasParent = casosHijos.size() != 0;

            //Agrego los hijos a la lista de casos a preprocesar
            casosAPreProcesar.addAll(casosHijos);

            //Limpiamos el Set de Datos
            casosHijos = new Set<Id>();
        }

        return casosAPreProcesar;
    }

    public PageReference cancel() {
        //Redirigimos al caso principal
        PageReference prRef = new PageReference('/' + caso.Id);
        prRef.setRedirect(true);
        return prRef;
    }

    public PageReference addRecordatorio() {

        String url = '/00U/e?who_id=001J000001FcqXl&what_id=' + caso.Id + '&retURL=/' + caso.Id;

        PageReference prRef = new PageReference(url);
        prRef.setRedirect(true);
        return prRef;
    }

    public static List<GestionCaso__c> getListaGestionCaso(Id rtId) {

        //Obtenemos el developer name
        List<RecordType> rts = [SELECT Id, DeveloperName FROM RecordType WHERE   SobjectType = 'Case' AND Id = :rtId LIMIT 1];

        //Lista con los record de GestionCaso
        List<GestionCaso__c> records = new List<GestionCaso__c>();

        if (rts.size() > 0) {
            //Obtenemos el RT
            RecordType rt = rts.get(0);

            for (GestionCaso__c campo : [SELECT Campo__c, RecordType__c, Label__c, Agregar_Link__c, Mostrar_Popup__c, FieldSet__c FROM GestionCaso__c WHERE RecordType__c = :rt.DeveloperName AND Tipo__c = 'Case' ORDER BY Orden__c ASC]) {
                records.add(campo);
            }

        }

        return records;

    }

    @TestVisible public static List<Data> getCaseDataByRecordType(List<GestionCaso__c> lista, Case caso) {


        if (lista.size() > 0) {

            //Lista de datos del nodo
            List<Data> datos = new List<Data>();

            //Obtenemos los campos del CustomSettings para ese RecordType
            for (GestionCaso__c campo : lista) {

                //Creamos un nuevo objeto Dato
                Data dato = new Data();

                //Seteamos algunos valores
                dato.label = campo.Label__c;
                dato.isLink = campo.Agregar_Link__c;
                dato.showPopUp = campo.Mostrar_Popup__c;
                dato.conjunto = campo.FieldSet__c;

                if (campo.Campo__c.indexOf('.') != -1) {
                    List<String> valores = campo.Campo__c.split('\\.');
                    sObject o = caso;
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
                    dato.valor = String.valueOf(caso.get(campo.Campo__c));
                    dato.id = String.valueOf(caso.get('Id'));
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

    public static String getRecordTypeNameById(Id id) {
        List<RecordType> rts = [SELECT Name FROM RecordType WHERE Id = :id LIMIT 1];
        if (rts.size() > 0) {
            return rts.get(0).Name;
        } else {
            return '';
        }
    }

    public static List<Case> getDinamicQUery(Map<String, String> whereList, Integer limite) {

        //Obtenemos los campos que se setearon por custom settings
        Set<String> camposCS = new Set<String>();


        //Recorremos la Custom Setting y Coleccionamos los Casos
        for (GestionCaso__c campo : [SELECT Campo__c FROM GestionCaso__c WHERE Tipo__c = 'Case']) {
            camposCS.add(campo.Campo__c);
        }


        //Obtenemos todos los campos de un objeto Caso
        SObjectType caseType = Schema.getGlobalDescribe().get('Case');
        Map<String, Schema.SObjectField> mfields = caseType.getDescribe().fields.getMap();

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
        query += ' ' + 'FROM' + ' ' + 'Case';

        //Armamos el WHERE
        query += ' ' + 'WHERE Status != ' + '\'' + 'Cerrado' + '\'';

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

        System.Debug(LoggingLevel.INFO, query);

        return Database.query(query);
    }

    public static Boolean hasChildrens(Id caseId) {
        List<Case> casos = [SELECT Id FROM Case WHERE ParentId = :caseId LIMIT 1];
        return (casos.size() > 0);
    }

    public static String validateId(String Idparam) {
        String id = String.escapeSingleQuotes(Idparam);
        if ((id.length() == 15 || id.length() == 18) && Pattern.matches('^[a-zA-Z0-9]*$', id)) {
            return id;
        }
        return null;
    }


    //Clase Auxiliar que representara un Nodo del Arbol
    public class Nodo {

        //Constantes

        //Ruta Imagen Archivo
        public String rutaArchivo = 'jstree-default jstree-file';

        //Ruta Imagen Carpeta
        public String rutaCarpeta = 'jstree-default jstree-folder';

        //Atributos
        public String id {get; set;}
        public String parent {get; set;}
        public String text {get; set;}
        public Boolean children;
        public String icon {get; set;}
        public List<Data> datos {get; set;}
        public State state {get; set;}
        public Atributo a_attr {get; set;}
        public Data comentario_codificado {get; set;}
        public Data descripcion {get; set;}
        public Data fecha {get; set;}
        public String type {get; set;}

        public void setChildren(Boolean children) {
            this.children = children;
            this.icon = (children) ? rutaCarpeta : rutaArchivo;
        }

    }

    //Clase auxiliar que representara el stado del nodo
    public class State {

        //Atributos
        public Boolean opened {get; set;}
        public Boolean disabled {get; set;}
        public Boolean selected {get; set;}


    }

    //Clase auxiliar que representara los datos a visualizar del nodo
    public class Data {

        //Atributos
        public String label {get; set;}
        public String valor {get; set;}
        public Boolean isLink {get; set;}
        public String id {get; set;}
        public Boolean showPopUp {get; set;}
        public String conjunto {get; set;}




    }

    //Clase auxiliar que representara atributos
    public class Atributo {

        //Atributos
        public String href {get; set;}
        public String data_type {get; set;}

    }

    //Clase auxiliar que representara el resultado de un procesamiento
    public class Resultado {

        //Atributos
        public List<Task> tareas {get; set;}
        public Integer casosProcesados {get; set;}
        public Boolean error {get; set;}
        public String msg {get; set;}
        public Interaccion__c interaccion {get; set;}
        public Boolean interaccionDeleted {get; set;}

    }

    //Clase Auxiliar que representara los datos necesarios para abrir el popup de ventas
    public class DatosVentas {

        public String idCuenta {get; set;}
        public String idObtentor {get; set;}
        public String anoCampana {get; set;}
        public String cultivo {get; set;}

    }


    //Clase auxiliar que representara el objeto que se le pasa a los metodos de procesamiento
    public class DatosProcesar {

        //Atributos

        //Lista de casos a Procesar
        public List<String> idsCasos {get; set;}

        //Lista de tareas que se han creado hasta el momento
        public List<Task> tareas {get; set;}

        //Lista de comentarios codificados
        public List<String> comentariosCodificados {get; set;}

        //Descripcion
        public String descripcion {get; set;}

        //Caso Padre
        public Id parentCase {get; set;}

        //Interaccion Actual
        public Interaccion__c interaccion {get; set;}

        //Fecha de Respuesta
        public Date fechaRespuesta {get; set;}

        //Fecha de Pago
        public Date fechaPago {get; set;}

        // Tipo de Tarea
        public String taskType {get; set;}

    }


}