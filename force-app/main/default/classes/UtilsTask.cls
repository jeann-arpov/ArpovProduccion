/**
* @author Maximo Martinez
* @date 29/05/2014
* @description Clase con diferentes metodos auxiliares para el objeto Task
*/

public with sharing class UtilsTask {

    /**
    * @author Maximo Martinez
    * @date 04/08/2014
    * @description Metodo que setea el owner de las task asociadas a remesas
    * @param lista de remesas
    */

    public static void setearOperadorRemesa(List<Task> lista) {

        //Coleccionamos el whatid de cada task
        Map<Id, Set<Id>> taskByWhatIds = new Map<Id, Set<Id>>();

        for (Task t : lista) {

            if (t.WhatId != null) {
                if (!taskByWhatIds.containsKey(t.WhatId)) {
                    taskByWhatIds.put(t.WhatId, new Set<Id>());
                }
                taskByWhatIds.get(t.WhatId).add(t.Id);
            }

        }

        //Lista que contendra las remesas
        Set<Id> remesas = new Set<Id>();

        //Recorremos los Ids y verificamos cuales corresponden a objetos de remesas
        for (Id id : taskByWhatIds.keySet()) {

            if (String.valueOf(id.getSObjectType()) == 'Remesa__c') {

                remesas.add(id);

            }

        }

        //Armamos un Map para coleccionar por cada remesa su operador
        Map<Id, Id> operadores = new Map<Id, Id>();

        for (Remesa__c r : [SELECT Id, Productor__r.Operador__c FROM Remesa__c WHERE Id IN :remesas]) {

            //verificamos si tenemos un productor seteado
            if (r.Productor__r != null) {

                //Verificamos si tenemos un Operador seteado
                if (r.Productor__r.Operador__c != null) {

                    //Agregamos al Map
                    operadores.put(r.Id, r.Productor__r.Operador__c);

                }


            }


        }

        //Recorremos nuevamente las tareas y seteamos el Owner id en base al operador
        for (Task t : lista) {

            //Si esta en el map cambio el OwnerId
            if (operadores.containsKey(t.WhatId)) {

                //Obtengo el operador
                Id idOperador = operadores.get(t.WhatId);

                t.OwnerId = idOperador;

            }

        }



    }

    public static void AdjuntaAttachments(List<Task> lista) {

        //Coleccionamos el whatid de cada task
        Map<Id, Set<Task>> taskByWhatIds = new Map<Id, Set<Task>>();

        for (Task t : lista) {

            if (t.WhatId != null) {
                if (!taskByWhatIds.containsKey(t.WhatId)) {
                    taskByWhatIds.put(t.WhatId, new Set<Task>());
                }
                taskByWhatIds.get(t.WhatId).add(t);
            }

        }

        //Lista que contendra las remesas
        Set<Id> remesas = new Set<Id>();

        //Recorremos los Ids y verificamos cuales corresponden a objetos de remesas
        for (Id id : taskByWhatIds.keySet()) {

            if (String.valueOf(id.getSObjectType()) == 'Remesa__c') {

                remesas.add(id);

            }

        }

        //Obtenemos los attachmen de cada remesa
        Map<Id, List<Attachment>> adjuntosByRemesa = new Map<Id, List<Attachment>>();

        for (Attachment a : [SELECT Name, ContentType, Body, ParentId FROM Attachment WHERE ParentId IN :remesas]) {

            if (!adjuntosByRemesa.containsKey(a.ParentId)) {
                adjuntosByRemesa.put(a.ParentId, new List<Attachment>());
            }

            adjuntosByRemesa.get(a.ParentId).add(a);

        }

        //Lista que contendra los adjuntos a crear
        List<Attachment> adjuntos = new List<Attachment>();

        for (Id idRemesa : adjuntosByRemesa.keySet()) {

            //Obtenemos la lista de adjuntos
            List<Attachment> listaAdjuntos = adjuntosByRemesa.get(idRemesa);

            //Obtenemos el la lista de task que se generaron para esa remesa (si hay mas de una)
            Set<Task> tareas = taskByWhatIds.get(idRemesa);

            //Recorremos las task
            for (Task t : tareas) {

                //Recorremos los attachment
                for (Attachment a : listaAdjuntos) {

                    Attachment adjunto = a.clone();

                    //Cambiamos el what id
                    adjunto.ParentId = t.Id;

                    //Cambiamos el owner
                    if (t.OwnerId != null)
                        adjunto.OwnerId = t.OwnerId;

                    //Agregamos el adjunto a la lista de adjuntos
                    adjuntos.add(adjunto);
                }

            }

        }

        if (adjuntos.size() > 0) {
            Utils.insertList(adjuntos);
        }


    }

    /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Metodo encargado de generar Interacciones y Casos Gestionados, a partir de tareas cargadas desde
    * @description la pagina standard de SF
    */
    public static void gestionarCasos(List<Task> lista) {


        //Record Type de los dos tipos de casos que se gestionan hasta el momento
        Id casoDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');
        Id casoCobranza = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');

        //Obtenemos los casos que estan asociados a las tareas

        //Set donde almacenaremos los whatids de las tareas
        Set<Id> whatIds = new Set<Id>();

        //Recorremos las tareas
        for (Task tarea : lista) {

            //Consultamos si la tarea no se creo desde la página de gestion de casos
            if (tarea.Generada_desde_Pagina_Gestion_de_Casos__c == false) {
                //Coleccionamos las tareas
                whatIds.add(tarea.WhatId);
            }
        }

        //A partir de los what ids obtenemos los casos que existan (si es que hay)

        //Map que contendra los casos
        Map<Id, Case> casos = new  Map<Id, Case>();

        //Recorremos los casos
        for (Case caso : [SELECT Id, RecordTypeId, Factura__c, DUP__c, AccountId FROM Case WHERE Id IN :whatIds AND (RecordTypeId = :casoDUP OR RecordTypeId = :casoCobranza) AND ParentId != null]) {

            //Coleccionamos el id del caso en el map de casos
            if (!casos.containsKey(caso.Id)) {
                casos.put(caso.Id, caso);
            }


        }


        //Por cada tarea relacionada con un caso y que no ha sido cargada por la pagina de gestion de casos
        //Creo una Interaccion y un Caso Gestionado

        //Lista que contendra las interacciones a insertar
        List<WrapperGestionCaso> wrappers = new List<WrapperGestionCaso>();

        //Recorremos las tareas
        for (Task tarea : lista) {

            //Verificamos si la tarea esta asociada a un caso que sea hijo y que ademas sea de uno de los tipos
            //de casos gestionables
            if (casos.containsKey(tarea.WhatId)) {

                //Obtenemos el caso
                Case c = casos.get(tarea.WhatId);

                //Instanciamos un wrapper
                WrapperGestionCaso wp = new WrapperGestionCaso();

                //Creamos una interaccion
                wp.interaccion = new Interaccion__c();


                //Seteamos algunos datos
                wp.interaccion.Caso__c = tarea.WhatId;
                wp.interaccion.Modo_de_Contacto__c = (tarea.Subject != null) ? ((tarea.Subject.indexOf('Llamada') != -1 || tarea.Subject.indexOf('Call') != -1) ? 'Telefono' : 'Email') : null;
                wp.interaccion.Fecha_y_Hora__c =  system.now();
                wp.interaccion.Operador__c = UserInfo.getUserId();

                //Creamos un caso gestionado
                wp.casoGestionado = new Caso_Gestionado__c();

                //Seteamos algunos datos
                wp.casoGestionado.Caso__c = c.Id;
                wp.casoGestionado.Comentario_Codificado__c = tarea.Comentario_Codificado__c;
                wp.casoGestionado.Cuenta__c = c.AccountId;

                //Insertamos en la lista de wrappers
                wrappers.add(wp);
            }

        }


        //Si creamos casos e interacciones vamos a insertar las interacciones, luego setear la interaccion a los
        //casos gestionados e insertar finalmenente estos
        if (wrappers.size() > 0) {

            //Lista que contendra las interacciones a insertar
            List<Interaccion__c> interaccionesToInsert = new List<Interaccion__c>();

            //Lista que contendra las interacciones a insertar
            List<Caso_Gestionado__c> cgToInsert = new List<Caso_Gestionado__c>();

            for (WrapperGestionCaso wp : wrappers) {

                //Insertamos la interaccion en la lista de interacciones a insertar
                interaccionesToInsert.add(wp.interaccion);

            }

            System.Debug(LoggingLevel.INFO, interaccionesToInsert);

            //Llamamos al metodo de insercion por lotes
            Utils.insertList(interaccionesToInsert);

            //Recorremos los wrappers y ya con el id de la interaccion, lo asociamos al caso gestionado

            for (WrapperGestionCaso wp : wrappers) {

                //Relacionamos el caso gestionado con la interaccion
                wp.casoGestionado.Interaccion__c = wp.interaccion.Id;

                //Agregamos el caso gestionado a la lista de casos a insertar
                cgToInsert.add(wp.casoGestionado);


            }

            System.Debug(LoggingLevel.INFO, cgToInsert);

            //Llamamos al metodo de insercion por lotes
            Utils.insertList(cgToInsert);

        }



    }





    /**
    * @author Maximo Martinez
    * @date 28/08/2014
    * @description Metodo que valida que el caso cumpla con las condiciones que la task requiere
    */
    public static void validarFechas(List<Task> lista) {


        //Recorremos las task y verificamos en el comentario codificado existan:
        //6 - Promesa de Respuesta
        //9 - Solicita Plazo de pago

        //Map que contendra el Id de los Casos  y el task que cumplen la condicion
        Map<Id, List<Task>> tareas = new Map<Id, List<Task>>();

        for (Task tarea : lista) {

            if (tarea.Comentario_Codificado__c != null) {

                if (tarea.Comentario_Codificado__c.contains('6 - Promesa de Respuesta') || tarea.Comentario_Codificado__c.contains('9 - Solicita Plazo de pago')) {

                    //Existen alguno de estos comentarios, coleccionamos el caso y las task

                    //Verificamos si existe la entrada sino la creamos
                    if (!tareas.containsKey(tarea.Id)) {

                        tareas.put(tarea.WhatId, new List<Task>());

                    }

                    tareas.get(tarea.WhatId).add(tarea);


                }

            }

        }

        //Verificamos si el map esta vacio
        if (tareas.size() == 0) return;


        //Obtenemos los recordtype de los casos
        Id rtDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');

        Id rtCobranza = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');


        //Recorremos nuevamente los casos gestionados obteniendo la informacion del caso al que pertenecen
        for (Case caso : [SELECT Id, RecordTypeId, Fecha_Comprometida_Pago__c, Fecha_Comprometida_Respuesta__c FROM Case WHERE Id IN :tareas.keySet() AND (RecordTypeId = :rtDUP OR RecordTypeId = :rtCobranza)]) {

            //Si el caso es un tipo DUP, el caso gestionado contiene el comentario 6 y
            //el caso no tiene una fecha de respuesta seteamos error

            if (tareas.containsKey(caso.Id)) {

                //Recorremos las task
                for (Task tarea : (List<Task>)tareas.get(caso.Id)) {

                    if (caso.RecordTypeId == rtDUP && tarea.Comentario_Codificado__c.contains('6 - Promesa de Respuesta') && caso.Fecha_Comprometida_Respuesta__c == null) {

                        tarea.addError('No se ha cargado la fecha comprometida de respuesta. En el caso asociado.');

                    } else if (caso.RecordTypeId == rtCobranza && tarea.Comentario_Codificado__c.contains('9 - Solicita Plazo de pago') && caso.Fecha_Comprometida_Pago__c == null) {

                        tarea.addError('No se ha cargado la fecha comprometida de pago. En el caso asociado.');

                    }

                }


            }


        }


    }

    /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Clase encargada de mantener unida una interaccion, una tarea y un caso momentaneamente
    */

    public class WrapperGestionCaso {

        //Atributos
        public Interaccion__c interaccion {get; set;}
        public Caso_Gestionado__c casoGestionado {get; set;}

    }

}