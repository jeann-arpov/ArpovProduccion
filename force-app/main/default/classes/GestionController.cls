/**
* @author Maximo Martinez
* @date 11/09/2018
* @description Controlador del Componente Lightning gestionCmp
*/
public class GestionController {

    /**
    * @author Maximo Martinez
    * @date 28/11/2018
    * @description Devuelve la configuracion personalizada usada en el componente lightning
    * @return Devuelve una lista de Configuracion_Gestion__mdt
    */
    @AuraEnabled
    public static List<Map<String,Object>> getConfig(){
        
        Id rtFactura = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Factura');
        Id rtDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('DUP');
        Id rtAuditoria = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Auditoria');
        Id rtVentas = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Ventas');

        List<Map<String,Object>> configs = new List<Map<String,Object>>();

        for(Configuracion_Gestion__mdt conf : [SELECT DeveloperName,Id,Id_Usuario__c,Prioridad__c,Tipo_de_Registro__c FROM Configuracion_Gestion__mdt WHERE Id_Usuario__c =:UserInfo.getUserId() ORDER BY Prioridad__c ASC]){

            Map<String,Object> config = new Map<String,Object>();

            config.put('Prioridad__c',conf.Prioridad__c);
            config.put('Tipo_de_Registro__c',conf.Tipo_de_Registro__c);
            config.put('RecordTypeId',((conf.Tipo_de_Registro__c=='Auditoría')?rtAuditoria:((conf.Tipo_de_Registro__c=='Factura')?rtFactura:((conf.Tipo_de_Registro__c=='Ventas')?rtVentas:rtDUP))));
            config.put('RecordTypeDeveloperName',((conf.Tipo_de_Registro__c=='Auditoría')?'Auditoria':((conf.Tipo_de_Registro__c=='Factura')?'Factura':((conf.Tipo_de_Registro__c=='Ventas')?'Ventas':'DUP'))));
            config.put('FieldSet',((conf.Tipo_de_Registro__c=='Auditoría')?'Gestion_Auditorias':((conf.Tipo_de_Registro__c=='Factura')?'Gestion_Cobranza':((conf.Tipo_de_Registro__c=='Ventas')?'Gestion_Ventas':'Gestion_DUP'))));
            config.put('Title',((conf.Tipo_de_Registro__c=='Auditoría')?'Auditorias':((conf.Tipo_de_Registro__c=='Factura')?'Facturas':((conf.Tipo_de_Registro__c=='Ventas')?'Ventas':'DUPs'))));
            config.put('SObjectName',((conf.Tipo_de_Registro__c=='Auditoría')?'Transaccion__c':((conf.Tipo_de_Registro__c=='Factura')?'Opportunity':((conf.Tipo_de_Registro__c=='Ventas')?'Venta__c':'Transaccion__c'))));

            configs.add(config);

        }
        
        return configs;

    }   



    /**
    * @author Maximo Martinez
    * @date 05/10/2018
    * @description Devuelve la campaña vigente con fecha inicio mas cercana a la actual x defecto
    * @return Devuelve una lista de campos que contiene el fieldset
    */
    @AuraEnabled
    public static Campana_Agricola__c getCampanaAgricola(){
        return GestionDeCuentasController.getCampanaAgricola()[0];
    }  

    /**
    * @author Maximo Martinez
    * @date 17/12/2018
    * @description Devuelve las campañas agricolas vigentes y sus anteriores
    * @return Lista de objetos campañas agricolas y sus anteriores
    */
    @AuraEnabled
    public static List<Campana_Agricola__c> getCampanasAgricolas(){
        
        Set<Id> idsCampanasAgricolas = new Set<Id>();

        for(Campana_Agricola__c ca : [SELECT Id, Name, Nombre_de_Campana_Anterior__c FROM Campana_Agricola__c WHERE Estado__c = 'Activa']){
            idsCampanasAgricolas.add(ca.Id);
            idsCampanasAgricolas.add(ca.Nombre_de_Campana_Anterior__c);
        }

        return [SELECT Id, Name FROM Campana_Agricola__c WHERE Id IN :idsCampanasAgricolas];

    }


    /**
    * @author Maximo Martinez
    * @date 04/12/2018
    * @description Devuelve la cuenta de la interaccion
    * @return Devuelve el Id de la campañá
    */
    @AuraEnabled
    public static Interaccion_Nueva__c getInteraccion(String recordId){
        return [SELECT Id, Cuenta__c, (SELECT Id, RecordTypeId, RecordType.DeveloperName, Transaccion__c, Factura__c, Resultado__c, Respuestas__c, Fecha_Comprometida_Respuesta__c, Fecha_Comprometida_Pago__c, Comentarios__c FROM Documentos_Gestionados__r) FROM Interaccion_Nueva__c WHERE Id = :recordId];
    }  


    /**
    * @author Maximo Martinez
    * @date 04/12/2018
    * @description Devuelve la cuenta de la interaccion
    * @return Devuelve el Id de la campañá
    */
    @AuraEnabled
    public static SObject getActivityItem(String recordId){

        Schema.SObjectType sType = Utils.getObjectTypeById(recordId);

        return Database.query('SELECT Id, AccountId, WhatId FROM '+sType.getDescribe().getName()+' WHERE Id = :recordId');
    
    }  

    /**
    * @author Maximo Martinez
    * @date 12/09/2018
    * @description Graba una nueva interaccion y sus respectivos documentos gestionados asociados
    * @return Retorna una PageReference ó null dependiendo de se la transaccion fue o no efectiva
    */
    @AuraEnabled
    public static Interaccion_Nueva__c save(Interaccion_Nueva__c interaccion, List<Documento_Gestionado__c> documentosGestionado, Id activityId, String horaInicioFactura, String horaFinFactura, String horaInicioDup, String horaFinDup, String horaInicioAuditoria, String horaFinAuditoria, String horaInicioVenta, String horaFinVenta){

        Id rtFactura = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Factura');
        Id rtDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('DUP');
        Id rtAuditoria = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Auditoria');
        Id rtVentas = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Ventas');

        Set<Id> idsRecordTypesDocsGestionados = new Set<Id>();
        
        Map<Datetime,Map<Datetime,Set<Id>>> recordTypesAvailablesByDate = new Map<Datetime,Map<Datetime,Set<Id>>>();

        interaccion.IsUpdatable__c = false;

        // Intentamos guardar la gestion
        checkResults(Utils.upsertList(new List<Interaccion_Nueva__c>{interaccion},false));

        interaccion = [SELECT Id, Name, Cuenta__c, Cuenta__r.Name, Resultado_de_la_Gestion__c FROM Interaccion_Nueva__c WHERE Id = :interaccion.Id];

        // Lista de Tareas que tenemos que dar de alta si hay fecha Comprometida de Respuesta distinta en cada Documento_Gestionado__c
        List<SObject> sobjectsToInsert = new List<SObject>(); 

        List<SObject> sobjectsToUpdate = new List<SObject>();

        Datetime now = System.now();

        String description = String.format('Llamada de seguimiento proveniente de la gestion nro {0} realizada el dia {1} hora {2}', new List<String> { interaccion.Name, now.date().format(), now.hour() + ':' + ( (now.minute()<9) ? '0'+now.minute() : ''+now.minute() ) });

        System.debug(LoggingLevel.WARN, horaInicioFactura);
        System.debug(LoggingLevel.WARN, horaFinFactura);

        List<Campana_Agricola__c> cAgricolas = GestionDeCuentasController.getCampanaAgricola();

        // Recorremos los documentos
        for(Documento_Gestionado__c dg : documentosGestionado){

            if(String.isEmpty(dg.Id)){
                dg.Gestion_Nueva__c = interaccion.Id;
            }

            idsRecordTypesDocsGestionados.add(dg.RecordTypeId);

            if(dg.Fecha_Comprometida_Respuesta__c != null || dg.Fecha_Comprometida_Pago__c != null){
                
                Date d = (dg.Fecha_Comprometida_Pago__c!=null ? dg.Fecha_Comprometida_Pago__c : dg.Fecha_Comprometida_Respuesta__c);

                String horaInicio = (dg.RecordTypeId == rtFactura) ? horaInicioFactura : ( (dg.RecordTypeId == rtDUP) ? horaInicioDup : ( (dg.RecordTypeId == rtVentas) ? horaInicioVenta : horaInicioAuditoria ) );
                String horaFin = (dg.RecordTypeId == rtFactura) ? horaFinFactura : ( (dg.RecordTypeId == rtDUP) ? horaFinDup : ( (dg.RecordTypeId == rtVentas) ? horaFinVenta : horaFinAuditoria ) );

                Datetime dtStart = (String.isNotEmpty(horaInicio)) ? Datetime.newInstance(d.year(), d.month(), d.day(),Integer.valueOf(horaInicio.substring(0,2)), Integer.valueOf(horaInicio.substring(3,5)),0) : Datetime.newInstance(d.year(), d.month(), d.day(), now.hour(), now.minute(),0);
                Datetime dtEnd = (String.isNotEmpty(horaFin)) ? Datetime.newInstance(d.year(), d.month(), d.day(),Integer.valueOf(horaFin.substring(0,2)), Integer.valueOf(horaFin.substring(3,5)),0) : Datetime.newInstance(d.year(), d.month(), d.day(), now.hour(), now.minute(),0);

                if(!recordTypesAvailablesByDate.containsKey(dtStart)){
                    recordTypesAvailablesByDate.put(dtStart,new Map<Datetime,Set<Id>>());
                }

                if(!recordTypesAvailablesByDate.get(dtStart).containsKey(dtEnd)){
                    recordTypesAvailablesByDate.get(dtStart).put(dtEnd,new Set<Id>());
                }

                recordTypesAvailablesByDate.get(dtStart).get(dtEnd).add(dg.RecordTypeId);
            }

            if(dg.RecordTypeId == rtAuditoria && String.isNotEmpty(dg.Transaccion__c)){ // Las auditorias gestionadas hay que pasarlas a Gestionadas
                sobjectsToUpdate.add(new Transaccion__c(Id=dg.Transaccion__c,Gestionada__c=true));
            }

            if(cAgricolas != null && !cAgricolas.isEmpty() && (String.isEmpty(dg.Campania_Gestion__c)) ){
                dg.Campania_Gestion__c = cAgricolas[0].Id;
            }

           
        }

        // Creamos las tareas
        for(Datetime dtStart : recordTypesAvailablesByDate.keySet()){
            
            for(Datetime dtEnd : recordTypesAvailablesByDate.get(dtStart).keySet()){

                String subject = buildSubject(interaccion.Cuenta__r.Name,recordTypesAvailablesByDate.get(dtStart).get(dtEnd));

                Event t = new Event();
                t.WhatId = interaccion.Cuenta__c;
                t.Subject = subject;
                t.ActivityDateTime = dtStart;
                t.StartDateTime = dtStart;
                t.EndDateTime = dtEnd;
                t.Description = description;
                sobjectsToInsert.add(t);

            }

        }

        // Intentamos upsertear los documentos
        checkResults(Utils.upsertList(documentosGestionado,false));

        // Creamos/Actualizamos una actividad
        Task t = new Task();
        t.Status = 'Cerrada';
        t.Gestion_Nueva__c = interaccion.Id;
        t.Description = description;

        if(String.isEmpty(activityId)){
            t.WhatId = interaccion.Cuenta__c;
            t.WhatId = interaccion.Id;
            t.Subject = buildSubject(interaccion.Cuenta__r.Name,idsRecordTypesDocsGestionados);
            t.ActivityDate = Date.today();
            sobjectsToInsert.add(t);
        }else if(String.isNotEmpty(activityId) && Task.SObjectType == Utils.getObjectTypeById(activityId)){
            t.Id = activityId;
            sobjectsToUpdate.add(t);
        }

        if(String.isNotEmpty(activityId) && Event.SObjectType == Utils.getObjectTypeById(activityId)){
            Event e = new Event();
            e.Id = activityId;
            //e.WhatId = interaccion.Id;
            e.Gestion_Nueva__c = interaccion.Id;
            sobjectsToUpdate.add(e);
        }

        

        // Intentamos insertar las tareas
        checkResults(Utils.insertList(sobjectsToInsert,false));

        // Intentamos actualizar los objectos
        checkResults(Utils.updateList(sobjectsToUpdate,false));

        return interaccion;

    }


    private static void checkResults(List<Database.SaveResult> svrs){
        
        List<String> errors = new List<String>();

        for(Database.SaveResult svr : svrs){
            if(!svr.isSuccess()){
                errors.add(svr.getErrors()[0].getMessage());
            }
        }

        // Si hay error, hacemos rollback e indicamos al usuario del error
        if(!errors.isEmpty()){
            throw new AuraHandledException(String.join(errors,'\n'));
        }

    }

    private static void checkResults(List<Database.UpsertResult> svrs){
        
        List<String> errors = new List<String>();

        for(Database.UpsertResult svr : svrs){
            if(!svr.isSuccess()){
                errors.add(svr.getErrors()[0].getMessage());
            }
        }

        // Si hay error, hacemos rollback e indicamos al usuario del error
        if(!errors.isEmpty()){
            throw new AuraHandledException(String.join(errors,'\n'));
        }

    }

    /**
    * @author Maximo Martinez
    * @date 12/09/2018
    * @description Devuelve el nombre del icono del objeto para usar ele el componente lightning
    * @param sObjectName Nombre API del SObject a obtener el icono
    * @return el nombre del icono del objeto 
    */
    @AuraEnabled
    public static String getIconName(String sObjectName){
        return AuraController.getIconName(sObjectName);
    }


    private static String buildSubject(String accountName, Set<Id> idsRecordTypes){

        Id rtFactura = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Factura');
        Id rtDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('DUP');
        Id rtAuditoria = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Auditoria');
        Id rtVentas = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Documento_Gestionado__c.SObjectType).get('Ventas');

        String subject = accountName;

        List<String> recordTypesAvailables = new List<String>();

        if(idsRecordTypes.contains(rtDUP)){
            recordTypesAvailables.add('DUP');
        }

        if(idsRecordTypes.contains(rtFactura)){
            recordTypesAvailables.add('Cobranza');
        }

        if(idsRecordTypes.contains(rtVentas)){
            recordTypesAvailables.add('Ventas');
        }

        if(idsRecordTypes.contains(rtAuditoria)){
            recordTypesAvailables.add('Auditoria');
        }

        return subject + ((recordTypesAvailables.isEmpty())?'':' - '+String.join(recordTypesAvailables, ' / '));
    
    }
      

}